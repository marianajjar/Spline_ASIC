# Signoff

## 1. Overview

The final design is checked at logical, timing, and physical levels.

```text
RTL-to-Gate LEC
      |
      v
Pad-Level Functional GLS
      |
      v
Routed Physical Design
      |
      +-------------------+
      |                   |
      v                   v
PrimeTime STA       Calibre DRC / LVS
```

## 2. RTL-to-Gate Logic Equivalence

Cadence Conformal compares the RTL reference with the synthesized gate-level netlist.

| Metric | Result |
|---|---:|
| Equivalent compare points | 669 |
| Incomplete verification | 0 |
| Design ambiguity | 0 |
| Final result | **PASS** |

This is the final verified RTL-to-synthesized-gate comparison.

Repository location:

```text
Signoff/LEC/
```

## 3. Pad-Level Functional GLS

Gate-level simulation was performed after pad integration.

The sequence includes:

1. synchronization + \(L\) configuration;
2. ten FIR coefficient words;
3. serial I/Q samples;
4. output capture and checking.

All four interpolation factors were exercised.

**Final pad-level GLS result: PASS**

The preserved result is functional/zero-delay GLS. No SDF timing result is claimed.

Repository location:

```text
Signoff/GLS_Pad_Level/
```

## 4. PrimeTime Static Timing Analysis

Post-layout STA uses propagated clocks and extracted parasitics.

| Check | Worst Slack | Result |
|---|---:|---|
| Setup | **+0.29 ns** | **MET** |
| Hold | **+0.86 ns** | **MET** |

The final routed design therefore meets both reported setup and hold requirements in the analyzed signoff views.

Repository location:

```text
Signoff/PrimeTime/
```

## 5. Innovus DRC

The final Innovus implementation-level DRC reports:

```text
0 violations
```

The final connectivity check also reports no problems or warnings.

## 6. Calibre DRC

Calibre DRC was run on the final GDS.

The remaining results are mainly associated with:

- pad/ESD structures;
- technology/fill/density rules;
- final manufacturing-oriented checks.

These residual results were reviewed with the project advisor and treated as non-blocking for the academic project scope.

The documentation therefore deliberately does **not** claim zero Calibre DRC results.

Repository location:

```text
Signoff/DRC/
```

## 7. Calibre LVS

Calibre LVS compares the extracted layout circuit with the reference source circuit.

```text
Reference/source : top_eco_nocorner.spi
Extracted layout : top.sp
```

Final result:

```text
OVERALL COMPARISON: CORRECT
```

The post-layout Innovus Verilog representation is retained separately as:

```text
top_final_final_lvs.v
```

Repository location:

```text
Signoff/LVS/
```

## 8. Final Signoff Summary

| Check | Tool | Final Result |
|---|---|---|
| RTL-to-gate LEC | Cadence Conformal | **PASS** |
| Pad-level functional GLS | Synopsys VCS | **PASS** |
| Setup STA | Synopsys PrimeTime | **+0.29 ns - MET** |
| Hold STA | Synopsys PrimeTime | **+0.86 ns - MET** |
| Innovus connectivity | Cadence Innovus | **PASS** |
| Innovus DRC | Cadence Innovus | **0 violations** |
| Calibre DRC | Siemens Calibre | Residual pad/technology checks reviewed for academic scope |
| Calibre LVS | Siemens Calibre | **CORRECT** |

## 9. Repository Structure

```text
Signoff/
├── LEC/
├── GLS_Pad_Level/
├── PrimeTime/
├── DRC/
└── LVS/
```
