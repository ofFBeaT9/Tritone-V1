# Tritone: A Balanced Ternary CMOS Processor

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![HDL: SystemVerilog](https://img.shields.io/badge/HDL-SystemVerilog-blue.svg)]()
[![SPICE: ngspice](https://img.shields.io/badge/SPICE-ngspice-green.svg)]()
[![Status: Research](https://img.shields.io/badge/Status-Research-orange.svg)]()

**Tritone** is a complete balanced ternary computing platform implemented in standard CMOS technology. It includes a transistor-level cell library, synthesizable RTL, a 4-stage pipelined CPU, assembler toolchain, and comprehensive test suite.

> *"Perhaps the prettiest number system of all is the balanced ternary notation."*
> — Donald Knuth, The Art of Computer Programming

---

## Table of Contents

- [Overview](#overview)
- [Why Balanced Ternary?](#why-balanced-ternary)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [The GT-LOGIC Cell Library](#the-gt-logic-cell-library)
- [BTISA Instruction Set](#btisa-instruction-set)
- [CPU Microarchitecture](#cpu-microarchitecture)
- [Synthesis Results](#synthesis-results)
- [Test Coverage](#test-coverage)
- [FPGA Implementation](#fpga-implementation)
- [Tools & Scripts](#tools--scripts)
- [Documentation](#documentation)
- [Roadmap](#roadmap)
- [References](#references)
- [License](#license)

---

## Overview

Tritone demonstrates that **practical ternary computing is achievable with standard CMOS technology**. Instead of requiring exotic devices like carbon nanotubes or memristors, this project uses voltage-mode encoding with multi-threshold transistors available in any modern process.

### Key Features

| Feature | Description |
|---------|-------------|
| **12 SPICE Cells** | Complete ternary logic library validated with SKY130 PDK |
| **27-Trit Datapath** | ~42.8 bits equivalent information capacity |
| **4-Stage Pipeline** | IF → ID → EX → WB with hazard detection |
| **26 Instructions** | Full ISA: arithmetic, logic, memory, control flow |
| **Data Forwarding** | Zero-stall forwarding for RAW hazards |
| **Multi-Vendor FPGA** | Xilinx, Lattice, and Intel/Altera support |
| **Python Assembler** | Full toolchain with pseudo-instructions |
| **80.8% Test Coverage** | 21/26 instructions validated |

### Project Status

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 1 | SPICE Cell Library | ✅ Complete |
| Phase 2 | RTL Synthesis | ✅ Complete |
| Phase 3 | FPGA Prototype | 🟡 75% (design ready) |
| Phase 4 | CPU Core | ✅ Complete |
| Phase 5 | Documentation & Testing | 🟡 In Progress |

---

## Why Balanced Ternary?

### The Three Values

Balanced ternary uses three symmetric values:

| Symbol | Value | Voltage (1.8V) | Description |
|--------|-------|----------------|-------------|
| **−** | -1 | 0V (GND) | Negative one |
| **0** | 0 | 0.9V (VDD/2) | Zero |
| **+** | +1 | 1.8V (VDD) | Positive one |

### Advantages Over Binary

| Property | Binary | Balanced Ternary | Benefit |
|----------|--------|------------------|---------|
| Information per digit | 1.000 bits | 1.585 bits | **+58.5% density** |
| 8-digit range | 256 values | 6,561 values | **25.6× larger** |
| Negation | Two's complement | Flip all signs | **Trivial operation** |
| Sign representation | Separate sign bit | Inherent in digits | **No overhead** |
| Rounding | Complex | Truncation = rounding | **Natural** |

### Number Examples

| Decimal | Balanced Ternary | Calculation |
|---------|------------------|-------------|
| 0 | `0` | 0 |
| 1 | `+` | +1 |
| 5 | `+−−` | 9 − 3 − 1 = 5 |
| -5 | `−++` | -9 + 3 + 1 = -5 |
| 13 | `+++` | 9 + 3 + 1 = 13 |
| 42 | `+−++0` | 81 − 27 + 9 + 3 + 0 = 66... |

---

## Architecture

### System Block Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    BALANCED TERNARY CPU SYSTEM                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐          │
│  │   IF    │───▶│   ID    │───▶│   EX    │───▶│   WB    │          │
│  │  Fetch  │    │ Decode  │    │ Execute │    │  Write  │          │
│  └────┬────┘    └────┬────┘    └────┬────┘    └────┬────┘          │
│       │              │              │              │                 │
│       │         ┌────┴────┐        │              │                 │
│       │         │ Register│◀───────┴──────────────┘                 │
│       │         │  File   │                                          │
│       │         │ 9×27-trit│                                         │
│       │         └────┬────┘                                          │
│       │              │                                               │
│  ┌────┴────┐   ┌────┴────┐   ┌─────────┐   ┌─────────┐             │
│  │  IMEM   │   │ Hazard  │   │   ALU   │   │  DMEM   │             │
│  │ 243×9t  │   │ + Fwd   │   │  8 ops  │   │ 729×27t │             │
│  └─────────┘   └─────────┘   └─────────┘   └─────────┘             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Layer | Technology | Location |
|-------|------------|----------|
| Transistor | SKY130 PDK (1.8V) | `spice/cells/` |
| Cell Library | ngspice simulation | `asic/lib/` |
| RTL | SystemVerilog | `hdl/rtl/` |
| FPGA | Xilinx/Lattice/Intel | `fpga/` |
| Software | Python assembler | `tools/` |
| Testing | pytest + cocotb | `tests/` |

---

## Project Structure

```
tritone-complete/
├── hdl/                          # Hardware Description Language
│   ├── rtl/                      # Synthesizable RTL modules
│   │   ├── ternary_pkg.sv        # Type definitions & functions
│   │   ├── btfa.sv               # Balanced Ternary Full Adder
│   │   ├── ternary_adder.sv      # N-trit parametric adder
│   │   ├── ternary_alu.sv        # 8-operation ALU
│   │   ├── ternary_regfile.sv    # 9×27-trit register file
│   │   ├── btisa_decoder.sv      # Instruction decoder
│   │   ├── ternary_cpu.sv        # 4-stage pipeline CPU
│   │   ├── ternary_hazard_unit.sv# RAW hazard detection
│   │   ├── ternary_forward_unit.sv# Data forwarding
│   │   ├── ternary_memory.sv     # Memory interface
│   │   └── ternary_cpu_system.sv # Top-level system
│   ├── tb/                       # Testbenches
│   └── sim/                      # Simulation scripts & outputs
│
├── spice/                        # SPICE Cell Library
│   ├── cells/                    # 12 ternary cell definitions
│   │   ├── sti.spice             # Standard Ternary Inverter
│   │   ├── pti.spice             # Positive Threshold Inverter
│   │   ├── nti.spice             # Negative Threshold Inverter
│   │   ├── tmin.spice            # Ternary MIN (AND)
│   │   ├── tmax.spice            # Ternary MAX (OR)
│   │   ├── btfa.spice            # Full Adder (42 transistors)
│   │   └── ...
│   ├── testbenches/              # Cell validation circuits
│   ├── models/                   # SKY130 SPICE models
│   └── results/                  # Simulation outputs (CSV, logs)
│
├── fpga/                         # FPGA Implementation
│   ├── src/                      # FPGA wrappers & testbenches
│   ├── constraints/              # Timing constraints
│   │   ├── ternary_alu.xdc       # Xilinx
│   │   ├── ternary_alu_lattice.lpf# Lattice
│   │   └── ternary_alu_quartus.sdc# Intel/Altera
│   └── scripts/                  # Build scripts (TCL)
│
├── asic/                         # ASIC Library Files
│   └── lib/
│       └── gt_logic_ternary.lib  # Liberty timing library
│
├── tools/                        # Software Tools
│   ├── btisa_assembler.py        # BTISA assembler (434 lines)
│   ├── programs/                 # Assembly test programs (.btasm)
│   ├── scripts/                  # PowerShell automation
│   └── synthesis/                # RTL synthesis utilities
│
├── tests/                        # Python Test Suite
│   ├── test_btisa_assembler.py   # 36 assembler tests
│   ├── test_ternary_logic.py     # 23 logic tests
│   └── test_hello_world.py       # 3 integration tests
│
├── docs/                         # Documentation
│   ├── specs/                    # Technical specifications
│   │   ├── btisa_v01.md          # ISA specification
│   │   └── gt_logic_cells.md     # Cell library spec
│   ├── papers/                   # Research paper draft
│   ├── presentations/            # Slide content
│   └── qa/                       # QA reports & gates
│
└── eda playground/               # EDA tool experiments
    └── log.txt                   # Yosys synthesis log
```

---

## Quick Start

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.8+ | Assembler, test scripts |
| Icarus Verilog | 12.0+ | RTL simulation |
| ngspice | 42+ | SPICE simulation |
| Node.js | 18+ | Presentation generator (optional) |

### 1. Run CPU Simulation

```bash
cd hdl/sim
./run_cpu_sim.bat          # Windows
./run_sim.sh               # Linux/macOS
```

Or manually:
```bash
cd hdl
iverilog -g2012 -o tb_cpu.vvp \
    rtl/ternary_pkg.sv \
    rtl/btfa.sv \
    rtl/ternary_adder.sv \
    rtl/ternary_alu.sv \
    rtl/ternary_regfile.sv \
    rtl/btisa_decoder.sv \
    rtl/ternary_hazard_unit.sv \
    rtl/ternary_forward_unit.sv \
    rtl/ternary_memory.sv \
    rtl/ternary_cpu.sv \
    rtl/ternary_cpu_system.sv \
    tb/tb_ternary_cpu.sv

vvp tb_cpu.vvp
```

### 2. Assemble a Program

```bash
cd tools
python btisa_assembler.py programs/test_arithmetic.btasm -o output.mem
```

### 3. Run SPICE Simulations

```bash
cd spice
ngspice testbenches/tb_btfa_cin0_dc.spice
```

### 4. Run Python Tests

```bash
pytest tests/ -v
```

---

## The GT-LOGIC Cell Library

### Cell Inventory

| Cell | Function | Transistors | Validated |
|------|----------|-------------|-----------|
| **STI** | Y = −A (full invert) | 6 | ✅ |
| **PTI** | Positive threshold | 6 | ✅ |
| **NTI** | Negative threshold | 6 | ✅ |
| **TMIN** | Y = MIN(A,B) — AND | 10 | ✅ |
| **TMAX** | Y = MAX(A,B) — OR | 10 | ✅ |
| **TNAND** | Y = −MIN(A,B) | 16 | ✅ |
| **TNOR** | Y = −MAX(A,B) | 16 | ✅ |
| **TSUM** | Sum without carry | 20 | ✅ |
| **TMUX3** | 3:1 Multiplexer | 24 | ✅ |
| **BTHA** | Half Adder | 30 | ✅ |
| **BTFA** | Full Adder | 42 | ✅ |

### Standard Ternary Inverter (STI)

The fundamental cell — implements balanced ternary negation:

| Input | Output |
|-------|--------|
| +1 (1.8V) | −1 (0V) |
| 0 (0.9V) | 0 (0.9V) |
| −1 (0V) | +1 (1.8V) |

### Balanced Ternary Full Adder (BTFA)

The BTFA computes `Sum = (A + B + Cin) mod 3` and `Cout = (A + B + Cin) div 3`.

**Exhaustive validation: 27/27 test vectors PASS (100%)**

---

## BTISA Instruction Set

### Overview

- **Word size**: 27 trits (~42.8 bits equivalent)
- **Registers**: 9 general-purpose (R0-R8), R0 hardwired to zero
- **Memory**: 243 instruction words, 729 data words
- **Encoding**: 9 trits per instruction

### Instruction Encoding

```
[8:6] Opcode  (3 trits = 27 opcodes possible)
[5:4] Rd      (2 trits = 9 registers)
[3:2] Rs1     (2 trits = 9 registers)
[1:0] Rs2/Imm (2 trits = 9 values or register)
```

### Complete Instruction Set (26 Instructions)

#### Arithmetic Operations
| Mnemonic | Operation | Description |
|----------|-----------|-------------|
| `ADD` | Rd = Rs1 + Rs2 | Ternary addition |
| `SUB` | Rd = Rs1 − Rs2 | Ternary subtraction |
| `NEG` | Rd = −Rs1 | Negate (flip all trits) |
| `MUL` | Rd = Rs1 × Rs2 | Multiply (future) |
| `SHL` | Rd = Rs1 << 1 | Shift left (×3) |
| `SHR` | Rd = Rs1 >> 1 | Shift right (÷3) |
| `ADDI` | Rd = Rs1 + Imm | Add immediate |

#### Logic Operations
| Mnemonic | Operation | Description |
|----------|-----------|-------------|
| `MIN` | Rd = MIN(Rs1, Rs2) | Tritwise minimum (AND) |
| `MAX` | Rd = MAX(Rs1, Rs2) | Tritwise maximum (OR) |
| `XOR` | Rd = Rs1 XOR Rs2 | Ternary XOR (mod-3 add) |
| `INV` | Rd = STI(Rs1) | Standard ternary invert |
| `PTI` | Rd = PTI(Rs1) | Positive threshold invert |
| `NTI` | Rd = NTI(Rs1) | Negative threshold invert |

#### Memory Operations
| Mnemonic | Operation | Description |
|----------|-----------|-------------|
| `LD` | Rd = Mem[Rs1+Imm] | Load word |
| `ST` | Mem[Rs1+Imm] = Rs2 | Store word |
| `LDT` | Rd = Mem[Rs1][Imm] | Load single trit |
| `STT` | Mem[Rs1][Imm] = Rs2[0] | Store single trit |
| `LUI` | Rd = Imm << 18 | Load upper immediate |

#### Control Flow
| Mnemonic | Operation | Description |
|----------|-----------|-------------|
| `BEQ` | if Rs1=Rs2: PC += Imm | Branch if equal |
| `BNE` | if Rs1≠Rs2: PC += Imm | Branch if not equal |
| `BLT` | if Rs1<Rs2: PC += Imm | Branch if less than |
| `JAL` | Rd = PC+1; PC = Rs1+Imm | Jump and link |
| `JALR` | Rd = PC+1; PC = Rs1 | Jump and link register |
| `JR` | PC = Rs1 | Jump register (return) |

#### System Operations
| Mnemonic | Operation | Description |
|----------|-----------|-------------|
| `NOP` | — | No operation |
| `HALT` | — | Halt execution |
| `ECALL` | — | Environment call |

### Example Program

```asm
# Compute sum of 1 + 2 + 3 = 6
    LDI  R1, 1        # R1 = 1
    LDI  R2, 2        # R2 = 2
    LDI  R3, 3        # R3 = 3
    ADD  R4, R1, R2   # R4 = 1 + 2 = 3
    ADD  R5, R4, R3   # R5 = 3 + 3 = 6
    HALT
```

---

## CPU Microarchitecture

### 4-Stage Pipeline

```
┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
│   IF   │───▶│   ID   │───▶│   EX   │───▶│   WB   │
│ Fetch  │    │ Decode │    │Execute │    │ Write  │
└────────┘    └────────┘    └────────┘    └────────┘
    │              │              │              │
    ▼              ▼              ▼              ▼
  IMEM          RegFile         ALU          RegFile
  Read           Read         Compute         Write
```

### Pipeline Features

| Feature | Implementation |
|---------|----------------|
| **Hazard Detection** | RAW hazard detection unit |
| **Load-Use Stall** | 1-cycle stall for memory dependencies |
| **Data Forwarding** | EX→EX, WB→EX forwarding paths |
| **Branch Handling** | 2-cycle penalty with flush |

### Forwarding Example

```asm
LDI  R1, 1       # R1 = 1
ADD  R2, R1, 1   # R2 = R1 + 1 (forward from EX)
ADD  R3, R2, 1   # R3 = R2 + 1 (forward from EX)
ADD  R4, R3, 1   # R4 = R3 + 1 (forward from EX)
```

Result: R1=1, R2=2, R3=3, R4=4 — **zero stall cycles** due to forwarding.

---

## Synthesis Results

### Yosys Synthesis (from EDA Playground)

```
=== ternary_cpu ===
   Number of wires:                533
   Number of wire bits:           1114
   Number of cells:                821

=== design hierarchy ===
   ternary_cpu                       1
     ternary_regfile                 1
     ternary_adder (WIDTH=8)         2
     ternary_alu (WIDTH=27)          1
     btisa_decoder                   1
     ternary_forward_unit            1
     ternary_hazard_unit             1

   Total cells:                    814
     BUFG                            1
     FDCE                          164
     IBUF                           42
     INV                           246
     LUT1                           54
     LUT2                           13
     LUT3                           27
     LUT5                           64
     LUT6                           36
     MUXF7                          54
     MUXF8                          27
     OBUF                           86
```

### Resource Summary

| Resource | Count |
|----------|-------|
| Flip-Flops (FDCE) | 164 |
| LUTs (total) | 194 |
| Inverters | 246 |
| Multiplexers | 81 |
| I/O Buffers | 128 |
| **Total Cells** | **814** |

---

## Test Coverage

### Instruction Coverage: 80.8% (21/26)

| Category | Tested | Total | Coverage |
|----------|--------|-------|----------|
| Arithmetic | 3 | 3 | 100% |
| Logical | 6 | 6 | 100% |
| Shift | 3 | 3 | 100% |
| Data Movement | 4 | 4 | 100% |
| Control Flow | 4 | 8 | 50% |
| System | 1 | 2 | 50% |

### Test Programs

| Program | Instructions Tested |
|---------|---------------------|
| `test_arithmetic.btasm` | ADD, SUB, NEG, MUL |
| `test_logical.btasm` | MIN, MAX, XOR, INV |
| `test_bitwise.btasm` | AND, OR, XOR |
| `test_shift.btasm` | SHL, SHR |
| `test_shift_extended.btasm` | SRA |
| `test_control_flow.btasm` | BEQ, BNE, BEQZ, BNEZ |
| `test_data_movement.btasm` | LDI, MOV, LDT, STT |
| `test_hazards.btasm` | Pipeline hazard scenarios |
| `test_memory_stress.btasm` | Memory edge cases |

### Python Test Suite

| Test File | Tests | Status |
|-----------|-------|--------|
| `test_btisa_assembler.py` | 36 | ✅ 100% pass |
| `test_ternary_logic.py` | 23 | ✅ 100% pass |
| `test_hello_world.py` | 3 | ✅ 100% pass |
| **Total** | **62** | **100% pass** |

---

## FPGA Implementation

### Multi-Vendor Support

| Vendor | Constraint File | Build Script |
|--------|-----------------|--------------|
| Xilinx | `ternary_alu.xdc` | `build.tcl` |
| Lattice | `ternary_alu_lattice.lpf` | `build_lattice.tcl` |
| Intel/Altera | `ternary_alu_quartus.sdc` | `build_quartus.tcl` |

### Resource Projection (Artix-7)

| Resource | Estimated | Available | Utilization |
|----------|-----------|-----------|-------------|
| LUTs | ~2,500 | 20,800 | 12% |
| FFs | ~1,200 | 41,600 | 3% |
| BRAM | 2 | 50 | 4% |
| DSP | 0 | 90 | 0% |

### Timing

- **Target**: 50 MHz
- **Critical Path**: 27-trit ripple-carry adder
- **Estimated Fmax**: 25-40 MHz

---

## Tools & Scripts

### BTISA Assembler

```bash
python btisa_assembler.py <input.btasm> [-o output.mem]
```

**Features:**
- All 26 instructions supported
- Pseudo-instructions: `LDI`, `MOV`, `JMP`, `RET`, `BEQZ`, `BNEZ`
- Label support for branches
- Multiple output formats (SV, hex, binary)

### Automation Scripts

| Script | Purpose |
|--------|---------|
| `run_test.ps1` | Run individual test programs |
| `batch_assemble.ps1` | Assemble all programs |
| `ci_smoke_test.ps1` | CI validation suite |
| `analyze_performance.ps1` | Performance profiling |

---

## Documentation

| Document | Description |
|----------|-------------|
| `docs/specs/btisa_v01.md` | Complete ISA specification |
| `docs/specs/gt_logic_cells.md` | Cell library specification |
| `docs/GETTING_STARTED.md` | Setup and installation guide |
| `docs/IMPLEMENTATION_ROADMAP.md` | Development milestones |
| `docs/papers/GT_LOGIC_Ternary_CPU_Paper.md` | Research paper draft |
| `ternary_technology_comparison.md` | Multi-Vth CMOS vs TFET analysis |
| `PROJECT_ANALYSIS.md` | Complete project analysis |
| `ROADMAP_DETAILED.md` | Detailed development roadmap |

---

## Roadmap

### Completed

- [x] 12-cell SPICE library with SKY130 validation
- [x] BTFA with 100% exhaustive test coverage
- [x] 4-stage pipelined CPU with hazard handling
- [x] 26-instruction ISA specification
- [x] Python assembler with pseudo-instructions
- [x] 80.8% instruction test coverage
- [x] Multi-vendor FPGA constraints
- [x] Performance profiling framework

### In Progress

- [ ] FPGA synthesis validation (requires Vivado)
- [ ] Expand test coverage to 95%
- [ ] Research paper finalization

### Future Work

- [ ] Branch prediction (backward-taken predictor)
- [ ] Carry-lookahead adder for improved timing
- [ ] Cache hierarchy
- [ ] ASIC tapeout via Efabless/SKY130

---

## References

1. **Knuth, D.** "The Art of Computer Programming, Vol. 2" — Section on balanced ternary
2. **Brusentsov, N.** "Setun: The First Ternary Computer" — Comm. ACM, 1962
3. **Ko, M. et al.** "Design of Ternary Logic Gates Using Standard CMOS" — IEEE Access, 2021
4. **SkyWater SKY130 PDK** — [skywater-pdk.readthedocs.io](https://skywater-pdk.readthedocs.io/)
5. **Mouftah & Jordan** "Design of Ternary COS/MOS Memory" — IEEE Trans. Computers, 1977

---

## License

This project is released under the MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- SkyWater Technology Foundry for the open-source PDK
- Efabless for open-source silicon access
- The ngspice development team

---

**Repository:** [github.com/ofFBeaT9/Tritone-V1](https://github.com/ofFBeaT9/Tritone-V1)

*Built with balanced ternary logic — the most elegant number system.*
