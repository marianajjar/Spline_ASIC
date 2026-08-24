# RTL Architecture and Implementation

## 1. Purpose and Design Organization

The RTL implements the synthesizable digital core of the spline-interpolation ASIC. It receives serial complex I/Q samples, reconstructs signed input words, performs programmable MINAJ2 cubic interpolation, schedules the interpolated samples at the required output rate, and applies a programmable 10-tap FIR low-pass filter.

The supported interpolation factors are

\[
L \in \{2,3,4,5\}.
\]

The design contains two parallel signal-processing paths, one for I and one for Q, together with shared configuration and timing control. The I path is the timing master: it determines the serial word mode, generates the raw processing strobes, and owns the interpolation-phase counter. The Q path follows the I timing so that both components of the complex signal remain aligned.

```text
top_interpolator_dac
|
+-- spi_cfg4_nomode                    configuration capture
|
+-- spi_i_master                       I SIPO + timing master
+-- spi_q_slave                        Q SIPO + timing slave
|
+-- word_history3                      I history
+-- word_history3                      Q history
|
+-- minaj2_interp_3samp_internalSlope  I MINAJ2 core
+-- minaj2_interp_3samp_internalSlope  Q MINAJ2 core
|
+-- minaj2_window_latch                I interpolation window
+-- minaj2_window_latch                Q interpolation window
|
+-- sample_shift_ntaps_I               I scheduler + phase master
+-- sample_shift_ntaps_Q               Q scheduler + phase slave
|
+-- fir20_q16_fromx                    I 10-tap FIR
+-- fir20_q16_fromx                    Q 10-tap FIR
```

The complete signal path is

```text
serial I/Q
   -> serial-to-parallel reception
   -> three-sample history
   -> MINAJ2 interpolation
   -> interpolation-window registers
   -> Sample Shift / phase scheduling
   -> 10-tap FIR
   -> dac_I / dac_Q
```

---

## 2. Top-Level Module

The top-level module is `top_interpolator_dac`.

### Parameters

| Parameter | Default | Description |
|---|---:|---|
| `WL` | 16 | Main signal word length |
| `FL` | 12 | Main fractional length |
| `NTAPS` | 10 | Number of FIR taps |

### Interface

| Signal | Width | Direction | Description |
|---|---:|---|---|
| `clk` | 1 | Input | External high-frequency system clock |
| `reset` | 1 | Input | Active-high asynchronous reset |
| `serial_in_I` | 1 | Input | Serial I input; also carries configuration and FIR coefficients |
| `serial_in_Q` | 1 | Input | Serial Q input |
| `dac_I` | 16 | Output | Signed filtered I output |
| `dac_Q` | 16 | Output | Signed filtered Q output |

All sequential logic remains in the external `clk` domain. The required lower processing rates are implemented with enable strobes rather than by generating additional internal clocks.

---

## 3. Operating Modes

The external clock and normal serial input-word length depend on the selected interpolation factor.

| \(L\) | External Clock | Normal Input Word | Input Rate | Output Rate |
|---:|---:|---:|---:|---:|
| 2 | 960 MHz | 16 bits | 60 MSa/s | 120 MSa/s |
| 3 | 900 MHz | 15 bits | 60 MSa/s | 180 MSa/s |
| 4 | 960 MHz | 16 bits | 60 MSa/s | 240 MSa/s |
| 5 | 900 MHz | 15 bits | 60 MSa/s | 300 MSa/s |

The two clock/word-length combinations preserve the same input sample rate:

\[
960\text{ MHz}/16 = 60\text{ MSa/s}
\]

and

\[
900\text{ MHz}/15 = 60\text{ MSa/s}.
\]

For \(L=3\) and \(L=5\), the received 15-bit samples are sign-extended internally to the common signed 16-bit representation.

---

## 4. Startup and Configuration Sequence

Configuration is received through `serial_in_I` before normal I/Q streaming begins.

```text
reset
  |
  v
wait for synchronization marker = 1
  |
  v
capture L[2:0]
  |
  v
en_stream = 1
  |
  v
load ten 16-bit FIR coefficients
  |
  v
coeff_done = 1
  |
  v
normal I/Q processing enabled
```

A key architectural point is that **completion of the L configuration and completion of FIR coefficient loading are different events**.

`en_stream` means that the interpolation-factor configuration is available and the serial/timing logic may operate. Normal sample processing does not begin until the ten FIR coefficients have also been received.

---

## 5. Interpolation-Factor Configuration

`spi_cfg4_nomode` monitors `serial_in_I` after reset.

Before synchronization, zeros are ignored. The first serial `1` is treated as the synchronization marker. The following three serial bits are stored as the interpolation factor.

The bits are captured in increasing bit-index order:

```text
first L bit  -> L[0]
second L bit -> L[1]
third L bit  -> L[2]
```

After the third bit, the value is stored in `L_ctrl` and `cfg_ready_now` becomes active. The top level uses

```text
en_stream = cfg_ready_now
```

to activate the serial-word and timing logic.

The intended normal operating set is \(L=2,3,4,5\). System-level verification and the block-level formal environment constrain normal processing to these supported values.

---

## 6. Coefficient-Loading Control

The top-level control separates coefficient loading from normal signal streaming with

```text
coeff_load_mode = en_stream && !coeff_done
en_iq           = en_stream &&  coeff_done
```

The three main operating intervals are therefore:

| State | `en_stream` | `coeff_done` | `coeff_load_mode` | `en_iq` | Active Function |
|---|---:|---:|---:|---:|---|
| Waiting for L | 0 | 0 | 0 | 0 | Configuration capture |
| FIR loading | 1 | 0 | 1 | 0 | Receive ten FIR coefficients |
| Normal streaming | 1 | 1 | 0 | 1 | Process I/Q samples |

This separation prevents coefficient words from updating the sample history or interpolation datapath.

---

## 7. FIR Coefficient Loading

### 7.1 Coefficient Source

All ten coefficients are received through the **I serial input**. The Q serial input is not used as a second coefficient path.

During coefficient loading,

```text
coeff_word = word_I
```

is connected to both FIR instances. Therefore the I and Q channels always use the same filter coefficient set.

### 7.2 Forced 16-Bit Coefficient Words

Normal samples use 16-bit words for \(L=2,4\) and 15-bit words for \(L=3,5\). FIR coefficients, however, are always signed 16-bit words.

The I master therefore receives

```text
force16_word = coeff_load_mode
```

which disables 15-bit mode while coefficients are being loaded.

This is particularly important for \(L=3\) and \(L=5\): their normal input samples are 15 bits, but their configuration coefficients are still received as 16-bit words.

### 7.3 Coefficient Completion and Storage

`strobe_common` is the raw completed-word pulse generated by the I master.

While `coeff_load_mode=1`, each `strobe_common` means that one complete coefficient is available in `word_I`. Both FIR blocks receive

```text
coeff_load_en = coeff_load_mode
coeff_strobe  = strobe_common
coeff_word    = word_I
```

and write the coefficient into the current load index.

`coeff_count` advances once per coefficient word. With `NTAPS=10`, coefficients 0 through 9 are loaded. When the tenth word arrives, `coeff_done` is asserted and remains high.

At that point:

```text
coeff_load_mode = 0
en_iq           = 1
```

and the normal I/Q datapath becomes active.

### 7.4 Configuration-Phase Coefficient Rate

Because coefficient words are always 16 bits, the coefficient-word rate depends only on the external clock:

| External Clock | Coefficient Width | Coefficient Word Rate |
|---:|---:|---:|
| 960 MHz | 16 bits | 60 Mword/s |
| 900 MHz | 16 bits | 56.25 Mword/s |

This difference exists only during coefficient loading. Normal I/Q operation remains 60 MSa/s for every supported \(L\).

---

## 8. I Serial Receiver — Timing Master

`spi_i_master` performs three main functions:

1. reconstruct the serial I word;
2. select 15- or 16-bit word operation;
3. generate the two raw timing strobes.

The normal word mode is

```text
L = 2 or 4 -> 16-bit mode
L = 3 or 5 -> 15-bit mode
```

unless `force16_word` is asserted during coefficient loading.

### 8.1 Word Counter

The serial word terminal count is

```text
term = 15  for 16-bit words
term = 14  for 15-bit words
```

so a raw `strobe` is produced once per complete serial word.

### 8.2 15-Bit Sign Extension

In 15-bit mode, bit 14 is the sign bit. The reconstructed word is extended to 16 bits by copying bit 14 into bit 15.

The rest of the datapath therefore always receives a signed 16-bit sample independent of the external word format.

### 8.3 Stable Word Mode

`mode15_word` is updated at a word boundary rather than in the middle of a word. This prevents a mode change from altering the interpretation of an active serial transfer.

---

## 9. Q Serial Receiver — Timing Slave

`spi_q_slave` reconstructs the Q sample but does not generate an independent timing decision.

It receives `mode15_word` from the I master and uses the same 15/16-bit format. Therefore I and Q:

- use the same word length;
- complete their serial words on the same clock boundary;
- use the same sign-extension rule;
- enter the downstream datapath as an aligned complex sample pair.

This I-master/Q-slave organization removes the possibility of independent I/Q word-boundary drift.

---

## 10. Strobe Architecture

The strobe structure is central to the multi-rate implementation.

The design does **not** generate separate 60, 120, 180, 240, or 300 MHz clocks. Instead, all state elements are physically clocked by the external 900/960 MHz clock, and processing occurs only when the appropriate one-cycle strobe is asserted.

There are four important strobe signals:

```text
strobe_common
strobe_iq
shift_strobe_common
shift_strobe_iq
```

The `_common` signals are raw timing events generated by the I master. The `_iq` signals are the same events gated by `coeff_done` so that they reach the normal datapath only after configuration is complete.

---

## 11. `strobe_common` — Raw Word-Completion Pulse

The I serial master generates

```text
strobe_common = en_stream && (count == term)
```

where `term` depends on the active word length.

Its meaning changes with the operating phase.

### During coefficient loading

`strobe_common` means:

```text
a complete 16-bit FIR coefficient is available
```

It advances the coefficient counter and writes `word_I` into both FIR coefficient arrays.

### During normal streaming

`strobe_common` means:

```text
a complete aligned I/Q input sample is available
```

For normal sample operation its rate is 60 MHz.

---

## 12. `strobe_iq` — Normal Input-Sample Pulse

The top level forms

```text
strobe_iq = strobe_common && coeff_done
```

This is the strobe used by the normal 60 MSa/s processing stages.

Each `strobe_iq`:

- commits a new I/Q word into the three-sample histories;
- advances the MINAJ2 slope state;
- causes a new interpolation group to be captured;
- resets the interpolation phase to the beginning of the new group.

Because it is gated by `coeff_done`, coefficient words cannot accidentally enter the interpolation datapath.

---

## 13. `shift_strobe_common` — Raw Interpolation-Rate Pulse

A second counter in `spi_i_master` generates the output-rate timing.

| \(L\) | External Clock | Divider | `shift_strobe_common` Rate |
|---:|---:|---:|---:|
| 2 | 960 MHz | 8 | 120 MHz |
| 3 | 900 MHz | 5 | 180 MHz |
| 4 | 960 MHz | 4 | 240 MHz |
| 5 | 900 MHz | 3 | 300 MHz |

The divider values are therefore

```text
L=2 -> 8
L=3 -> 5
L=4 -> 4
L=5 -> 3
```

which implements

\[
f_{shift}=60L\text{ MHz}.
\]

`shift_strobe_common` becomes active once `en_stream` is active, including during the coefficient-loading interval. It is therefore only a raw timing reference until configuration is complete.

---

## 14. `shift_strobe_iq` — Normal Output-Sample Pulse

The top level forms

```text
shift_strobe_iq = shift_strobe_common && coeff_done
```

This is the actual output-rate enable used by the Sample Shift and FIR stages.

Each pulse:

1. selects one stored I interpolation sample;
2. selects the corresponding Q interpolation sample;
3. shifts both values into their FIR delay lines;
4. advances the interpolation phase where appropriate;
5. updates the registered FIR outputs.

Its effective rate is \(60L\) MSa/s.

---

## 15. Control and Timing Summary

| Signal | Source | Rate / Condition | Main Purpose |
|---|---|---|---|
| `cfg_ready_now` | Configuration block | End of L capture | Indicates configuration is available |
| `en_stream` | Top level | After L capture | Enables serial/timing logic |
| `coeff_load_mode` | Top level | `en_stream && !coeff_done` | Selects coefficient-loading phase |
| `strobe_common` | I master | End of serial word | Raw word-completion event |
| `coeff_done` | Top level | After ten coefficients | Marks coefficient-loading completion |
| `en_iq` | Top level | `en_stream && coeff_done` | Enables normal datapath |
| `strobe_iq` | Top level | 60 MHz in normal mode | Commits one new I/Q input sample |
| `shift_strobe_common` | I master | \(60L\) MHz | Raw interpolation-rate event |
| `shift_strobe_iq` | Top level | \(60L\) MHz after config | Processes one output sample |
| `mode15_word` | I master | Per input word | Shared 15/16-bit mode |
| `phase_shared` | I Sample Shift | Per output phase | Synchronizes Q phase to I |

The relationship can be summarized as

```text
                   L configuration complete
                            |
                            v
                       en_stream
                            |
               +------------+------------+
               |                         |
               v                         v
        strobe_common             shift_strobe_common
               |                         |
        coefficient loading              |
               |                         |
               v                         |
          coeff_done --------------------+
               |                         |
               v                         v
          strobe_iq               shift_strobe_iq
           60 MHz                   60L MHz
               |                         |
               v                         v
      history + MINAJ2          Sample Shift + FIR
```

---

## 16. Timing Examples

### 16.1 \(L=4\)

```text
external clock       = 960 MHz
normal word length   = 16 bits
strobe_iq rate       = 960 / 16 = 60 MHz
shift_strobe_iq rate = 960 / 4  = 240 MHz
```

Four output-sample events are generated for each new 60 MSa/s input interval.

### 16.2 \(L=5\)

```text
external clock       = 900 MHz
normal word length   = 15 bits
strobe_iq rate       = 900 / 15 = 60 MHz
shift_strobe_iq rate = 900 / 3  = 300 MHz
```

Five output-sample events are generated for each input interval.

In this mode, input-word and output-rate events can coincide periodically. The I Sample Shift therefore gives the new-group `strobe_iq` priority when updating the phase, ensuring that every new interpolation group begins at phase zero.

---

## 17. Three-Sample History

Each channel uses `word_history3` to store the local MINAJ2 neighborhood:

```text
w0 = newest sample   = x_n
w1 = center sample   = x_c
w2 = previous sample = x_prev
```

On every valid input event:

```text
w2 <= w1
w1 <= w0
w0 <= word_in
```

The history updates only when `en_iq` and `strobe_iq` are active. I and Q histories therefore advance on the same input-sample event.

---

## 18. MINAJ2 Interpolation Core

Each channel contains one `minaj2_interp_3samp_internalSlope` instance.

The core uses the current three-sample window and stores the previous slope \(m_p\) internally.

### 18.1 Slope Recursion

The implemented relation is

\[
m_{new}=
\frac{-11x_{prev}-4m_p+8x_c+3x_n}{10}.
\]

The numerator is formed using shifts and additions. Division by 10 is approximated with

```text
Sum * 1638 >> 14
```

with a half-LSB bias before the arithmetic shift. The result is saturated to the signed 16-bit range.

`m_p` updates once per `strobe_iq`, so the slope state advances once for every new input sample interval.

### 18.2 Cubic Coefficients

The Hermite polynomial is represented as

\[
y(u)=c_0+c_1u+c_2u^2+c_3u^3
\]

with

\[
c_0=x_{prev},
\]

\[
c_1=m_p,
\]

\[
c_2=3(x_c-x_{prev})-2m_p-m_{new},
\]

\[
c_3=m_p+m_{new}-2(x_c-x_{prev}).
\]

### 18.3 Interpolation Phase Values

The normalized phase \(u\) is represented in Q1.15.

| Position | RTL Integer | Approximate Value |
|---|---:|---:|
| \(1/5\) | 6554 | 0.2000 |
| \(1/4\) | 8192 | 0.2500 |
| \(1/3\) | 10923 | 0.3333 |
| \(2/5\) | 13107 | 0.4000 |
| \(1/2\) | 16384 | 0.5000 |
| \(3/5\) | 19661 | 0.6000 |
| \(2/3\) | 21845 | 0.6667 |
| \(3/4\) | 24576 | 0.7500 |
| \(4/5\) | 26214 | 0.8000 |

The active interpolation groups are:

| \(L\) | Valid Group |
|---:|---|
| 2 | `y0`, `y1(1/2)` |
| 3 | `y0`, `y1(1/3)`, `y2(2/3)` |
| 4 | `y0`, `y1(1/4)`, `y2(1/2)`, `y3(3/4)` |
| 5 | `y0`, `y1(1/5)`, `y2(2/5)`, `y3(3/5)`, `y4(4/5)` |

`y0` is always the original `x_prev` sample.

### 18.4 Horner Evaluation

The cubic is evaluated in Horner form to avoid explicit calculation of \(u^2\) and \(u^3\). A half-LSB bias is inserted before the Q1.15 rescaling shifts to reduce fixed-point bias.

---

## 19. Interpolation-Window Registers

`minaj2_window_latch` captures `y0...y4` on `strobe_iq` and holds them stable until the next input sample arrives.

This creates a clean rate boundary:

```text
60 MHz:
    form and capture one interpolation group

60L MHz:
    transmit the members of the group one at a time
```

The Sample Shift logic therefore operates on a stable interpolation window while the next serial input word is being assembled.

---

## 20. Sample Shift and Shared Phase

### 20.1 I Channel — Phase Master

`sample_shift_ntaps_I` owns the interpolation phase.

For each `shift_strobe_iq`, the current phase selects one stored MINAJ2 output:

```text
phase 0 -> y0
phase 1 -> y1
phase 2 -> y2
phase 3 -> y3
phase 4 -> y4
```

Only the first \(L\) phases are used.

The selected sample is inserted into the 10-element FIR input delay line.

### 20.2 Phase Update

The phase logic is

```text
if strobe_iq:
    phase = 0
else if shift_strobe_iq and phase < L-1:
    phase = phase + 1
```

The input-sample strobe has priority over the shift strobe. This guarantees that a new interpolation group always restarts at phase zero.

### 20.3 Q Channel — Phase Slave

`sample_shift_ntaps_Q` receives

```text
phase_in = phase_shared
```

from the I path. Q therefore selects the same interpolation position as I on every `shift_strobe_iq`.

---

## 21. Programmable 10-Tap FIR

The generic FIR module is named `fir20_q16_fromx`; the top-level instance overrides it to

```text
NTAPS = 10
```

for the implemented ASIC.

Two instances are used, one for I and one for Q.

### 21.1 Runtime Coefficient Storage

Each FIR contains a coefficient array and `load_idx`.

On every coefficient-loading strobe:

```text
coeffs[load_idx] <= coeff_word
```

and the load index advances until the final coefficient.

The same `word_I` coefficient stream is connected to both filters.

### 21.2 FIR Input State

The Sample Shift blocks maintain the ten-sample delay-line arrays supplied to the FIRs:

```text
sr_I[0:9]
sr_Q[0:9]
```

A new selected interpolation sample enters each array on `shift_strobe_iq`.

### 21.3 Multiply-Accumulate Operation

The FIR computes

\[
y[n]=\sum_{k=0}^{9}x_kh_k.
\]

Products are accumulated in a 48-bit signed accumulator. The result is rescaled by the main fractional length `FL=12` and saturated to the signed 16-bit output range

\[
-32768 \le y \le 32767.
\]

The registered FIR outputs are connected directly to `dac_I` and `dac_Q`.

---

## 22. Fixed-Point Organization

The main top-level format is

```text
WL = 16
FL = 12
```

for samples, coefficients, and DAC outputs.

Additional precision is used internally for:

- MINAJ2 slope terms;
- cubic coefficients;
- polynomial products;
- FIR accumulation.

The normalized interpolation phase uses Q1.15 because it represents a fractional position between adjacent input samples.

---

## 23. End-to-End RTL Operation

The complete hardware sequence is:

```text
1. Reset the design.

2. Detect the synchronization marker on serial_in_I.

3. Capture L[2:0].

4. Assert en_stream.

5. Enter coeff_load_mode and force 16-bit serial words.

6. Receive ten FIR coefficients through serial_in_I.

7. On every strobe_common during coefficient loading:
       write word_I to the next coefficient location
       in both FIR filters.

8. After the tenth coefficient:
       coeff_done = 1
       coeff_load_mode = 0
       en_iq = 1

9. Receive aligned serial I/Q samples.

10. Every strobe_iq at 60 MHz:
       update the I/Q three-sample histories
       update the MINAJ2 slope state
       form and latch one interpolation group
       restart the output phase.

11. Every shift_strobe_iq at 60L MHz:
       select one I interpolation sample
       select the matching Q sample
       shift both samples into the FIR delay lines
       update the FIR outputs.

12. Present the filtered signed results on dac_I and dac_Q.
```

---

## 24. RTL Module Map

| Module | Main Responsibility |
|---|---|
| `top_interpolator_dac` | Top-level integration, coefficient control, strobe gating |
| `spi_cfg4_nomode` | Synchronization-marker detection and interpolation-factor capture |
| `spi_i_master` | I serial reconstruction, word-mode control, raw strobe generation |
| `spi_q_slave` | Q serial reconstruction using I-master mode |
| `word_history3` | Three-sample MINAJ2 input history |
| `minaj2_interp_3samp_internalSlope` | Fixed-point MINAJ2 interpolation and slope state |
| `minaj2_window_latch` | Stores the generated interpolation group |
| `sample_shift_ntaps_I` | I interpolation scheduling and phase control |
| `sample_shift_ntaps_Q` | Q scheduling using the shared I phase |
| `fir20_q16_fromx` | Runtime-loaded FIR MAC and output saturation |

---

## 25. Architectural Summary

The RTL implements the complete multi-rate interpolation chain in a single external clock domain.

Configuration first captures the interpolation factor and loads a common ten-coefficient FIR response. During normal operation, the I serial receiver becomes the timing master: it reconstructs sample words and generates both the 60 MHz input-sample event and the \(60L\) MHz output-sample event.

Aligned I/Q samples are stored in three-sample histories and processed by two identical MINAJ2 cores. Each input interval produces a group of \(L\) samples. The group is held in registers and serialized by the Sample Shift stage. The I interpolation phase is shared with Q so the complex signal remains synchronized. Finally, the selected samples are filtered by matched programmable 10-tap FIR filters and delivered as signed 16-bit DAC outputs.

The combination of raw and gated strobes allows configuration and normal processing to reuse the same serial/timing logic without creating additional internal clock domains.
