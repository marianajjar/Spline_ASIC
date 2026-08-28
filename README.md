# Spline Interpolation DSP ASIC (TSMC 65 nm)

A real-time ASIC implementation for interpolation of complex baseband I/Q signals. The design supports programmable interpolation factors \(L=\{2,3,4,5\}\), uses the MINAJ2 cubic interpolation algorithm, and applies a programmable 10-tap FIR cleanup filter.

The project covers MATLAB algorithm development and fixed-point modeling, synthesizable RTL, simulation and formal verification, synthesis, pad-level implementation in Cadence Innovus, post-layout timing, SAIF-based power analysis, and physical signoff.

## Key Specifications

| Parameter | Value |
|---|---|
| Input signal | Complex I/Q, 64-QAM |
| Input sample rate | 60 MSa/s |
| Interpolation factors | \(L=2,3,4,5\) |
| Output sample rates | 120, 180, 240, 300 MSa/s |
| Interpolation algorithm | MINAJ2 cubic interpolation |
| FIR filter | Programmable 10-tap FIR |
| Main datapath | 16-bit fixed point, 12 fractional bits |
| External clock | 960 MHz for \(L=2,4\); 900 MHz for \(L=3,5\) |
| Serial input word | 16 bits for \(L=2,4\); 15 bits for \(L=3,5\) |
| Architecture | Parallel I/Q datapaths with shared control |
| Technology | TSMC 65 nm low-power standard-cell flow |

## Architecture

The ASIC contains two parallel I/Q datapaths controlled by shared configuration and timing logic. The I path is the timing master; the Q path follows the common word and interpolation-phase control so that both signal components remain aligned.

```text
                         Shared Control
                              |
                 +------------+------------+
                 |                         |
             I Datapath                 Q Datapath
                 |                         |
          Serial Reception          Serial Reception
                 |                         |
          Sample History             Sample History
                 |                         |
              MINAJ2                     MINAJ2
                 |                         |
          Sample Scheduling          Sample Scheduling
                 |                         |
           10-Tap FIR                 10-Tap FIR
                 |                         |
               I Out                     Q Out
```

After reset, the design detects a synchronization marker, captures the 3-bit interpolation-factor field, loads ten signed 16-bit FIR coefficients through the I serial input, and then enters normal I/Q streaming.

See [System Architecture](docs/Architecture.md) and [RTL Architecture](docs/RTL_Architecture.md).

## Supported Modes

| L | External Clock | Input Word | Input Rate | Output Rate |
|---:|---:|---:|---:|---:|
| 2 | 960 MHz | 16 bits | 60 MSa/s | 120 MSa/s |
| 3 | 900 MHz | 15 bits | 60 MSa/s | 180 MSa/s |
| 4 | 960 MHz | 16 bits | 60 MSa/s | 240 MSa/s |
| 5 | 900 MHz | 15 bits | 60 MSa/s | 300 MSa/s |

## Design Flow

```text
MATLAB Algorithm Development
          |
          v
Fixed-Point / RTL Golden Model
          |
          v
RTL Implementation
          |
          v
Block + Top-Level + Formal Verification
          |
          v
Synthesis
          |
          v
RTL-to-Gate LEC
          |
          v
Pad-Level GLS
          |
          v
Cadence Innovus Physical Design
          |
          +--------------------+
          |                    |
          v                    v
   PrimeTime STA       SAIF-Based Power
          |                    |
          +---------+----------+
                    v
              DRC / LVS
```

## Verification Highlights

- Bit-exact MATLAB-to-RTL regression for all supported interpolation modes.
- All 12 ordered transitions between different \(L\) values exercised.
- Functional coverage: **100%**.
- Assertion coverage: **100%**.
- Synopsys VC Formal: **9 RTL blocks**, **123 assertions analyzed**, **118 proven**, **0 failed**, and **38/38 covers reached**.
- RTL-to-gate Cadence Conformal LEC: **PASS**.
- Pad-level functional GLS: **PASS**.

See [Verification](docs/Verification.md) and [Signoff](docs/Signoff.md).

## Final Implementation Snapshot

| Category | Final Result |
|---|---|
| Die size | **1000 × 950 µm** |
| Core size | **646 × 596 µm** |
| PrimeTime setup slack | **+0.29 ns — MET** |
| PrimeTime hold slack | **+0.86 ns — MET** |
| Innovus DRC | **0 violations** |
| Innovus connectivity | **PASS** |
| Calibre LVS | **CORRECT** |
| Typical \(L=5\) total pad-level power | **109.509 mW** |
| Typical \(L=5\) interpolation-core `I0` power | **34.89 mW** |

![Final routed ASIC layout](Figures/final_layout.png)

Detailed results are collected in [Results](docs/Results.md).

## Repository Structure

```text
Spline_ASIC/
├── README.md
├── docs/
│   ├── Architecture.md
│   ├── MATLAB_Model.md
│   ├── RTL_Architecture.md
│   ├── Verification.md
│   ├── Synthesis.md
│   ├── Physical_Design.md
│   ├── Power_Analysis.md
│   ├── Signoff.md
│   └── Results.md
│
├── Figures/
├── MATLAB/
├── RTL/
├── Verification/
├── Synthesis/
│
├── SAIF_Generation/
│   ├── run_saif_toggle.tcsh
│   ├── tb_saif.sv
│   ├── inputs/
│   └── saif/                  # generated locally
│
├── Innovus/
│   ├── datain/
│   │   └── saif/              # staged SAIF activity
│   ├── scripts/
│   ├── reports/
│   ├── power/
│   ├── dataout/
│   └── work/                  # generated tool data
│
└── Signoff/
    ├── LEC/
    ├── GLS_Pad_Level/
    ├── PrimeTime/
    ├── DRC/
    └── LVS/
```

## Documentation

- [System Architecture](docs/Architecture.md)
- [MATLAB Model and RTL Golden Reference](docs/MATLAB_Model.md)
- [RTL Architecture](docs/RTL_Architecture.md)
- [Verification](docs/Verification.md)
- [Synthesis](docs/Synthesis.md)
- [Physical Design](docs/Physical_Design.md)
- [Power Analysis](docs/Power_Analysis.md)
- [Signoff](docs/Signoff.md)
- [Final Results](docs/Results.md)

## Main Tools

- MATLAB, Fixed-Point Toolbox, IQTools / PathWave VSA workflow
- Synopsys VCS and Verdi
- Synopsys VC Formal
- Synopsys Design Compiler
- Cadence Conformal
- Cadence Innovus
- Synopsys PrimeTime
- Siemens Calibre DRC/LVS

## Public Repository Notes

Technology libraries, foundry simulation models, PDK files, EDA databases, large waveform databases, and foundry GDS data are intentionally excluded from the public repository. The repository contains project RTL, scripts, verification collateral, selected reports, and documentation required to describe and reproduce the project flow in a properly configured ASIC environment.
