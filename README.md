# Spline Interpolation DSP ASIC with Full RTL-to-Digital Design (TSMC 65nm)

A complete RTL-to-layout ASIC implementation of a real-time interpolation engine for complex baseband I/Q signals. The design supports programmable interpolation factors \(L=\{2,3,4,5\}\), uses the MINAJ2 cubic interpolation algorithm, and includes a programmable 10-tap FIR cleanup filter.

The project covers the complete development flow from MATLAB algorithm evaluation and fixed-point modeling through RTL design, verification, synthesis, physical implementation, and final signoff.

## Key Specifications

| Parameter | Value |
|---|---|
| Input signal | Complex I/Q, 64-QAM |
| Input sample rate | 60 MSa/s |
| Interpolation factors | 2, 3, 4, 5 |
| Output sample rates | 120, 180, 240, 300 MSa/s |
| Interpolation algorithm | MINAJ2 cubic interpolation |
| FIR filter | Programmable 10-tap FIR |
| Datapath | 16-bit fixed point, 12 fractional bits |
| External clocks | 960 MHz for even L, 900 MHz for odd L |
| Architecture | Parallel I/Q datapaths with shared control |
| Technology | 65 nm low-power standard-cell flow |

## Architecture

The ASIC contains two parallel I/Q datapaths controlled by shared timing and configuration logic. The I path acts as the timing master, while the Q path follows the common word and interpolation-phase control.

```text
                Shared Control
                     │
          ┌──────────┴──────────┐
          │                     │
      I Datapath            Q Datapath
          │                     │
   Serial Capture        Serial Capture
          │                     │
    Sample History        Sample History
          │                     │
       MINAJ2                 MINAJ2
          │                     │
    Sample Shift           Sample Shift
          │                     │
     10-Tap FIR             10-Tap FIR
          │                     │
        I Out                 Q Out
```

After reset, the design detects a synchronization marker, captures the interpolation factor, loads ten FIR coefficients through the I serial input, and then enters normal streaming mode.

More detail is available in [System Architecture](docs/architecture.md) and [RTL Architecture](docs/RTL_architecture.md).

## Supported Modes

| L | Input Clock | Input Word | Output Rate |
|---:|---:|---:|---:|
| 2 | 960 MHz | 16 bits | 120 MSa/s |
| 3 | 900 MHz | 15 bits | 180 MSa/s |
| 4 | 960 MHz | 16 bits | 240 MSa/s |
| 5 | 900 MHz | 15 bits | 300 MSa/s |

## Design Flow

```text
MATLAB Algorithm Development
          ↓
Fixed-Point Modeling
          ↓
RTL Implementation
          ↓
Block / Top-Level / Formal Verification
          ↓
Synthesis
          ↓
RTL-to-Gate LEC
          ↓
Pad-Level GLS
          ↓
Physical Design
          ↓
Post-Layout STA + Power Analysis
          ↓
DRC + LVS
```

## Verification Highlights

- Bit-accurate MATLAB-to-RTL regression across all supported interpolation modes.
- Block-level verification of the main datapath and control modules.
- Top-level testing of \(L=2,3,4,5\), mode transitions, reset, configuration, and streaming corner cases.
- 100% functional coverage for the implemented top-level coverage model.
- 100% assertion coverage for the top-level assertion set.
- Formal verification of 9 RTL blocks:
  - 123 assertions analyzed,
  - 118 proven,
  - 5 reset-related vacuous properties,
  - 0 failed assertions,
  - 38/38 formal cover properties reached.
- RTL-to-gate LEC: **PASS**.
- Pad-level GLS: **PASS**.

See [Verification](docs/Verification.md) and [Signoff](docs/Signoff.md).

## Physical Implementation

The final pad-level design was placed and routed using Cadence Innovus.

- Die size: **1000 µm × 950 µm**
- Core area: **385,016 µm²**
- Final placement: no unplaced instances
- Final Innovus connectivity check: no problems or warnings
- Final Innovus DRC: 0 violations
- Final extracted parasitics generated for slow and fast RC conditions

![Final routed ASIC layout](Figures/final_layout.png)

See [Physical Design](docs/Physical_design.md).

## Post-Layout Timing

Final PrimeTime signoff with extracted parasitics reported:

| Check | Worst Slack | Result |
|---|---:|---|
| Setup | +0.29 ns | MET |
| Hold | +0.86 ns | MET |

## Post-Route Core Power

SAIF-based Innovus power analysis was performed separately for all four interpolation modes. The uploaded reports measure the interpolation core instance `I0`.

| L | SlowView (mW) | TypView (mW) | FastView (mW) |
|---:|---:|---:|---:|
| 2 | 93.20 | 80.70 | 128.53 |
| 3 | 112.57 | 103.60 | 155.43 |
| 4 | 115.26 | 107.01 | 159.50 |
| 5 | 117.16 | 109.51 | 162.62 |

## Physical Verification

Calibre LVS returned **CORRECT**, confirming equivalence between the extracted layout circuit and the reference SPICE netlist.

The final Calibre DRC run contains residual pad/ESD and technology/fill-related rule checks that were reviewed as non-design-blocking within the academic project scope. The final Innovus routing DRC itself reports zero violations.

## Repository Structure

```text
Spline_ASIC/
├── MATLAB/                  # Algorithm, fixed-point and golden-reference models
├── RTL/                     # Synthesizable RTL
├── Verification/            # Block-level, top-level and formal RTL verification
├── Synthesis/               # Synthesis scripts, constraints, reports and netlist
├── Physical_Design/         # Innovus implementation, extraction and power analysis
├── Signoff/                 # LEC, pad-level GLS, PrimeTime, DRC and LVS
├── Figures/                 # Project figures
└── docs/                    # Detailed project documentation
```

## Documentation

- [System Architecture](docs/architecture.md)
- [MATLAB Model](docs/Matlab_model.md)
- [RTL Architecture](docs/RTL_architecture.md)
- [Verification](docs/Verification.md)
- [Synthesis](docs/Synthesis.md)
- [Physical Design](docs/Physical_design.md)
- [Signoff](docs/Signoff.md)

## Main Tools

- MATLAB / Fixed-Point modeling
- Synopsys VCS and Verdi
- Synopsys VC Formal
- Synopsys Design Compiler
- Cadence Conformal LEC
- Cadence Innovus
- Synopsys PrimeTime
- Siemens Calibre DRC/LVS

## Repository Notes

Technology libraries, foundry models, large simulation databases, and proprietary PDK files are intentionally not included in this public repository. The repository contains project RTL, scripts, selected reports, generated netlists where appropriate, and documentation needed to describe the implemented flow.
