# Post-Route Power Analysis

## 1. Overview

Post-route power is evaluated in Cadence Innovus using mode-specific SAIF switching activity.

The power flow is separated into two stages:

```text
SAIF_Generation/
      |
      v
core_sf_L2.saif ... core_sf_L5.saif
      |
      v
Innovus/datain/saif/
      |
      v
Innovus Post-Route Power Analysis
```

This keeps activity generation independent of the physical-design scripts.

## 2. SAIF Generation

The SAIF testbench runs the synthesized interpolation core and uses the nominal clock/input-word mode for each \(L\).

| L | External Clock | Normal Input Word |
|---:|---:|---:|
| 2 | 960 MHz | 16 bits |
| 3 | 900 MHz | 15 bits |
| 4 | 960 MHz | 16 bits |
| 5 | 900 MHz | 15 bits |

FIR coefficient words are always 16 bits.

Repository structure:

```text
SAIF_Generation/
├── run_saif_toggle.tcsh
├── tb_saif.sv
├── inputs/
│   ├── iq_L2.txt
│   ├── iq_L3.txt
│   ├── iq_L4.txt
│   └── iq_L5.txt
└── saif/
```

Generated files:

```text
core_sf_L2.saif
core_sf_L3.saif
core_sf_L4.saif
core_sf_L5.saif
```

## 3. Innovus SAIF Location

The generated files are staged into:

```text
Innovus/datain/saif/
```

The final Innovus scripts therefore do not depend on the working directory of the SAIF simulation.

## 4. Hierarchy Mapping and Coverage

The activity is generated from the simulation DUT hierarchy and mapped to the interpolation-core instance in the pad-level design.

```text
Simulation SAIF scope : tb_top_interpolator_dac/DUT
Innovus core instance : I0
```

Final annotation coverage is approximately:

```text
32562 / 43203 = 75.37%
```

## 5. Power Analysis Scripts

The final scripts are:

```text
Innovus/scripts/power_fast_typ_saif.tcl
Innovus/scripts/power_slow_saif.tcl
```

They restore the signoff physical database, read the correct mode-specific SAIF file, map activity to `I0`, select the required analysis view, and create power reports for \(L=2..5\).

## 6. Total Pad-Level Design Power

The main `Total Power` section in the final Innovus reports represents the complete pad-level design.

| L | SlowView (mW) | TypView (mW) | FastView (mW) |
|---:|---:|---:|---:|
| 2 | 93.204 | 80.703 | 128.525 |
| 3 | 112.566 | 103.597 | 155.429 |
| 4 | 115.263 | 107.006 | 159.500 |
| 5 | **117.161** | **109.509** | **162.620** |

## 7. Interpolation-Core `I0` Power

The same reports also contain the hierarchical power of the interpolation core itself.

| L | SlowView (mW) | TypView (mW) | FastView (mW) |
|---:|---:|---:|---:|
| 2 | 16.32 | 19.53 | 24.24 |
| 3 | 20.78 | 25.04 | 30.84 |
| 4 | 24.47 | 29.62 | 36.27 |
| 5 | **28.75** | **34.89** | **42.63** |

The report's design-level total must therefore not be confused with the `Instance I0` row.

Within each analysis view, power increases with \(L\), consistent with the higher \(60L\) MHz output activity.

At the typical view for \(L=5\):

```text
Total pad-level power = 109.509 mW
Core I0 power         = 34.89 mW
```

## 8. Power-Integrity Analysis

Static VDD and VSS rail analysis was also performed.

The project did not define a separate academic pass/fail requirement for IR-drop closure. The results are therefore treated as guidance for future physical optimization.

Potential improvements include:

- additional VDD/VSS pads;
- wider power rings and straps;
- denser power-grid routing;
- more parallel vias at high-current connections;
- improved current distribution across the core.

## 9. Public Repository Policy

Generated SAIF files, large EDA databases, and proprietary foundry files should remain excluded from Git. The testbench, scripts, and small representative input files document the methodology without distributing restricted technology content.
