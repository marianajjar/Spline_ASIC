# Verification

## 1. Verification Strategy

The ASIC was verified from individual RTL blocks through the complete integrated design using simulation, assertions, functional coverage, formal verification, logic equivalence checking, and pad-level gate-level simulation.

```text
Block-Level Simulation
        |
        v
Top-Level RTL Regression <---- MATLAB Bit-Accurate Golden Model
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

Self-checking SystemVerilog testbenches were developed for the major control and datapath blocks.

| Block | Main Checks |
|---|---|
| Configuration | Synchronization marker, \(L\) capture, reset, legal/illegal values |
| I Serial Master | 15/16-bit reconstruction, sign extension, word strobes, shift strobes, forced 16-bit coefficient mode |
| Q Serial Slave | Serial reconstruction and alignment to the I timing master |
| Sample History | Three-sample update, hold, reset, random samples |
| MINAJ2 | Slope update, \(L=2..5\), fixed-point arithmetic, saturation |
| Window Latch | Interpolation-group capture and hold |
| Sample Shift I/Q | Phase progression, shared phase, simultaneous input/output events |
| FIR | Coefficient loading, MAC state, scaling, saturation |

Directed tests, boundary cases, reset cases, and arithmetic corner cases are combined with self-checking reference calculations.

## 3. Top-Level RTL Regression

The integrated regression applies the complete transaction:

```text
Synchronization + L
        |
        v
10 FIR coefficient words
        |
        v
Serial I/Q input samples
        |
        v
MINAJ2 interpolation
        |
        v
10-tap FIR
        |
        v
Captured DAC I/Q output
```

The regression covers:

- all four supported modes \(L=2,3,4,5\),
- all 12 ordered transitions between different \(L\) values,
- long 64-QAM sequences,
- zero and DC inputs,
- impulse behavior,
- positive and negative full-scale values,
- saturation cases,
- reset during configuration and streaming.

Captured RTL outputs are aligned and compared sample-by-sample against the MATLAB integer golden model.

**Bit-exact MATLAB-to-RTL result: PASS**

## 4. Assertions and Coverage

SystemVerilog Assertions check the main control and datapath invariants, including:

- legal and stable interpolation-factor configuration,
- coefficient-loading progression and completion,
- no normal I/Q processing before `coeff_done`,
- legal strobe relationships,
- legal phase range and progression,
- MINAJ2 state update/hold behavior,
- arithmetic saturation,
- FIR coefficient and output behavior.

Functional coverage tracks the supported modes, all ordered mode transitions, interpolation phases, control states, and important arithmetic corner cases.

| Coverage Metric | Result |
|---|---:|
| Functional coverage | **100%** |
| Assertion coverage | **100%** |

These are functional/assertion coverage results; they are not claimed as 100% code coverage.

## 5. Formal Verification

Synopsys VC Formal was used for block-level formal property verification of nine RTL blocks.

| Metric | Result |
|---|---:|
| RTL blocks verified | 9 |
| Assertions analyzed | 123 |
| Proven assertions | 118 |
| Vacuous assertions | 5 |
| Failed assertions | **0** |
| Cover properties reached | **38 / 38 (100%)** |

The five vacuous properties are reset-related assertions in runs where reset was constrained inactive. All formal cover properties were reached.

Formal SVA sources and reports are kept under the verification/formal portion of the repository.

## 6. RTL-to-Gate Logic Equivalence

Cadence Conformal was used to compare the RTL reference with the synthesized gate-level implementation.

| Metric | Result |
|---|---:|
| Equivalent compare points | 669 |
| Incomplete verification | 0 |
| Design ambiguity | 0 |
| Final result | **PASS** |

This result is specifically the RTL-to-synthesized-gate comparison.

## 7. Pad-Level Gate-Level Simulation

A separate functional gate-level simulation was performed after pad integration using the padded top-level design.

The testbench applies the same logical configuration sequence and I/Q traffic used by the RTL environment. All four interpolation factors were exercised.

**Pad-level GLS result: PASS**

The preserved GLS result is a functional/zero-delay verification result; no SDF-based timing claim is made here.

Final pad-level GLS files and reports are organized under:

```text
Signoff/GLS_Pad_Level/
```

## 8. Verification Summary

| Stage | Result |
|---|---|
| Block-level simulation | Completed |
| Top-level RTL regression | **PASS** |
| MATLAB bit-accurate comparison | **PASS** |
| Functional coverage | **100%** |
| Assertion coverage | **100%** |
| VC Formal | **118 proven, 0 failed** |
| Formal covers | **38/38 reached** |
| RTL-to-gate LEC | **PASS** |
| Pad-level functional GLS | **PASS** |

Post-route power activity is generated independently using the dedicated `SAIF_Generation/` flow described in [Power Analysis](Power_Analysis.md), not from the pad-level GLS flow.
