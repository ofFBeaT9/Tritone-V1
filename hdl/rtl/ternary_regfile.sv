// Ternary Register File
// 9 registers × 27 trits each
// R0 is hardwired to zero (writes ignored)
//
// Register addressing uses 2 trits:
//   00 -> R0 (zero)
//   0+ -> R1, 0- -> R2
//   +0 -> R3, ++ -> R4, +- -> R5
//   -0 -> R6, -+ -> R7, -- -> R8

module ternary_regfile
  import ternary_pkg::*;
#(
  parameter int NUM_REGS = 9,
  parameter int TRIT_WIDTH = 27
)(
  input  logic                     clk,
  input  logic                     rst_n,

  // Read port 1 (Rs1)
  input  trit_t [1:0]              rs1_addr,
  output trit_t [TRIT_WIDTH-1:0]   rs1_data,

  // Read port 2 (Rs2)
  input  trit_t [1:0]              rs2_addr,
  output trit_t [TRIT_WIDTH-1:0]   rs2_data,

  // Write port (Rd)
  input  trit_t [1:0]              rd_addr,
  input  trit_t [TRIT_WIDTH-1:0]   rd_data,
  input  logic                     we,

  // Debug ports (direct register access by integer index)
  input  logic [3:0]               dbg_reg_idx,
  output trit_t [TRIT_WIDTH-1:0]   dbg_reg_data
);

  // Register storage array
  trit_t [TRIT_WIDTH-1:0] regs [NUM_REGS];

  // ============================================================
  // Address conversion: 2-trit balanced ternary to integer index
  // ============================================================
  // Encoding: each trit position has weight 1 and 3
  // T_ZERO = 0, T_POS_ONE = +1, T_NEG_ONE = -1
  // But we need unsigned index 0-8, so we offset
  //
  // addr[1] addr[0]  value   index
  //   0       0        0       0
  //   0       +        1       1
  //   0       -       -1       2 (wrap around using modulo)
  //   +       0        3       3
  //   +       +        4       4
  //   +       -        2       5
  //   -       0       -3       6
  //   -       +       -2       7
  //   -       -       -4       8

  function automatic int trit2_to_index(trit_t [1:0] addr);
    int val0, val1, result;

    // Convert each trit to integer
    case (addr[0])
      T_ZERO:    val0 = 0;
      T_POS_ONE: val0 = 1;
      T_NEG_ONE: val0 = 2;  // Map -1 to index offset 2
      default:   val0 = 0;
    endcase

    case (addr[1])
      T_ZERO:    val1 = 0;
      T_POS_ONE: val1 = 3;
      T_NEG_ONE: val1 = 6;  // Map -1 to index offset 6
      default:   val1 = 0;
    endcase

    result = val0 + val1;
    if (result >= NUM_REGS) result = 0;  // Safety clamp
    return result;
  endfunction

  // ============================================================
  // Read ports (combinational)
  // ============================================================
  // R0 always reads as zero - use generate for Icarus compatibility
  trit_t [TRIT_WIDTH-1:0] zero_val;
  genvar gi;
  generate
    for (gi = 0; gi < TRIT_WIDTH; gi++) begin : gen_zero
      assign zero_val[gi] = T_ZERO;
    end
  endgenerate

  assign rs1_data = (trit2_to_index(rs1_addr) == 0) ?
                    zero_val :
                    regs[trit2_to_index(rs1_addr)];

  assign rs2_data = (trit2_to_index(rs2_addr) == 0) ?
                    zero_val :
                    regs[trit2_to_index(rs2_addr)];

  // Debug read port (direct integer index access)
  assign dbg_reg_data = (dbg_reg_idx == 0 || dbg_reg_idx >= NUM_REGS) ?
                        zero_val :
                        regs[dbg_reg_idx];

  // ============================================================
  // Write port (sequential)
  // ============================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers to zero
      for (int i = 0; i < NUM_REGS; i++) begin
        for (int j = 0; j < TRIT_WIDTH; j++) begin
          regs[i][j] <= T_ZERO;
        end
      end
    end else begin
      // Write to register (R0 writes are ignored)
      if (we && trit2_to_index(rd_addr) != 0) begin
        regs[trit2_to_index(rd_addr)] <= rd_data;
      end
    end
  end

  // ============================================================
  // Debug: register value display (simulation only)
  // ============================================================
  `ifdef SIMULATION
  function automatic string reg_to_string(int idx);
    string s;
    s = "";
    for (int i = TRIT_WIDTH-1; i >= 0; i--) begin
      case (regs[idx][i])
        T_NEG_ONE: s = {s, "-"};
        T_ZERO:    s = {s, "0"};
        T_POS_ONE: s = {s, "+"};
        default:   s = {s, "?"};
      endcase
    end
    return s;
  endfunction

  // Display all registers
  task display_regs();
    $display("=== Register File ===");
    for (int i = 0; i < NUM_REGS; i++) begin
      $display("R%0d: %s (dec: %0d)", i, reg_to_string(i),
               ternary_to_bin(regs[i]));
    end
    $display("====================");
  endtask
  `endif

endmodule
