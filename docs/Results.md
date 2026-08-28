# Final Results

## 1. Operating Points

| L | Input Word | External Clock | Input Rate | Output Rate |
|---:|---:|---:|---:|---:|
| 2 | 16 bits | 960 MHz | 60 MSa/s | 120 MSa/s |
| 3 | 15 bits | 900 MHz | 60 MSa/s | 180 MSa/s |
| 4 | 16 bits | 960 MHz | 60 MSa/s | 240 MSa/s |
| 5 | 15 bits | 900 MHz | 60 MSa/s | 300 MSa/s |

## 2. Signal Quality

Project requirement:

```text
EVM < 350 m%rms
```

| L | MATLAB EVM (m%rms) | RTL EVM (m%rms) | Result |
|---:|---:|---:|---|
| 2 | 116.21 | 110.00 | **PASS** |
| 3 | 186.41 | 174.88 | **PASS** |
| 4 | 192.94 | 186.37 | **PASS** |
| 5 | 77.881 | 72.80 | **PASS** |

All supported modes meet the EVM requirement.

## 3. Verification

| Metric | Final Result |
|---|---|
| Supported modes | **4/4** |
| Ordered mode transitions | **12/12** |
| MATLAB-to-RTL comparison | **Bit-exact PASS** |
| Functional coverage | **100%** |
| Assertion coverage | **100%** |
| Formal verification | **9 blocks, 118 proven, 0 failed** |
| Formal covers | **38/38 reached** |
| RTL-to-gate LEC | **PASS** |
| Pad-level functional GLS | **PASS** |

## 4. Synthesis

| Metric | Result |
|---|---:|
| Clock period constraint | 1.04167 ns |
| Worst setup slack | **0.00 ns - MET** |
| Pre-layout hold slack | -0.03 ns |
| Sequential cells | 1,063 |
| Clock gating | Latch-based |

The small pre-layout hold violation is resolved in the final post-layout timing result.

## 5. Physical Implementation

| Metric | Final Result |
|---|---:|
| Technology | TSMC 65 nm low-power |
| Die size | **1000 x 950 um** |
| Die area | **0.950 mm²** |
| Core size | **646 x 596 um** |
| Core area | **385,016 um²** |
| Clock-tree sinks | 1,063 |
| Unplaced instances | **0** |
| Innovus connectivity | **PASS** |
| Innovus DRC | **0 violations** |

![Final routed ASIC layout](../Figures/final_layout.png)

## 6. Post-Layout Timing

| Check | Worst Slack | Result |
|---|---:|---|
| Setup | **+0.29 ns** | **MET** |
| Hold | **+0.86 ns** | **MET** |

## 7. Post-Route Power

SAIF annotation coverage:

```text
75.37%
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

## 8. Physical Verification

| Check | Result |
|---|---|
| Innovus placement | **PASS** |
| Innovus connectivity | **PASS** |
| Innovus DRC | **0 violations** |
| Calibre DRC | Residual pad/ESD and technology/fill checks reviewed for academic scope |
| Calibre LVS | **CORRECT** |

## 9. Final Project Snapshot

| Category | Final Result |
|---|---|
| Supported interpolation factors | **L=2,3,4,5** |
| Input sample rate | 60 MSa/s |
| Maximum output sample rate | **300 MSa/s** |
| EVM target | < 350 m%rms |
| RTL EVM range | **72.8-186.37 m%rms - all PASS** |
| Functional / assertion coverage | **100% / 100%** |
| Formal | **118 proven, 0 failed, 38/38 covers** |
| RTL-to-gate LEC | **PASS** |
| Pad-level GLS | **PASS** |
| PrimeTime setup / hold | **+0.29 ns / +0.86 ns - MET** |
| Innovus DRC | **0 violations** |
| Calibre LVS | **CORRECT** |
| Typical \(L=5\) total power | **109.509 mW** |
| Typical \(L=5\) core `I0` power | **34.89 mW** |

## 10. Detailed Documentation

- [System Architecture](Architecture.md)
- [MATLAB Model](MATLAB_Model.md)
- [RTL Architecture](RTL_Architecture.md)
- [Verification](Verification.md)
- [Synthesis](Synthesis.md)
- [Physical Design](Physical_Design.md)
- [Power Analysis](Power_Analysis.md)
- [Signoff](Signoff.md)
