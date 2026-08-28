# Synthesis and Timing Constraints

## 1. Synthesis Overview

The RTL was synthesized with Synopsys Design Compiler using `top_interpolator_dac` as the top-level design.

Technology mapping uses TSMC 65 nm low-power multi-Vt standard-cell libraries. The final Design Compiler version used for the project was W-2024.09-SP3.

```text
RTL Analysis / Elaboration
          |
          v
Apply SDC Constraints
          |
          v
Insert Clock Gating
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

## 2. System Clock Constraint

The synthesis SDC uses the highest external clock frequency, 960 MHz:

$$
T_{clk}=1.04167\ \text{ns}.
$$

Main constraints:

| Constraint | Value |
|---|---:|
| Clock period | 1.04167 ns |
| Nominal synthesis clock | 960 MHz |
| Clock uncertainty | 0.05 ns |
| Maximum clock transition | 0.20 ns |
| Input delay | 0.10 ns |
| Output delay | 0.10 ns |
| Output load | 0.05 pF |

Example clock definition:

```tcl
create_clock -name clk -period 1.041666 \
    -waveform {0 0.520833} [get_ports clk]
```

The \(L=3,5\) operating modes use a 900 MHz external clock in normal chip operation.

## 3. Why Multicycle Constraints Are Required

All sequential logic is physically clocked by the high-frequency clock. However, much of the datapath updates only when a slower functional strobe is asserted.

The multicycle constraints therefore model real architectural update intervals.

### Source-Sample / MINAJ2 State

Normal input samples arrive every:

```text
16 clocks for L=2,4
15 clocks for L=3,5
```

The shortest legal interval is 15 clocks:

```text
setup MCP = 15
hold MCP  = 14
```

This is applied to the MINAJ2 state and interpolation-window state controlled by `strobe_iq`.

### FIR Output State

The fastest interpolation event is \(L=5\), one event every three 900 MHz clock cycles:

```text
setup MCP = 3
hold MCP  = 2
```

| Datapath Region | Functional Enable | Setup MCP | Hold MCP |
|---|---|---:|---:|
| MINAJ2 state | `strobe_iq` | 15 | 14 |
| Interpolation-window state | `strobe_iq` | 15 | 14 |
| FIR/output state | `shift_strobe_iq` | 3 | 2 |

These exceptions reflect the designed strobe behavior and are not used simply to hide timing-critical logic.

## 4. Clock Gating

Latch-based clock gating is inserted for groups of registers that share enable conditions:

```tcl
set_clock_gating_style -sequential_cell latch -minimum_bitwidth 3
insert_clock_gating
```

This reduces unnecessary register switching while preserving one logical clock domain.

## 5. Synthesis Timing Result

| Metric | Result |
|---|---:|
| Worst setup slack | **0.00 ns - MET** |
| Worst pre-layout hold slack | **-0.03 ns** |
| Sequential cells | 1,063 |
| Clock gating | Latch-based |

The small pre-layout hold violation is checked again after CTS and routing. Final PrimeTime analysis reports positive hold slack.

## 6. Main Outputs

The synthesis flow generates:

| File | Purpose |
|---|---|
| `top_interpolator_dac.v` | Technology-mapped gate-level netlist |
| `top_interpolator_dac.sdc` | Exported implementation constraints |
| `initial.top_interpolator_dac.ddc` | Pre-compile database |
| `final.top_interpolator_dac.ddc` | Final mapped database |
| `compile.vsdc` | Equivalence-checking setup information |
| synthesis reports | Timing and constraint evidence |

The mapped netlist is used by Innovus, LEC, and the dedicated SAIF generation flow.

## 7. Repository Location

```text
Synthesis/
```

Proprietary standard-cell libraries and foundry models are referenced only from the local EDA environment and are not committed.
