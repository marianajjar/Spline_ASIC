# Synthesis and Timing Constraints

## 1. Synthesis Overview

The RTL was synthesized using **Synopsys Design Compiler** with `top_interpolator_dac` as the top-level design.

The synthesis flow uses the TSMC 65 nm standard-cell libraries with a multi-Vt cell set:

- RVT — regular threshold-voltage cells;
- LVT — low threshold-voltage cells;
- HVT — high threshold-voltage cells.

The main synthesis sequence is:

```text
RTL analysis and elaboration
        ↓
Apply timing constraints
        ↓
Insert clock gating
        ↓
compile_ultra
        ↓
Timing / area / constraint checks
        ↓
Mapped gate-level netlist + SDC + DDC
```

`compile_ultra` is used for technology mapping and timing optimization. Clock gating is enabled using latch-based integrated clock-gating structures for groups of three or more sequential elements.

---

## 2. Main Timing Constraints

Although the datapath operates at several effective sample rates, all sequential logic is driven by the same high-frequency system clock. The slower processing rates are created by clock-enable strobes, so the SDC constrains a single clock domain.

| Constraint | Value |
|---|---:|
| System clock period | 1.04167 ns |
| Nominal clock frequency | 960 MHz |
| Clock uncertainty | 0.05 ns |
| Maximum clock transition | 0.20 ns |
| Input delay | 0.10 ns |
| Output delay | 0.10 ns |
| Output load | 0.05 |

The main clock constraint is:

```tcl
create_clock -name clk -period 1.041666 \
    -waveform {0 0.520833} [get_ports clk]
```

Input delays are applied to the non-clock inputs, while output delay and load constraints are applied to the DAC outputs.

---

## 3. Multicycle Path Constraints

The design contains registers that are physically clocked by the high-frequency system clock but functionally update only when their corresponding strobe is asserted.

Multicycle constraints are therefore used to model the **actual functional update interval** of these paths rather than requiring every path to complete in a single system-clock cycle.

### 3.1 MINAJ2 and Interpolation-Window Paths

The MINAJ2 slope state and interpolation-window registers update at the input-sample rate through `strobe_iq`.

Normal input words require:

```text
15 clock cycles for L = 3, 5
16 clock cycles for L = 2, 4
```

The synthesis constraints use the shortest legal interval, **15 clock cycles**, so the paths remain valid for every supported mode.

```tcl
set_multicycle_path 15 -setup ...
set_multicycle_path 14 -hold  ...
```

These constraints are applied to the MINAJ2 state registers and the I/Q interpolation-window registers.

### 3.2 FIR Output Paths

The FIR output is updated by `shift_strobe_iq`. The highest output rate occurs for `L=5`, where a new interpolated sample is processed once every three 900 MHz clock cycles.

The FIR output-register paths are therefore constrained as:

```tcl
set_multicycle_path 3 -setup ...
set_multicycle_path 2 -hold  ...
```

The setup constraint gives the path three system-clock cycles, while the corresponding `N-1` hold constraint preserves the correct launch/capture relationship.

### 3.3 Multicycle Summary

| Datapath Region | Functional Enable | Setup MCP | Hold MCP | Reason |
|---|---|---:|---:|---|
| MINAJ2 state | `strobe_iq` | 15 | 14 | New source sample every 15/16 clocks |
| Interpolation window | `strobe_iq` | 15 | 14 | Updated once per source-sample interval |
| FIR output registers | `shift_strobe_iq` | 3 | 2 | Fastest output event is once every 3 clocks |

The multicycle paths reflect architectural enable timing; they are not used simply to hide timing-critical combinational paths.

---

## 4. Clock Gating

Clock gating is inserted during synthesis using:

```tcl
set_clock_gating_style -sequential_cell latch -minimum_bitwidth 3
insert_clock_gating
```

This allows groups of sequential elements with common enable conditions to use synthesized clock-gating structures instead of unnecessary register switching on every system-clock edge.

Key MINAJ2, FIR, and Sample Shift hierarchy is preserved through the clock-gating and synthesis stages to simplify implementation analysis and later equivalence checking.

---

## 5. Synthesis Results

The final mapped design contains:

| Metric | Post-Compile Result |
|---|---:|
| Total cells | 25,916 |
| Combinational cells | 24,810 |
| Sequential cells | 1,063 |
| Buffers / inverters | 2,476 |
| Macros / black boxes | 0 |
| Worst setup slack | **0.00 ns — MET** |
| Worst hold slack | **-0.03 ns** |

The worst reported setup path meets the synthesis timing constraint.

A small **-0.03 ns hold violation** remains in the synthesis report. The minimum-delay violations are associated mainly with very short input-to-register paths, including coefficient-loading, sample-history, and serial-input registers. Hold timing is checked again after physical implementation, where actual clock-tree and routing delays are available.


---

## 6. Generated Outputs

The synthesis flow produces the main implementation handoff files:

| File | Purpose |
|---|---|
| `top_interpolator_dac.v` | Technology-mapped gate-level netlist |
| `top_interpolator_dac.sdc` | Exported implementation timing constraints |
| `initial.top_interpolator_dac.ddc` | Pre-compile Design Compiler database |
| `final.top_interpolator_dac.ddc` | Final mapped Design Compiler database |
| `compile.vsdc` | Synthesis setup information used by the equivalence flow |
| `post_elaborate.rpt` | Elaboration checks |
| `post_compile.rpt` | Final synthesis timing, area, and constraint report |

These outputs are used by the following physical-design, STA, and equivalence-checking stages.

---

## 7. Summary

The design was synthesized with a 1.04167 ns system-clock constraint using multi-Vt TSMC 65 nm libraries and `compile_ultra`.

Because the architecture uses clock-enable strobes rather than separate internal clocks, multicycle constraints are applied to the state that functionally updates at the 60 MSa/s input rate and the interpolated output rate. The final mapped design contains **25,916 cells**, meets the synthesis setup constraint with **0.00 ns worst setup slack**, and reports a small **-0.03 ns pre-layout hold violation** for short paths.
