// Balanced Ternary CPU Core
// 4-stage pipeline: IF -> ID -> EX -> WB
//
// BTISA v0.1 Implementation
// - 27-trit data path
// - 9 general-purpose registers
// - 9-trit instruction encoding

module ternary_cpu
  import ternary_pkg::*;
#(
  parameter int TRIT_WIDTH = 27,
  parameter int IMEM_DEPTH = 243,  // 3^5 instructions
  parameter int DMEM_DEPTH = 729   // 3^6 data words
)(
  input  logic clk,
  input  logic rst_n,

  // Instruction memory interface
  output trit_t [7:0]            imem_addr,
  input  trit_t [8:0]            imem_data,

  // Data memory interface
  output trit_t [8:0]            dmem_addr,
  output trit_t [TRIT_WIDTH-1:0] dmem_wdata,
  input  trit_t [TRIT_WIDTH-1:0] dmem_rdata,
  output logic                   dmem_we,
  output logic                   dmem_re,

  // Status outputs
  output logic                   halted,
  output trit_t [7:0]            pc_out,       // Current PC for debug
  output logic                   valid_out,    // Pipeline valid signal

  // Debug ports for register file access
  input  logic [3:0]             dbg_reg_idx,
  output trit_t [TRIT_WIDTH-1:0] dbg_reg_data,

  // Hazard status
  output logic                   stall_out,
  output logic                   fwd_a_out,
  output logic                   fwd_b_out
);

  // ============================================================
  // Pipeline Registers
  // ============================================================

  // IF/ID Stage
  trit_t [8:0]  if_id_instr;
  trit_t [7:0]  if_id_pc;
  logic         if_id_valid;

  // ID/EX Stage
  trit_t [TRIT_WIDTH-1:0] id_ex_rs1_data;
  trit_t [TRIT_WIDTH-1:0] id_ex_rs2_data;
  trit_t [1:0]            id_ex_rd;
  trit_t [1:0]            id_ex_rs1;
  trit_t [1:0]            id_ex_imm;
  logic [2:0]             id_ex_alu_op;
  logic                   id_ex_reg_write;
  logic                   id_ex_mem_read;
  logic                   id_ex_mem_write;
  logic                   id_ex_alu_src;
  logic                   id_ex_branch;
  logic                   id_ex_jump;
  trit_t [7:0]            id_ex_pc;
  logic                   id_ex_valid;

  // EX/WB Stage
  trit_t [TRIT_WIDTH-1:0] ex_wb_result;
  trit_t [TRIT_WIDTH-1:0] ex_wb_mem_data;
  trit_t [1:0]            ex_wb_rd;
  logic                   ex_wb_reg_write;
  logic                   ex_wb_mem_read;
  logic                   ex_wb_valid;

  // ============================================================
  // Program Counter
  // ============================================================
  trit_t [7:0] pc;
  trit_t [7:0] next_pc;
  trit_t [7:0] pc_plus_one;
  trit_t       pc_carry;
  logic        pc_stall;
  logic        take_branch;

  // Local constant 1 for PC increment (workaround for Icarus Verilog)
  trit_t [7:0] const_one;
  assign const_one[0] = T_POS_ONE;
  assign const_one[1] = T_ZERO;
  assign const_one[2] = T_ZERO;
  assign const_one[3] = T_ZERO;
  assign const_one[4] = T_ZERO;
  assign const_one[5] = T_ZERO;
  assign const_one[6] = T_ZERO;
  assign const_one[7] = T_ZERO;

  // Local constant zero for carry-in (workaround for Icarus Verilog)
  trit_t const_zero_trit;
  assign const_zero_trit = T_ZERO;

  // PC output for debug
  assign pc_out = pc;

  // PC increment: PC + 1
  ternary_adder #(.WIDTH(8)) pc_incrementer (
    .a    (pc),
    .b    (const_one),  // Constant 1
    .cin  (const_zero_trit),
    .sum  (pc_plus_one),
    .cout (pc_carry)
  );

  // Branch/Jump target calculation
  trit_t [7:0] branch_target;
  trit_t       branch_carry;
  trit_t [7:0] branch_offset;

  // Sign-extend 2-trit immediate to 8 trits
  assign branch_offset = {{6{id_ex_imm[1]}}, id_ex_imm};

  ternary_adder #(.WIDTH(8)) branch_adder (
    .a    (id_ex_pc),
    .b    (branch_offset),
    .cin  (const_zero_trit),
    .sum  (branch_target),
    .cout (branch_carry)
  );

  // Next PC selection
  always_comb begin
    if (take_branch || id_ex_jump) begin
      next_pc = branch_target;
    end else begin
      next_pc = pc_plus_one;
    end
  end

  // PC register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= TRIT8_ZERO;
    end else if (!halted && !pc_stall) begin
      pc <= next_pc;
    end
  end

  // Instruction memory interface
  assign imem_addr = pc;

  // ============================================================
  // Decoder Signals
  // ============================================================
  trit_t [2:0] dec_opcode;
  trit_t [1:0] dec_rd, dec_rs1, dec_rs2_imm;
  logic        dec_reg_write, dec_mem_read, dec_mem_write;
  logic        dec_branch, dec_jump, dec_alu_src;
  logic [2:0]  dec_alu_op;
  logic        dec_halt;

  // ============================================================
  // IF Stage: Instruction Fetch
  // ============================================================

  // IF/ID pipeline register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      if_id_instr <= TRIT9_ZERO;
      if_id_pc    <= TRIT8_ZERO;
      if_id_valid <= 1'b0;
    end else if (!pc_stall) begin
      if (take_branch || id_ex_jump) begin
        // Flush on branch/jump
        if_id_instr <= TRIT9_ZERO;  // NOP
        if_id_valid <= 1'b0;
      end else begin
        if_id_instr <= imem_data;
        if_id_pc    <= pc;
        if_id_valid <= 1'b1;
      end
    end
  end

  // ============================================================
  // ID Stage: Instruction Decode
  // ============================================================

  // Instruction decoder
  btisa_decoder u_decoder (
    .instruction (if_id_instr),
    .opcode      (dec_opcode),
    .rd          (dec_rd),
    .rs1         (dec_rs1),
    .rs2_imm     (dec_rs2_imm),
    .reg_write   (dec_reg_write),
    .mem_read    (dec_mem_read),
    .mem_write   (dec_mem_write),
    .branch      (dec_branch),
    .jump        (dec_jump),
    .alu_src     (dec_alu_src),
    .alu_op      (dec_alu_op),
    .halt        (dec_halt)
  );

  // Register file signals
  trit_t [TRIT_WIDTH-1:0] rf_rs1_data, rf_rs2_data;
  trit_t [TRIT_WIDTH-1:0] rf_wr_data;
  logic                   rf_wr_en;

  // Register file
  ternary_regfile #(
    .NUM_REGS   (9),
    .TRIT_WIDTH (TRIT_WIDTH)
  ) u_regfile (
    .clk          (clk),
    .rst_n        (rst_n),
    .rs1_addr     (dec_rs1),
    .rs2_addr     (dec_rs2_imm),
    .rs1_data     (rf_rs1_data),
    .rs2_data     (rf_rs2_data),
    .rd_addr      (ex_wb_rd),
    .rd_data      (rf_wr_data),
    .we           (rf_wr_en),
    .dbg_reg_idx  (dbg_reg_idx),
    .dbg_reg_data (dbg_reg_data)
  );

  // Write-back data and enable
  assign rf_wr_data = ex_wb_mem_read ? ex_wb_mem_data : ex_wb_result;
  assign rf_wr_en   = ex_wb_reg_write && ex_wb_valid;

  // ID/EX pipeline register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      id_ex_rs1_data  <= TRIT27_ZERO;
      id_ex_rs2_data  <= TRIT27_ZERO;
      id_ex_rd        <= TRIT2_ZERO;
      id_ex_rs1       <= TRIT2_ZERO;
      id_ex_imm       <= TRIT2_ZERO;
      id_ex_alu_op    <= 3'b000;
      id_ex_reg_write <= 1'b0;
      id_ex_mem_read  <= 1'b0;
      id_ex_mem_write <= 1'b0;
      id_ex_alu_src   <= 1'b0;
      id_ex_branch    <= 1'b0;
      id_ex_jump      <= 1'b0;
      id_ex_pc        <= TRIT8_ZERO;
      id_ex_valid     <= 1'b0;
    end else if (pc_stall) begin
      // Insert bubble (NOP) on stall - keep ID stage, invalidate EX
      id_ex_reg_write <= 1'b0;
      id_ex_mem_read  <= 1'b0;
      id_ex_mem_write <= 1'b0;
      id_ex_branch    <= 1'b0;
      id_ex_jump      <= 1'b0;
      id_ex_valid     <= 1'b0;
    end else begin
      // Normal operation
      id_ex_rs1_data  <= rf_rs1_data;
      id_ex_rs2_data  <= rf_rs2_data;
      id_ex_rd        <= dec_rd;
      id_ex_rs1       <= dec_rs1;
      id_ex_imm       <= dec_rs2_imm;
      id_ex_alu_op    <= dec_alu_op;
      id_ex_reg_write <= dec_reg_write;
      id_ex_mem_read  <= dec_mem_read;
      id_ex_mem_write <= dec_mem_write;
      id_ex_alu_src   <= dec_alu_src;
      id_ex_branch    <= dec_branch;
      id_ex_jump      <= dec_jump;
      id_ex_pc        <= if_id_pc;
      id_ex_valid     <= if_id_valid;
    end
  end

  // ============================================================
  // EX Stage: Execute
  // ============================================================

  // ALU operands
  trit_t [TRIT_WIDTH-1:0] alu_a, alu_b;
  trit_t [TRIT_WIDTH-1:0] alu_result;
  trit_t                  alu_carry;
  logic                   alu_zero, alu_neg;

  // Forwarded data from MEM/WB stage
  trit_t [TRIT_WIDTH-1:0] mem_forward_data;
  assign mem_forward_data = ex_wb_mem_read ? ex_wb_mem_data : ex_wb_result;

  // Sign-extension for immediate (Icarus workaround)
  trit_t imm_sign_trit;
  assign imm_sign_trit = trit_t'(id_ex_imm[1]);

  // ALU input A with forwarding
  // forward_a encoding: 00=no fwd, 01=from WB, 10=from MEM
  always_comb begin
    case (forward_a)
      2'b01:   alu_a = mem_forward_data;  // Forward from MEM/WB stage
      2'b10:   alu_a = mem_forward_data;  // Forward from MEM stage (same source in our 4-stage pipeline)
      default: alu_a = id_ex_rs1_data;    // Use pipeline register value (from ID stage)
    endcase
  end

  // ALU input B with forwarding (Rs2 data or sign-extended immediate)
  always_comb begin
    if (id_ex_alu_src) begin
      // Use sign-extended immediate (no forwarding for immediate values)
      alu_b = {{(TRIT_WIDTH-2){imm_sign_trit}}, id_ex_imm};
    end else begin
      // Use Rs2 with forwarding
      case (forward_b)
        2'b01:   alu_b = mem_forward_data;  // Forward from MEM/WB stage
        2'b10:   alu_b = mem_forward_data;  // Forward from MEM stage
        default: alu_b = id_ex_rs2_data;    // Use pipeline register value (from ID stage)
      endcase
    end
  end

  // ALU instance
  ternary_alu #(.WIDTH(TRIT_WIDTH)) u_alu (
    .a         (alu_a),
    .b         (alu_b),
    .op        (id_ex_alu_op),
    .result    (alu_result),
    .carry     (alu_carry),
    .zero_flag (alu_zero),
    .neg_flag  (alu_neg)
  );

  // Branch condition evaluation
  always_comb begin
    take_branch = 1'b0;
    if (id_ex_branch && id_ex_valid) begin
      // Compare Rs1 - Rs2, check flags
      // BEQ: branch if zero (Rs1 == Rs2)
      // BNE: branch if not zero (Rs1 != Rs2)
      // BLT: branch if negative (Rs1 < Rs2)
      case (id_ex_alu_op)
        3'b001: begin  // SUB for comparison
          // Determine branch type from immediate encoding (simplified)
          // For now, assume BEQ-like behavior
          take_branch = alu_zero;
        end
        default: take_branch = 1'b0;
      endcase
    end
  end

  // Data memory interface
  assign dmem_addr  = alu_result[8:0];
  assign dmem_wdata = id_ex_rs2_data;
  assign dmem_we    = id_ex_mem_write && id_ex_valid;
  assign dmem_re    = id_ex_mem_read && id_ex_valid;

  // EX/WB pipeline register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ex_wb_result    <= TRIT27_ZERO;
      ex_wb_mem_data  <= TRIT27_ZERO;
      ex_wb_rd        <= TRIT2_ZERO;
      ex_wb_reg_write <= 1'b0;
      ex_wb_mem_read  <= 1'b0;
      ex_wb_valid     <= 1'b0;
    end else begin
      ex_wb_result    <= alu_result;
      ex_wb_mem_data  <= dmem_rdata;
      ex_wb_rd        <= id_ex_rd;
      ex_wb_reg_write <= id_ex_reg_write;
      ex_wb_mem_read  <= id_ex_mem_read;
      ex_wb_valid     <= id_ex_valid;
    end
  end

  // ============================================================
  // Control / Hazard Detection and Forwarding
  // ============================================================

  // Forwarding control signals
  logic [1:0] forward_a;  // 00=no fwd, 01=from WB, 10=from MEM
  logic [1:0] forward_b;
  logic       if_id_stall;
  logic       id_ex_flush;
  
  // Convert 2-trit addresses to 3-trit for hazard/forward units
  // (Add zero as most significant trit since we only have 9 registers)
  trit_t [2:0] dec_rs1_3t, dec_rs2_3t, id_ex_rd_3t, ex_wb_rd_3t;
  assign dec_rs1_3t  = {T_ZERO, dec_rs1};
  assign dec_rs2_3t  = {T_ZERO, dec_rs2_imm};
  assign id_ex_rd_3t = {T_ZERO, id_ex_rd};
  assign ex_wb_rd_3t = {T_ZERO, ex_wb_rd};

  // Hazard Detection Unit
  ternary_hazard_unit u_hazard_unit (
    // ID stage
    .id_rs1       (dec_rs1_3t),
    .id_rs2       (dec_rs2_3t),
    .id_uses_rs1  (1'b1),                // Always use rs1 (simplified)
    .id_uses_rs2  (!dec_alu_src),        // Use rs2 unless using immediate
    // EX stage
    .ex_rd        (id_ex_rd_3t),
    .ex_reg_write (id_ex_reg_write),
    .ex_mem_read  (id_ex_mem_read),
    // MEM/WB stage (using ex_wb as our MEM stage)
    .mem_rd       (ex_wb_rd_3t),
    .mem_reg_write(ex_wb_reg_write),
    // Outputs
    .pc_stall     (pc_stall),
    .if_id_stall  (if_id_stall),
    .id_ex_flush  (id_ex_flush)
  );

  // Data Forwarding Unit
  trit_t [2:0] id_ex_rs1_3t, id_ex_rs2_3t;
  assign id_ex_rs1_3t = {T_ZERO, id_ex_rs1};
  assign id_ex_rs2_3t = {T_ZERO, id_ex_imm};  // imm field holds rs2 address
  
  ternary_forward_unit u_forward_unit (
    // EX stage operands
    .ex_rs1       (id_ex_rs1_3t),
    .ex_rs2       (id_ex_rs2_3t),
    // MEM stage (ex_wb pipeline register represents MEM/WB)
    .mem_rd       (ex_wb_rd_3t),
    .mem_reg_write(ex_wb_reg_write),
    // WB stage (for double-stall scenarios, currently same as MEM)
    .wb_rd        (ex_wb_rd_3t),
    .wb_reg_write (ex_wb_reg_write),
    // Outputs
    .forward_a    (forward_a),
    .forward_b    (forward_b)
  );

  assign stall_out = pc_stall;
  assign fwd_a_out = (forward_a != 2'b00);
  assign fwd_b_out = (forward_b != 2'b00);

  // Valid output
  assign valid_out = ex_wb_valid;

  // ============================================================
  // Halt Detection
  // ============================================================

  // Halt flag register
  logic halt_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      halt_reg <= 1'b0;
    end else if (dec_halt && if_id_valid) begin
      halt_reg <= 1'b1;
    end
  end

  assign halted = halt_reg;

  // ============================================================
  // Debug Support (simulation only)
  // ============================================================
  `ifdef SIMULATION
  // Simplified debug: PC and cycle counter
  integer cycle_count;
  initial cycle_count = 0;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= 0;
    end else if (!halt_reg) begin
      cycle_count <= cycle_count + 1;
      $display("[Cycle %0d] PC=%0d Valid=%b",
               cycle_count,
               ternary_to_bin({{19{T_ZERO}}, pc}),
               if_id_valid);
    end
  end

  function automatic int trit2_to_index(trit_t [1:0] addr);
    int val0, val1;
    case (addr[0])
      T_ZERO:    val0 = 0;
      T_POS_ONE: val0 = 1;
      T_NEG_ONE: val0 = 2;
      default:   val0 = 0;
    endcase
    case (addr[1])
      T_ZERO:    val1 = 0;
      T_POS_ONE: val1 = 3;
      T_NEG_ONE: val1 = 6;
      default:   val1 = 0;
    endcase
    return val0 + val1;
  endfunction
  `endif

endmodule
