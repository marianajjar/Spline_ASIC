# Post-Route Power Analysis

## 1. Overview

Post-route power is evaluated in Cadence Innovus using switching activity generated from gate-level simulation of the synthesized interpolation core.

A separate SAIF file is generated for each supported interpolation mode:

```text
L = 2
L = 3
L = 4
L = 5
```

This preserves the different clock/word modes and output activity rates of the four operating configurations.

## 2. SAIF Generation

SAIF generation is intentionally kept outside the Innovus directory:

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

The testbench uses the nominal external mode for each interpolation factor:

| L | Clock | Normal I/Q Word |
|---:|---:|---:|
| 2 | 960 MHz | 16 bits |
| 3 | 900 MHz | 15 bits |
| 4 | 960 MHz | 16 bits |
| 5 | 900 MHz | 15 bits |

FIR coefficients remain 16-bit words for every mode.

The run script compiles the synthesized `top_interpolator_dac` netlist once and executes four mode-specific simulations. The generated files are:

```text
core_sf_L2.saif
core_sf_L3.saif
core_sf_L4.saif
core_sf_L5.saif
```

VCD generation is optional for debugging and is not the final activity source used by the post-route power flow.

## 3. Staging into Innovus

The generated SAIF files are staged into:

```text
Innovus/datain/saif/
```

This keeps activity generation separate from physical implementation while providing a stable input location for the Innovus power scripts.

## 4. SAIF Hierarchy Mapping

The gate-level SAIF is generated from the simulation DUT hierarchy and mapped onto the interpolation-core instance in the pad-level Innovus design.

The final mapping is:

```text
SAIF scope    : tb_top_interpolator_dac/DUT
Innovus block : I0
```

The activity annotation coverage reported by the current Innovus power reports is approximately:

```text
75.37%
```

Unannotated activity uses the mode-appropriate default clock period in the final scripts.

## 5. Innovus Power Scripts

The final SAIF-based scripts are stored under:

```text
Innovus/scripts/
├── power_fast_typ_saif.tcl
└── power_slow_saif.tcl
```

They restore the completed physical database, read the mode-specific SAIF file, apply the `I0` hierarchy mapping, evaluate the required analysis view, and generate one report per interpolation mode.

The scripts read SAIF activity from:

```text
Innovus/datain/saif/
```

## 6. Total Pad-Level Design Power

The main `Total Power` section of each Innovus report corresponds to the complete pad-level design.

| L | SlowView (mW) | TypView (mW) | FastView (mW) |
|---:|---:|---:|---:|
| 2 | 93.204 | 80.703 | 128.525 |
| 3 | 112.566 | 103.597 | 155.429 |
| 4 | 115.263 | 107.006 | 159.500 |
| 5 | **117.161** | **109.509** | **162.620** |

## 7. Interpolation-Core `I0` Power

The same reports include the power of the interpolation-core instance `I0`.

| L | SlowView (mW) | TypView (mW) | FastView (mW) |
|---:|---:|---:|---:|
| 2 | 16.32 | 19.53 | 24.24 |
| 3 | 20.78 | 25.04 | 30.84 |
| 4 | 24.47 | 29.62 | 36.27 |
| 5 | **28.75** | **34.89** | **42.63** |

It is important not to confuse the report's design-level `Total Power` with the `Instance I0` row. The first is pad-inclusive design power; the second isolates the interpolation core.

Power increases with \(L\) within each analysis view because higher interpolation factors produce more output events and greater datapath activity.

At the typical view for the highest-rate mode:

```text
L = 5
Total pad-level design power = 109.509 mW
Interpolation-core I0 power  = 34.89 mW
```

## 8. Power-Integrity Analysis

Static VDD/VSS rail analysis was also performed on the routed implementation.

The project did not define a separate IR-drop pass/fail requirement. The analysis is therefore used to identify physical-design improvement opportunities rather than to claim a rail-signoff criterion.

Potential improvements include:

- additional VDD/VSS pads,
- wider or stronger power rings and straps,
- denser power-grid routing,
- additional parallel vias at high-current connections,
- improved distribution of high-current regions.

