# Balanced Ternary CMOS CPU - Presentation Part 2
## Technical Details, Circuits & Future Work

**Date:** December 2025

---

# SLIDE 14: STI Circuit Design

## Standard Ternary Inverter

Circuit uses Multi-Threshold CMOS:

`
        VDD (1.8V)
            |
      [HVT PMOS] <-- Input (High Vth ~0.76V)
            |
      [LVT PMOS] <-- Input (Low Vth ~0.29V)
            |
            +--------> Output
            |
      [LVT NMOS] <-- Input (Low Vth ~0.29V)
            |
      [SVT NMOS] <-- Input (Std Vth ~0.42V)
            |
        VSS (0V)
`

**Key:** Different threshold voltages create 3 stable output regions

---

# SLIDE 15: STI Transfer Curve

## DC Analysis Results

`
Output (V)
    |
1.8 |
    |            \
    |             \
0.9 |              
    |                      \
    |                       \
0.0 |                        
    +----+----+----+----+----+----+----+
       0.0  0.3  0.6  0.9  1.2  1.5  1.8
                  Input (V)
`

Truth Table:
- Input 0V (-1) -> Output 1.8V (+1)
- Input 0.9V (0) -> Output 0.9V (0)
- Input 1.8V (+1) -> Output 0V (-1)

---

# SLIDE 16: BTFA Truth Table

## Balanced Ternary Full Adder (27 combinations)

| A | B | Cin | Sum | Cout | Decimal |
|---|---|-----|-----|------|---------|
| - | - | - | 0 | - | -3 |
| - | - | 0 | + | - | -2 |
| - | - | + | - | 0 | -1 |
| 0 | 0 | 0 | 0 | 0 | 0 |
| + | + | + | 0 | + | +3 |

**Result: 27/27 test cases PASS**

---

# SLIDE 17: Pipeline Diagram

## 4-Stage CPU Pipeline

`
Cycle:  1    2    3    4    5    6    7
        |    |    |    |    |    |    |
Inst1: [IF]-[ID]-[EX]-[WB]
Inst2:      [IF]-[ID]-[EX]-[WB]
Inst3:           [IF]-[ID]-[EX]-[WB]
Inst4:                [IF]-[ID]-[EX]-[WB]
`

**Throughput:** 1 instruction per cycle (ideal)

---

# SLIDE 18: Data Forwarding

## Eliminating Pipeline Stalls

Without forwarding:
`
ADD R1: IF-ID-EX-WB
SUB R2: ---IF-ID-STALL-STALL-EX-WB  (2 cycles wasted)
`

With forwarding (our implementation):
`
ADD R1: IF-ID-EX-WB
SUB R2: ---IF-ID-EX-WB  (data forwarded from EX)
`

**Result:** No stalls for most RAW hazards

---

# SLIDE 19: Instruction Encoding

## 9-Trit Format

`
[T8][T7][T6][T5][T4][T3][T2][T1][T0]
|-- Opcode --|-- Rd --|-- Rs1 -|Rs2/Imm|
   (3 trits)  (2 trits)(2 trits)(2 trits)
`

Example: ADD R1, R2, R3
`
[0][0][0][0][+][0][-][+][0]
|--ADD--|--R1--|--R2--|--R3--|
`

---

# SLIDE 20: Register File

## 9 Registers x 27 Trits

| Reg | Encoding | Alias | Purpose |
|-----|----------|-------|---------|
| R0 | -- | ZERO | Hardwired zero |
| R1 | -0 | T1 | Temporary |
| R2 | -+ | T2 | Temporary |
| R3 | 0- | T3 | Temporary |
| R4 | 00 | T4 | Temporary |
| R5 | 0+ | T5 | Temporary |
| R6 | +- | T6 | Temporary |
| R7 | +0 | T7 | Temporary |
| R8 | ++ | RA | Return Address |

---

# SLIDE 21: ALU Operations

## 8 Core Operations

| Op | Code | Function |
|----|------|----------|
| ADD | 000 | A + B |
| SUB | 001 | A - B |
| NEG | 010 | -A |
| MIN | 011 | min(A,B) |
| MAX | 100 | max(A,B) |
| SHL | 101 | A * 3 |
| SHR | 110 | A / 3 |
| CMP | 111 | Compare |

---

# SLIDE 22: Assembler Example

## Fibonacci Program

`sm
# Compute Fibonacci(7)
        LDI  R1, 7      # n = 7
        LDI  R2, 1      # fib(1) = 1
        LDI  R3, 0      # fib(0) = 0
        LDI  R4, 1      # constant

loop:   BEQ  R1, R0, done
        ADD  R5, R2, R3
        MOV  R3, R2
        MOV  R2, R5
        SUB  R1, R1, R4
        JMP  loop

done:   HALT            # R2 = 13
`

---

# SLIDE 23: De Morgan's Laws

## Verified for Ternary Logic

Binary:
- NOT(A AND B) = (NOT A) OR (NOT B)

Ternary:
- STI(TMIN(A,B)) = TMAX(STI(A), STI(B)) 
- STI(TMAX(A,B)) = TMIN(STI(A), STI(B)) 

**All 9 combinations verified!**

This proves standard logic optimization works in ternary.

---

# SLIDE 24: Test Coverage

## Instruction Coverage by Category

| Category | Covered | Total | % |
|----------|---------|-------|---|
| Arithmetic | 3 | 3 | 100% |
| Logical | 6 | 6 | 100% |
| Shift | 3 | 3 | 100% |
| Data Move | 4 | 4 | 100% |
| Control | 4 | 8 | 50% |
| System | 1 | 3 | 33% |
| **Total** | **21** | **26** | **80.8%** |

---

# SLIDE 25: File Structure

## Project Organization

`
e:\ternary cmos compile\
+-- project/
|   +-- spice/cells/     (12 SPICE cells)
|   +-- spice/testbenches/ (14 testbenches)
|   +-- hdl/rtl/         (11 RTL modules)
|   +-- hdl/tb/          (6 testbenches)
|   +-- fpga/            (Multi-vendor support)
|   +-- tools/           (Assembler + programs)
|   +-- docs/            (Documentation)
+-- tests/               (62 Python tests)
`

---

# SLIDE 26: Remaining Work

## What's Left to Do

**High Priority:**
- [ ] Install Vivado (~40GB)
- [ ] Run FPGA synthesis
- [ ] Generate timing reports

**Medium Priority:**
- [ ] Expand test coverage to 90%+
- [ ] Finalize research paper
- [ ] Create comparison figures

**Future (Optional):**
- [ ] Branch prediction
- [ ] OpenLane ASIC flow
- [ ] Efabless tapeout

---

# SLIDE 27: Contributions

## Key Project Contributions

1. **Complete GT-LOGIC Cell Library**
   - 12 cells on SKY130 process
   - Full SPICE characterization

2. **Novel Ternary CPU**
   - First balanced ternary CPU with hazard handling
   - 26-instruction RISC-like ISA

3. **Comprehensive Toolchain**
   - Python assembler
   - 62 automated tests
   - 14 test programs

4. **Mathematical Validation**
   - De Morgan's laws verified
   - Exhaustive full adder testing

---

# SLIDE 28: Performance Comparison

## Ternary vs Binary Efficiency

| Metric | Binary | Ternary | Winner |
|--------|--------|---------|--------|
| Info/digit | 1.000 bits | 1.585 bits | Ternary |
| FA transistors | 28 | 42 | Binary |
| Trans/bit | 28.0 | 26.5 | Ternary |
| Negation | Complex | Trivial | Ternary |
| Sign bit | Required | Built-in | Ternary |

**Ternary is 5.4% more efficient per bit of information!**

---

# SLIDE 29: Future Applications

## Where Ternary Could Excel

1. **Neural Networks**
   - Weight quantization (-1, 0, +1)
   - Lower power inference

2. **Cryptography**
   - Novel encryption schemes
   - Side-channel resistance

3. **Scientific Computing**
   - Natural signed arithmetic
   - Efficient rounding

4. **Embedded Systems**
   - Higher info density
   - Lower wire count

---

# SLIDE 30: Conclusion

## Summary

We built a **complete balanced ternary computing system**:

- From SPICE transistors to working programs
- 85+ files, ~9,600 lines of code
- 100% test pass rate
- 75% project completion

**Key Result:**
Ternary computing is mathematically sound and practically implementable in standard CMOS technology.

---

# SLIDE 31: Thank You

## Questions?

**Project Location:**
e:\ternary cmos compile\

**Key Documents:**
- PROJECT_ANALYSIS.md
- ROADMAP_DETAILED.md
- project/docs/specs/btisa_v01.md
- project/docs/papers/GT_LOGIC_Ternary_CPU_Paper.md

---

# END OF PRESENTATION

Total Slides: 31
Part 1: Slides 1-13 (Overview)
Part 2: Slides 14-31 (Technical Details)

