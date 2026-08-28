# Verification

## 1. Verification Strategy

Verification is divided into four complementary levels:

1. block-level simulation;
2. top-level RTL regression against a MATLAB bit-accurate model;
3. assertion/coverage and formal property verification;
4. post-synthesis equivalence and pad-level gate simulation.

```text
Block-Level Tests
       |
       v
Top-Level RTL Regression <---- MATLAB RTL Golden Model
       |
       v
SVA + Functional Coverage
       |
       v
VC Formal
       |
       v
RTL-to-Gate LEC
       |
       v
Pad-Level Functional GLS
```

## 2. Block-Level Verification

Self-checking SystemVerilog testbenches verify the main blocks independently.

| Block | Main Verification Targets |
|---|---|
| L configuration | Sync marker, 3-bit L capture, reset, supported/unsupported values |
| SPI-I master | 15/16-bit words, sign extension, strobes, forced 16-bit coefficient mode |
| SPI-Q slave | Shared word mode, reconstruction, I/Q boundary alignment |
| History | Three-sample update order, hold, reset |
| MINAJ2 | Slope recursion, Q1.15 interpolation, saturation |
| Window latch | Window capture, hold, reset |
| Sample Shift I/Q | Phase sequence, shared phase, simultaneous event handling |
| FIR | Ten coefficient loads, MAC behavior, scaling, saturation |

## 3. Top-Level RTL Regression

The complete transaction is verified:

```text
Synchronization + L
        |
        v
10 FIR coefficients
        |
        v
Serial I/Q samples
        |
        v
History + MINAJ2
        |
        v
Sample scheduling
        |
        v
10-tap FIR
        |
        v
DAC I/Q outputs
```

Regression coverage includes:

- \(L=2,3,4,5\);
- all 12 ordered transitions between different modes;
- long 64-QAM traffic;
- reset during configuration;
- reset during coefficient loading;
- reset during streaming;
- repeated reset;
- zero/DC/impulse/full-scale inputs;
- arithmetic saturation cases.

Captured RTL outputs are compared exactly against the MATLAB integer golden model.

**Bit-exact MATLAB-to-RTL result: PASS**

## 4. Assertions and Functional Coverage

The top-level SVA checks include:

- stable legal configuration;
- correct coefficient-count progression;
- no I/Q processing before `coeff_done`;
- correct strobe gating;
- legal phase range and phase progression;
- stable `mode15_word` behavior at word boundaries;
- I/Q timing alignment;
- MINAJ2 update/hold behavior;
- positive and negative saturation;
- FIR load and output behavior.

Functional coverage tracks:

- all supported \(L\) modes;
- all 12 ordered transitions;
- all valid phase values;
- major configuration/streaming states;
- FIR saturation;
- MINAJ2 slope saturation.

| Coverage | Result |
|---|---:|
| Functional coverage | **100%** |
| Assertion coverage | **100%** |

These results are functional/assertion coverage; they are not presented as 100% RTL code coverage.

## 5. Formal Verification

Synopsys VC Formal was used in FPV mode for nine RTL blocks.

The formal properties cover configuration, word counters, mode selection, sign extension, strobe generation, history state, MINAJ2 state and saturation, Sample Shift phase behavior, window behavior, and FIR state/coefficient loading.

| Formal Metric | Result |
|---|---:|
| RTL blocks verified | 9 |
| Assertions analyzed | 123 |
| Proven assertions | 118 |
| Vacuous assertions | 5 |
| Failed assertions | **0** |
| Formal cover properties | **38/38 reached** |

The five vacuous properties are reset-related assertions in runs where reset was constrained inactive.

## 6. RTL-to-Gate LEC

Cadence Conformal compares the RTL reference with the synthesized gate-level netlist.

| Metric | Result |
|---|---:|
| Equivalent compare points | 669 |
| Incomplete verification | 0 |
| Design ambiguity | 0 |
| Compare result | **PASS** |

This is specifically the validated **RTL-to-synthesized-gate** comparison.

## 7. Pad-Level GLS

Functional gate-level simulation was performed after pad integration. The pad-level testbench exercises the configuration sequence, coefficient loading, and I/Q streaming for all four supported interpolation factors.

**Pad-level GLS result: PASS**

The preserved GLS result is a functional/zero-delay verification result; no SDF timing claim is made in the documentation.

Pad-level GLS data is stored under:

```text
Signoff/GLS_Pad_Level/
```

## 8. Verification Summary

| Stage | Final Result |
|---|---|
| Block-level simulation | Completed |
| Top-level RTL regression | **PASS** |
| MATLAB bit-accurate comparison | **PASS** |
| Functional coverage | **100%** |
| Assertion coverage | **100%** |
| Formal verification | **118 proven, 0 failed** |
| Formal covers | **38/38 reached** |
| RTL-to-gate LEC | **PASS** |
| Pad-level functional GLS | **PASS** |

The power-activity flow is independent of GLS and is documented in [Power Analysis](Power_Analysis.md).
