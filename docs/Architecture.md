# System Architecture

## 1. Overview

The project implements a real-time ASIC for interpolation of complex baseband I/Q signals sampled at 60 MSa/s. Four programmable interpolation factors are supported:

\[
L \in \{2,3,4,5\}
\]

which produce output rates of 120, 180, 240, and 300 MSa/s.

Interpolation is performed using the MINAJ2 local cubic method, followed by a programmable 10-tap FIR cleanup filter. The architecture contains parallel I and Q datapaths with shared control. The I path acts as the timing master and the Q path follows its word and interpolation-phase timing.

## 2. Operating Modes

| L | External Clock | Serial Input Word | Input Rate | Output Rate |
|---:|---:|---:|---:|---:|
| 2 | 960 MHz | 16 bits | 60 MSa/s | 120 MSa/s |
| 3 | 900 MHz | 15 bits | 60 MSa/s | 180 MSa/s |
| 4 | 960 MHz | 16 bits | 60 MSa/s | 240 MSa/s |
| 5 | 900 MHz | 15 bits | 60 MSa/s | 300 MSa/s |

For \(L=3\) and \(L=5\), the received 15-bit sample is sign-extended internally to the common 16-bit datapath representation.

## 3. Configuration and Streaming

Configuration is completed before normal I/Q data processing:

```text
Reset
  |
  v
Synchronization marker
  |
  v
Capture L[2:0]
  |
  v
Load 10 signed 16-bit FIR coefficients
  |
  v
Coefficient loading complete
  |
  v
Enable normal I/Q streaming
```

The configuration and coefficient stream is received through the I serial input. The same coefficient set is loaded into both FIR filters.

## 4. Datapath Organization

```text
                    Shared Configuration / Timing
                              |
                 +------------+------------+
                 |                         |
             I Datapath                 Q Datapath
                 |                         |
        Serial-to-Parallel        Serial-to-Parallel
                 |                         |
        Three-Sample History      Three-Sample History
                 |                         |
          MINAJ2 Interpolator       MINAJ2 Interpolator
                 |                         |
        Interpolation Window      Interpolation Window
                 |                         |
         Sample Scheduler          Sample Scheduler
                 |                         |
            10-Tap FIR                10-Tap FIR
                 |                         |
              dac_I                     dac_Q
```

The numerical processing is identical in the two channels. Shared timing prevents independent I/Q phase or word-boundary drift.

## 5. Clocking and Multi-Rate Control

All sequential RTL remains in one external high-frequency clock domain. Lower processing rates are created using strobes and enables rather than internally generated clocks.

The main events are:

- `strobe_common` — raw completed serial-word event from the I timing master.
- `strobe_iq` — aligned normal I/Q input-sample event, enabled only after coefficient loading.
- `shift_strobe_common` — raw interpolation/output-rate scheduling event.
- `shift_strobe_iq` — normal output scheduling event after configuration is complete.

This approach supports several data rates while keeping the clock structure simple for synthesis and physical implementation.

## 6. MINAJ2 Interpolation

MINAJ2 was selected after MATLAB algorithm evaluation as a hardware-suitable local cubic interpolation method. It uses three neighboring samples and a recursively updated slope estimate, avoiding the global linear-system solution required by classical cubic spline interpolation.

The main signal datapath is 16 bits with 12 fractional bits. The normalized interpolation phase \(u\) is represented in Q1.15.

## 7. Programmable FIR

A 10-tap FIR cleanup filter follows each interpolator. Ten signed 16-bit coefficients are loaded at startup through the I configuration stream and copied into both channel filters.

The FIR uses a wider internal accumulator, rescales by the configured fractional length, and saturates the final result back to the signed 16-bit output format.

## 8. Related Documentation

- [MATLAB Model](MATLAB_Model.md)
- [RTL Architecture](RTL_Architecture.md)
- [Verification](Verification.md)
- [Synthesis](Synthesis.md)
- [Physical Design](Physical_Design.md)
- [Power Analysis](Power_Analysis.md)
- [Signoff](Signoff.md)
