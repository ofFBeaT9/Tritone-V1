// Ternary CPU System
// Complete system with CPU core and memory
//
// This is the top-level module for FPGA/ASIC implementation

module ternary_cpu_system
  import ternary_pkg::*;
#(
  parameter int TRIT_WIDTH = 27,
  parameter int IMEM_DEPTH = 243,
  parameter int DMEM_DEPTH = 729
)(
  input  logic clk,
  input  logic rst_n,

  // External interface for loading programs (active during reset)
  input  logic                   prog_mode,
  input  logic [7:0]             prog_addr,
  input  trit_t [8:0]            prog_data,
  input  logic                   prog_we,

  // Status outputs
  output logic                   halted,
  output trit_t [7:0]            pc_out,
  output logic                   valid_out,

  // Debug register read port
  input  trit_t [1:0]            debug_reg_addr,
  output trit_t [TRIT_WIDTH-1:0] debug_reg_data
);

  // ============================================================
  // Internal Signals
  // ============================================================

  // CPU <-> Instruction Memory
  trit_t [7:0] imem_addr;
  trit_t [8:0] imem_data;

  // CPU <-> Data Memory
  trit_t [8:0]            dmem_addr;
  trit_t [TRIT_WIDTH-1:0] dmem_wdata;
  trit_t [TRIT_WIDTH-1:0] dmem_rdata;
  logic                   dmem_we;
  logic                   dmem_re;

  // ============================================================
  // CPU Core
  // ============================================================

  ternary_cpu #(
    .TRIT_WIDTH (TRIT_WIDTH),
    .IMEM_DEPTH (IMEM_DEPTH),
    .DMEM_DEPTH (DMEM_DEPTH)
  ) u_cpu (
    .clk        (clk),
    .rst_n      (rst_n),
    .imem_addr  (imem_addr),
    .imem_data  (imem_data),
    .dmem_addr  (dmem_addr),
    .dmem_wdata (dmem_wdata),
    .dmem_rdata (dmem_rdata),
    .dmem_we    (dmem_we),
    .dmem_re    (dmem_re),
    .halted     (halted),
    .pc_out     (pc_out),
    .valid_out  (valid_out)
  );

  // ============================================================
  // Memory
  // ============================================================

  ternary_memory #(
    .TRIT_WIDTH (TRIT_WIDTH),
    .IMEM_DEPTH (IMEM_DEPTH),
    .DMEM_DEPTH (DMEM_DEPTH)
  ) u_memory (
    .clk        (clk),
    .rst_n      (rst_n),
    .imem_addr  (imem_addr),
    .imem_data  (imem_data),
    .dmem_addr  (dmem_addr),
    .dmem_wdata (dmem_wdata),
    .dmem_rdata (dmem_rdata),
    .dmem_we    (dmem_we),
    .dmem_re    (dmem_re)
  );

  // ============================================================
  // Program Loading Interface
  // ============================================================

  // During prog_mode, allow external writes to instruction memory
  // This requires modification to memory module to support this
  // For now, use $readmemh or initial blocks in simulation

  // ============================================================
  // Debug Interface
  // ============================================================

  // The debug register port would need to be added to regfile
  // For now, assign a placeholder
  assign debug_reg_data = TRIT27_ZERO;

endmodule
