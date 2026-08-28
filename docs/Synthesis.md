# Synthesis and Timing Constraints

## 1. Synthesis Overview

The RTL was synthesized with Synopsys Design Compiler using `top_interpolator_dac` as the top-level design and TSMC 65 nm low-power multi-\(V_t\) standard-cell libraries.

The final synthesis flow uses `compile_ultra` for technology mapping and timing optimization.

```text
RTL Analysis / Elaboration
          |
          v
Apply Timing Constraints
          |
          v
Clock-Gating Insertion
          |
          v
compile_ultra
          |
          v
Timing / Constraint Checks
          |
          v
Mapped Netlist + SDC + DDC
```

The final Design Compiler environment used version W-2024.09-SP3.

## 2. Main Timing Constraints

All sequential logic is physically driven by one high-frequency system clock. Multi-rate datapath behavior is controlled by strobes and enables.

| Constraint | Value |
|---|---:|
| System clock period | 1.04167 ns |
| Nominal constrained frequency | 960 MHz |
| Clock uncertainty | 0.05 ns |
| Maximum clock transition | 0.20 ns |
| Input delay | 0.10 ns |
| Output delay | 0.10 ns |
| Output load | 0.05 pF |

The main clock constraint is equivalent to:

```tcl
create_clock -name clk -period 1.041666 \
    -waveform {0 0.520833} [get_ports clk]
```

The 960 MHz constraint covers the highest external clock frequency; \(L=3,5\) operate from a 900 MHz external clock in normal use.

## 3. Multicycle Constraints

Some state is clocked by the high-frequency clock but only updates when a functional strobe occurs. Multicycle constraints model this architectural update interval.

### MINAJ2 and Interpolation Window

Normal input samples arrive every 16 clocks for \(L=2,4\) and every 15 clocks for \(L=3,5\). The synthesis constraints use the shortest legal interval:

```text
setup multicycle = 15
hold multicycle  = 14
```

These constraints apply to the MINAJ2 state and interpolation-window registers driven by the source-sample strobe.

### FIR Output

The fastest output event occurs for \(L=5\), once every three 900 MHz clock cycles:

```text
setup multicycle = 3
hold multicycle  = 2
```

| Region | Functional Enable | Setup MCP | Hold MCP |
|---|---|---:|---:|
| MINAJ2 state | `strobe_iq` | 15 | 14 |
| Interpolation window | `strobe_iq` | 15 | 14 |
| FIR output state | `shift_strobe_iq` | 3 | 2 |

The multicycle paths represent real architectural enable timing rather than being used to mask unconstrained critical paths.

## 4. Clock Gating

Latch-based clock gating is enabled for groups of sequential elements with common enables:

```tcl
set_clock_gating_style -sequential_cell latch -minimum_bitwidth 3
insert_clock_gating
```

This reduces unnecessary sequential switching while preserving a single external clock domain.

## 5. Synthesis Results

| Metric | Result |
|---|---:|
| Worst setup slack | **0.00 ns — MET** |
| Worst pre-layout hold slack | **-0.03 ns** |
| Sequential cells | 1,063 |
| Clock gating | Latch-based |

The small pre-layout hold violation is expected to be addressed after clock-tree synthesis and routing, where physical clock and interconnect delays are available. Final post-layout PrimeTime analysis reports positive hold slack.

## 6. Main Handoff Files

The synthesis stage generates the principal implementation handoff data:

| File | Purpose |
|---|---|
| `top_interpolator_dac.v` | Technology-mapped gate-level netlist |
| `top_interpolator_dac.sdc` | Exported implementation timing constraints |
| `initial.top_interpolator_dac.ddc` | Pre-compile Design Compiler database |
| `final.top_interpolator_dac.ddc` | Final mapped Design Compiler database |
| `compile.vsdc` | Synthesis information used by equivalence checking |
| synthesis reports | Elaboration, timing, and constraint evidence |

The mapped netlist is also used by the dedicated `SAIF_Generation/` simulation flow.

## 7. Repository Location

Synthesis scripts, constraints, selected reports, and public handoff files are kept under:

```text
Synthesis/
```

Foundry libraries and proprietary technology data are referenced from the local EDA environment and are not committed to the public repository.
