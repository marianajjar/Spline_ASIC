# MATLAB Modeling and RTL Golden Reference

## 1. Purpose

MATLAB is used for two complementary tasks:

1. **Algorithm development and signal-quality evaluation** — 64-QAM generation, floating- and fixed-point MINAJ2 evaluation, FIR design, spectral analysis, RMSE, EVM, and VSA export.
2. **Bit-accurate RTL verification** — reproduction of the RTL integer arithmetic, generation of regression stimulus, and sample-by-sample comparison against captured RTL outputs.

These two models are intentionally separated: the algorithm model is convenient for signal-quality study, while the RTL golden model reproduces implementation-specific finite-width behavior.

## 2. Main MATLAB Files

| File | Role |
|---|---|
| `spline_project.m` | Main algorithm-development and signal-analysis script |
| `minAJ2_float.m` | Floating-point MINAJ2 implementation |
| `fix_firpm_coeff.m` | 10-tap FIR design, Q12 quantization, fixed-point filtering, and VSA export |
| `spline_golden_rtl.m` | Bit-accurate model of the implemented MINAJ2 + FIR datapath |
| `RUN_ALL_MODES.m` | Regression generation and comparison for all supported modes |
| `compare_rtl_golden.m` | Alignment search and exact signed-I/Q comparison |

Supporting helper functions and IQTools functions must be available on the MATLAB path when their corresponding scripts are used.

## 3. Reference Signal

The main communication waveform is a complex 64-QAM baseband signal:

\[
s[n] = I[n] + jQ[n]
\]

with the following parameters:

| Parameter | Value |
|---|---:|
| Modulation | 64-QAM |
| Input sample rate | 60 MSa/s |
| Number of symbols | 4000 |
| Samples per symbol | 3 |
| Pulse shaping | Root Raised Cosine |
| RRC roll-off | 0.15 |
| RRC span | 80 symbols |
| Interpolation factors | \(L=2,3,4,5\) |

For each interpolation factor,

\[
f_{s,out}=L f_{s,in}
\]

giving 120, 180, 240, and 300 MSa/s.

## 4. Algorithm-Level MINAJ2 Model

The floating-point model evaluates MINAJ2 independently on I and Q and recombines them into a complex output.

For normalized phase

\[
u_k=\frac{k}{L}, \qquad k=0,\ldots,L-1
\]

the cubic Hermite form is

\[
y(u)=H_{00}x_0+H_{01}x_1+H_{10}m_0+H_{11}m_1
\]

with the standard cubic Hermite basis functions.

The steady-state MINAJ2 slope recursion is

\[
s_i=\frac{-11x_{i-1}-4s_{i-1}+8x_i+3x_{i+1}}{10}.
\]

The high-level model is used to study waveform quality, spectral behavior, RMSE, and EVM. It is not used as the exact RTL checker because the RTL includes finite-width arithmetic and streaming-state details.

## 5. Fixed-Point Model

The implemented signal datapath uses 16-bit signed data with 12 fractional bits. The RTL golden model also reproduces:

- three-sample streaming history,
- recursive slope state,
- fixed intermediate widths,
- signed wrapping where required,
- saturation,
- Q1.15 interpolation constants,
- MINAJ2 rounding behavior,
- streaming FIR state.

The Q1.15 interpolation positions use the same integer constants as RTL, including:

| Fraction | Q1.15 |
|---:|---:|
| \(1/5\) | 6554 |
| \(1/4\) | 8192 |
| \(1/3\) | 10923 |
| \(2/5\) | 13107 |
| \(1/2\) | 16384 |
| \(3/5\) | 19661 |
| \(2/3\) | 21845 |
| \(3/4\) | 24576 |
| \(4/5\) | 26214 |

## 6. FIR Design

A separate 10-tap FIR coefficient set is generated for each interpolation mode using `firpm`.

| Parameter | Value |
|---|---:|
| Number of taps | 10 |
| Passband edge | 14 MHz |
| Stopband edge | 44 MHz |
| Passband weight | 10000 |
| Stopband weight | 200 |
| Coefficient word length | 16 bits |
| Fraction length | 12 bits |

The floating-point coefficients are quantized to signed Q12 integers:

\[
h_{int}=\mathrm{sat}_{16}\left(\mathrm{round}(h_{float}2^{12})\right).
\]

All ten coefficients are exported; the RTL loads ten 16-bit words rather than only the unique coefficients of a symmetric filter.

## 7. Bit-Accurate RTL Golden Model

For each source sample, the golden model updates the same three-sample history used by RTL:

```text
w2 <- w1
w1 <- w0
w0 <- new sample
```

so that

```text
x_prev = w2
x_c    = w1
x_n    = w0
```

The RTL-compatible slope numerator is

\[
Sum=8x_c+3x_n-11x_{prev}-4m_p
\]

and the divide-by-ten approximation is reproduced as

\[
m_{raw}=\left(Sum\cdot1638+8192\right)\gg14
\]

followed by signed saturation.

The cubic polynomial is evaluated using the same Q1.15 Horner-form arithmetic as the RTL. The FIR golden model reproduces the 10-tap streaming delay line, accumulator scaling by 12 fractional bits, and output saturation. The current bit-exact regression uses `FIR_ROUND=0`.

## 8. Regression Flow

`RUN_ALL_MODES.m` covers:

- \(L=2,3,4,5\),
- all 12 ordered transitions between different interpolation factors,
- long 64-QAM sequences,
- zero and DC inputs,
- impulse behavior,
- positive and negative full-scale cases,
- arithmetic saturation cases.

The script generates the serial input data and golden output data required by the RTL regression.

After simulation, `compare_rtl_golden.m`:

1. reads the captured RTL hexadecimal I/Q output,
2. converts it to signed 16-bit values,
3. searches a small alignment range,
4. compares aligned samples exactly,
5. reports the first mismatch if any.

Final regression result:

```text
MATLAB bit-accurate golden model vs RTL: PASS
```

## 9. Signal-Quality Evaluation

The project evaluates the algorithm using waveform comparison, spectral analysis, RMSE, EVM, and 64-QAM constellation measurements. Final EVM values used in the project summary are collected in [Results](Results.md).

VSA-compatible MAT/text exports are also generated for communication-quality inspection.

## 10. MATLAB Repository Content

The public `MATLAB/` directory should contain the project scripts, coefficient-generation logic, golden-model code, and small representative inputs/outputs required to understand the flow. Large generated datasets and tool-specific temporary files should remain excluded from version control.
