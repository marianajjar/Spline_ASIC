# Final Results

## 1. Project Operating Points

The ASIC implements real-time interpolation of complex baseband I/Q signals using the MINAJ2 cubic interpolation algorithm followed by a programmable 10-tap FIR cleanup filter.

| Interpolation Factor | Input Word | External Clock | Input Rate | Output Rate |
|---:|---:|---:|---:|---:|
| L=2 | 16 bits | 960 MHz | 60 MSa/s | 120 MSa/s |
| L=3 | 15 bits | 900 MHz | 60 MSa/s | 180 MSa/s |
| L=4 | 16 bits | 960 MHz | 60 MSa/s | 240 MSa/s |
| L=5 | 15 bits | 900 MHz | 60 MSa/s | 300 MSa/s |

---

## 2. Signal-Quality Results

The final MATLAB and RTL outputs were evaluated using EVM. The project target was:

```text
EVM < 350 m%rms
```

| L | MATLAB EVM (m%rms) | RTL EVM (m%rms) | Status |
|---:|---:|---:|---|
| 2 | 116.21 | 110.00 | **PASS** |
| 3 | 186.41 | 174.88 | **PASS** |
| 4 | 192.94 | 186.37 | **PASS** |
| 5 | 77.881 | 72.80 | **PASS** |

All four supported interpolation modes satisfy the EVM requirement.

---

## 3. Verification Results

### RTL Verification

Block-level and top-level verification covered the main datapath and control functions, all supported interpolation factors, mode transitions, reset/configuration behavior, streaming operation, and dedicated corner cases.

| Metric | Result |
|---|---:|
| Supported interpolation modes | **4 / 4** |
| Ordered mode transitions | **12 / 12** |
| Functional coverage | **100%** |
| Assertion coverage | **100%** |

### Formal Verification

Synopsys VC Formal was used for block-level formal property verification.

| Metric | Result |
|---|---:|
| RTL blocks verified | 9 |
| Assertions analyzed | 123 |
| Proven assertions | 118 |
| Vacuous assertions | 5 |
| Failed assertions | **0** |
| Cover properties reached | **38 / 38 (100%)** |

The five vacuous properties are reset-related assertions in runs where reset was constrained inactive.

### RTL-to-Gate LEC

Cadence Conformal was used to compare the RTL reference with the synthesized gate-level implementation.

| Metric | Result |
|---|---:|
| Incomplete verification | 0 |
| Design ambiguity | 0 |
| Compare result | **PASS** |

### Pad-Level GLS

Gate-level simulation was performed after pad integration using the padded top-level design.

```text
Pad-Level GLS: PASS
```

---

## 4. Synthesis Results

The RTL was synthesized using Synopsys Design Compiler and mapped to TSMC 65 nm low-power standard cells.

| Metric | Result |
|---|---:|
| Clock period | 1.04167 ns |
| Mapped cells | 25,916 |
| Sequential cells | 1,063 |
| Setup slack | **0.00 ns — MET** |
| Pre-layout hold slack | -0.03 ns |
| Clock gating | Latch-based |

The small pre-layout hold violation was resolved during physical implementation and final post-layout timing closure.

---

## 5. Physical Implementation

Cadence Innovus was used for floorplanning, pad integration, power planning, placement, clock-tree synthesis, routing, ECO closure, extraction, and final implementation checks.

| Physical Metric | Final Result |
|---|---:|
| Die size | **1000 × 950 µm** |
| Die area | **0.950 mm²** |
| Core size | **646 × 596 µm** |
| Core area | **385,016 µm²** |
| Clock-tree sinks | 1,063 |
| Unplaced instances | **0** |
| Innovus connectivity | **No problems or warnings** |
| Innovus DRC | **0 violations** |

![Final routed ASIC layout](../Figures/final_layout.png)

---

## 6. Post-Layout Timing

Final static timing analysis was performed using Synopsys PrimeTime with propagated clocks and extracted post-route parasitics.

The extracted timing data includes:

```text
top_slow.SPEF
top_fast.SPEF
```

| Check | Worst Slack | Result |
|---|---:|---|
| Setup | **+0.29 ns** | **MET** |
| Hold | **+0.86 ns** | **MET** |

The final routed implementation therefore meets both reported setup and hold timing requirements.

---

## 7. Post-Route Power

Post-route power was evaluated in Cadence Innovus using SAIF activity for each interpolation mode.

```text
SAIF annotation coverage = 75.37%
```

### Total Pad-Level Design Power

| L | SlowView (mW) | TypView (mW) | FastView (mW) |
|---:|---:|---:|---:|
| 2 | 93.204 | 80.703 | 128.525 |
| 3 | 112.566 | 103.597 | 155.429 |
| 4 | 115.263 | 107.006 | 159.500 |
| 5 | **117.161** | **109.509** | **162.620** |

### Interpolation-Core `I0` Power

| L | SlowView (mW) | TypView (mW) | FastView (mW) |
|---:|---:|---:|---:|
| 2 | 16.32 | 19.53 | 24.24 |
| 3 | 20.78 | 25.04 | 30.84 |
| 4 | 24.47 | 29.62 | 36.27 |
| 5 | **28.75** | **34.89** | **42.63** |

Power increases with interpolation factor because the higher output rate increases datapath activity.

At the typical view, the highest-rate mode, L=5, consumes:

```text
Total pad-level design power = 109.509 mW
Interpolation-core I0 power  = 34.89 mW
```

Power-integrity analysis was also performed. The results identify opportunities for further PDN improvement through additional power pads, wider or denser power straps, and stronger via connections.

---

## 8. Physical Verification

### Innovus

| Check | Result |
|---|---|
| Placement | **PASS** |
| Connectivity | **PASS** |
| DRC | **0 violations** |

### Calibre DRC

Calibre DRC was run on the final GDS. The remaining reported checks are associated with pad/ESD structures and technology/fill-related rules. These were reviewed with the project advisor and considered non-blocking for the academic project scope.

### Calibre LVS

Calibre LVS compared the extracted layout circuit against the reference SPICE circuit:

```text
Reference/source netlist : top_eco_nocorner.spi
Extracted layout netlist : top.sp
```

Final result:

```text
OVERALL COMPARISON: CORRECT
```

---

## 9. Final Implementation Summary

| Category | Final Result |
|---|---|
| Technology | TSMC 65 nm low-power |
| Supported modes | **L=2,3,4,5** |
| Input sample rate | 60 MSa/s |
| Maximum output sample rate | **300 MSa/s** |
| EVM target | < 350 m%rms |
| RTL EVM | **72.8–186.37 m%rms — all PASS** |
| Functional coverage | **100%** |
| Assertion coverage | **100%** |
| Formal verification | **118 proven, 0 failed, 38/38 covers** |
| RTL-to-gate LEC | **PASS** |
| Pad-level GLS | **PASS** |
| Mapped cells | 25,916 |
| Die size | **1000 × 950 µm** |
| Core size | **646 × 596 µm** |
| PrimeTime setup | **+0.29 ns — MET** |
| PrimeTime hold | **+0.86 ns — MET** |
| Innovus DRC | **0 violations** |
| Innovus connectivity | **PASS** |
| Calibre LVS | **CORRECT** |
| Typical L=5 total power | **109.509 mW** |
| Typical L=5 core `I0` power | **34.89 mW** |

---

## 10. Detailed Documentation

More detailed methodology and reports are available in:

- [System Architecture](architecture.md)
- [MATLAB Model](Matlab_model.md)
- [RTL Architecture](RTL_architecture.md)
- [Verification](Verification.md)
- [Synthesis](Synthesis.md)
- [Physical Design](Physical_design.md)
- [Signoff](Signoff.md)

The repository folders contain the corresponding RTL, scripts, constraints, testbenches, and selected implementation/signoff reports.
