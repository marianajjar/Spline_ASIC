# Signoff

## Overview

Final verification was performed after synthesis and physical implementation using a combination of logic-equivalence checking, pad-level gate-level simulation, static timing analysis, DRC, and LVS.

The signoff flow covered:

```text
RTL-to-Gate LEC
      ↓
Pad-Level GLS
      ↓
Physical Implementation
      ↓
PrimeTime STA
      ↓
Calibre DRC / LVS
```

## RTL-to-Gate Logic Equivalence Checking

Cadence Conformal LEC was used to compare the RTL reference design with the synthesized gate-level netlist.

The final comparison result was:

**PASS**

The verification report showed:

- incomplete verification: 0,
- user modifications to the design: 0,
- design ambiguity: 0,
- compare result: PASS.

This confirms that synthesis preserved the logical functionality of the RTL implementation.

## Pad-Level Gate-Level Simulation

Gate-level simulation was performed on the pad-integrated top-level design. The GLS testbench applies the same logical configuration and signal transaction used during RTL verification:

1. configuration header and interpolation factor,
2. ten FIR coefficient words,
3. serial I/Q input samples,
4. capture and comparison of the generated I/Q outputs.

All four supported interpolation factors were exercised.

**Final GLS result: PASS**

The pad-level GLS also provides switching-activity data used by the subsequent post-route power-analysis flow.

## Static Timing Analysis

Final post-layout static timing analysis was performed using Synopsys PrimeTime with extracted parasitics and propagated clocks.

### Setup Timing

The final worst setup path reported:

- path type: maximum delay,
- worst setup slack: **+0.29 ns**,
- result: **MET**.

### Hold Timing

The final worst hold path reported:

- path type: minimum delay,
- worst hold slack: **+0.86 ns**,
- result: **MET**.

Therefore, the final post-layout design meets both setup and hold timing in the analyzed signoff views.

## Design Rule Checking

Two levels of physical-rule checking were used.

### Innovus DRC

The final Innovus implementation check reported:

**No DRC violations were found.**

This confirms that no remaining implementation-level routing DRC violations were reported by the final Innovus database.

### Calibre DRC

Calibre DRC was also run on the final layout. The report contains residual rule-check results associated primarily with pad/ESD structures and technology/fill/density-related checks.

These residual results were reviewed as part of the project and were considered non-design-blocking for the academic implementation, since they correspond to structures or final manufacturing adjustments that are handled at the foundry/tapeout stage rather than by changes to the interpolation core.

For this reason, the repository preserves the Calibre DRC summary instead of describing the run as a zero-result Calibre DRC.

## Layout Versus Schematic

Calibre LVS was used to compare the circuit extracted from the final layout against the reference/source SPICE netlist.

The comparison used:

```text
Reference/source:
top_eco_nocorner.spi

Extracted layout netlist:
top.sp
```

The final Calibre report returned:

**OVERALL COMPARISON: CORRECT**

with the top-level cell reported as `CORRECT`.

This verifies that the electrical connectivity extracted from the final layout matches the intended source circuit.

The post-layout Verilog exported from Innovus,

```text
top_final_final_lvs.v
```

is retained separately as the digital post-layout representation of the implemented design.

## Signoff Summary

| Check | Tool | Final Result |
|---|---|---|
| RTL-to-Gate LEC | Cadence Conformal | **PASS** |
| Pad-Level GLS | Synopsys VCS | **PASS** |
| Post-layout setup STA | Synopsys PrimeTime | **MET, +0.29 ns** |
| Post-layout hold STA | Synopsys PrimeTime | **MET, +0.86 ns** |
| Innovus DRC | Cadence Innovus | **0 violations** |
| Calibre DRC | Siemens Calibre | Residual technology/pad-related checks reviewed for project scope |
| LVS | Siemens Calibre | **CORRECT** |

## Repository Organization

```text
Signoff/
├── LEC/
├── GLS_Pad_Level/
├── PrimeTime/
├── DRC/
└── LVS/
```

Detailed RTL verification results are documented separately in [Verification.md](Verification.md).
