# System Architecture

## Overview

This project implements a real-time ASIC for interpolation of complex baseband I/Q signals. The design receives serial I and Q samples at 60 MSa/s and supports programmable interpolation factors

\[
L \in \{2,3,4,5\}
\]

giving output sample rates of 120, 180, 240, and 300 MSa/s. Interpolation is performed using the MINAJ2 cubic interpolation algorithm followed by a programmable 10-tap FIR cleanup filter.

The architecture uses two parallel datapaths for the I and Q channels with shared control. The I path acts as the timing master and generates the common word and phase control used by the Q path.

## Key Specifications

| Parameter | Value |
|---|---|
| Input signal | Complex I/Q, 64-QAM |
| Input sample rate | 60 MSa/s |
| Interpolation factors | 2, 3, 4, 5 |
| Output sample rates | 120, 180, 240, 300 MSa/s |
| Main datapath width | 16 bits |
| Internal fractional length | 12 bits |
| Interpolation algorithm | MINAJ2 cubic interpolation |
| FIR filter | Programmable 10-tap FIR |
| External clock | 960 MHz for even L, 900 MHz for odd L |
| Normal serial input word | 16 bits for even L, 15 bits for odd L |
| Channels | Parallel I and Q datapaths |
| Control | Shared control, I path as timing master |

## Operating Modes

| L | External Clock | Serial Input Word | Output Rate |
|---:|---:|---:|---:|
| 2 | 960 MHz | 16 bits | 120 MSa/s |
| 3 | 900 MHz | 15 bits | 180 MSa/s |
| 4 | 960 MHz | 16 bits | 240 MSa/s |
| 5 | 900 MHz | 15 bits | 300 MSa/s |

For the odd interpolation modes, the received 15-bit sample is sign-extended internally to the 16-bit datapath width.

## Configuration and Streaming Sequence

The chip starts in configuration mode after reset. A synchronization marker is detected first, followed by the 3-bit interpolation-factor field. After the interpolation factor is configured, ten signed 16-bit FIR coefficient words are loaded serially through the I input. The same coefficient set is used by both the I and Q FIR filters.

After all coefficients are loaded, the design enters streaming mode. The shared controller then coordinates sample-word capture, interpolation phase generation, output shifting, and FIR processing.

The high-level sequence is:

```text
Reset
  ↓
Synchronization marker
  ↓
Capture L
  ↓
Load 10 FIR coefficients
  ↓
Enable I/Q streaming
  ↓
MINAJ2 interpolation
  ↓
Programmable FIR filtering
  ↓
I/Q output samples
```

## Clocking Strategy

The implementation uses a single high-frequency external clock domain. Lower-rate operations are controlled using clock enables and strobes rather than generated internal clocks. This keeps the clocking structure simple while supporting all four interpolation modes.

The main internal control events are:

- **Input-word strobe** – marks completion of an aligned I/Q input word.
- **Interpolation/output shift strobe** – schedules interpolated output samples according to the selected value of \(L\).
- **Coefficient-load mode** – enables serial loading of the ten FIR coefficients before normal streaming.
- **Streaming enable** – activates the I/Q datapaths after configuration is complete.

## Datapath

Each channel contains the following processing stages:

```text
Serial Input
    ↓
Serial-to-Parallel Capture
    ↓
Sample History
    ↓
MINAJ2 Cubic Interpolator
    ↓
Interpolation Window / Sample Shift
    ↓
10-Tap FIR Filter
    ↓
Output
```

The I and Q datapaths perform the same numerical processing. Shared control keeps both channels synchronized and reduces duplicated control logic.

## MINAJ2 Interpolator

MINAJ2 was selected after algorithm-level evaluation in MATLAB. It implements local cubic Hermite interpolation using three neighboring samples and an internally updated slope estimate. The RTL uses fixed-point arithmetic and evaluates the cubic polynomial using a Horner-form implementation.

The interpolation phase \(u\) is represented in Q1.15 format, while the main signal datapath uses a 16-bit fixed-point representation with 12 fractional bits.

## Programmable FIR Filter

A 10-tap FIR cleanup filter follows the interpolator. The filter coefficients are loaded during configuration, allowing the same hardware architecture to support coefficient sets optimized for the different interpolation modes.

The FIR uses a wider internal accumulator, scales the accumulated result back to the datapath format, and applies output saturation.

## Further Documentation

- [MATLAB Model](Matlab_model.md)
- [RTL Architecture](RTL_architecture.md)
- [Verification](Verification.md)
- [Synthesis](Synthesis.md)
- [Physical Design](Physical_design.md)
- [Signoff](Signoff.md)
