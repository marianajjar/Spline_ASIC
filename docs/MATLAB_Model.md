# MATLAB Modeling and RTL Golden Reference

## 1. Purpose

The MATLAB environment serves two different purposes:

1. **Algorithm and signal-quality development**
2. **Bit-accurate RTL verification**

The high-level model is used to compare interpolation methods and evaluate communication quality. A separate integer golden model reproduces the exact RTL state updates, finite-width arithmetic, Q-format constants, saturation behavior, and FIR streaming order.

## 2. Main MATLAB Files

| File | Main Role |
|---|---|
| `spline_project.m` | High-level algorithm development and signal-quality analysis |
| `minAJ2_float.m` | Floating-point MINAJ2 interpolation |
| `fix_firpm_coeff.m` | FIRPM design, Q12 coefficient quantization, fixed-point filtering, VSA export |
| `spline_golden_rtl.m` | Bit-accurate integer model of MINAJ2 + FIR RTL |
| `RUN_ALL_MODES.m` | Generates/runs the multi-mode regression |
| `compare_rtl_golden.m` | Alignment search and exact RTL/golden comparison |

## 3. Reference 64-QAM Signal

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

The complex signal is

$$
s[n] = I[n] + jQ[n].
$$

The output rate is

$$
f_{out}=L\cdot60\ \text{MSa/s}.
$$

## 4. Floating-Point MINAJ2

The floating-point model uses cubic Hermite interpolation.

For normalized phase

$$
u_k=\frac{k}{L}, \qquad k=0,\ldots,L-1
$$

the Hermite form is

$$
y(u)=H_{00}x_0+H_{01}x_1+H_{10}m_0+H_{11}m_1.
$$

The basis functions are:

$$
H_{00}=2u^3-3u^2+1
$$

$$
H_{01}=-2u^3+3u^2
$$

$$
H_{10}=u^3-2u^2+u
$$

$$
H_{11}=u^3-u^2.
$$

The steady-state MINAJ2 slope recursion is

$$
s_i=\frac{-11x_{i-1}-4s_{i-1}+8x_i+3x_{i+1}}{10}.
$$

This model is used for algorithm-level waveform, spectrum, RMSE, and EVM evaluation.

## 5. Fixed-Point Representation

The main signal datapath uses:

| Quantity | Format |
|---|---|
| Main signal | Signed 16-bit, 12 fractional bits |
| FIR coefficients | Signed 16-bit, Q12 |
| MINAJ2 interpolation phase | Q1.15 |
| Odd-mode external input | Signed 15-bit, sign-extended in RTL |

The RTL golden model explicitly reproduces:

- three-sample history;
- recursive slope state;
- fixed intermediate widths;
- arithmetic right shifts;
- signed wrapping where required;
- saturation;
- Q1.15 phase constants;
- FIR delay-line state.

## 6. RTL-Compatible MINAJ2 Arithmetic

For each new source sample,

```text
w2 <- w1
w1 <- w0
w0 <- new sample
```

with

```text
x_prev = w2
x_c    = w1
x_n    = w0
```

The slope numerator is

$$
S = 8x_c + 3x_n - 11x_{prev} - 4m_p.
$$

The RTL divide-by-ten approximation is modeled as

```text
m_raw = (S * 1638 + 8192) >>> 14
```

followed by signed 16-bit saturation.

The cubic coefficients are

$$
\Delta=x_c-x_{prev}
$$

$$
c_0=x_{prev}
$$

$$
c_1=m_p
$$

$$
c_2=3\Delta-2m_p-m_{new}
$$

$$
c_3=m_p+m_{new}-2\Delta.
$$

The polynomial is evaluated in Horner form using the same Q1.15 constants as RTL.

## 7. FIR Design

A 10-tap FIR coefficient set is generated independently for each \(L\).

| Parameter | Value |
|---|---:|
| Number of taps | 10 |
| Passband edge | 14 MHz |
| Stopband edge | 44 MHz |
| Passband weight | 10000 |
| Stopband weight | 200 |
| Word length | 16 bits |
| Fraction length | 12 bits |

The floating-point coefficient vector is generated with `firpm` and quantized using

$$
h_{int}=sat_{16}\left(round\left(h_{float}\cdot2^{12}\right)\right).
$$

All ten signed coefficients are exported and loaded into the RTL. The implementation does not rely on loading only five unique coefficients.

## 8. Bit-Accurate Regression

`RUN_ALL_MODES.m` covers:

- all four supported interpolation factors;
- all 12 ordered mode transitions;
- long 64-QAM sequences;
- zero and DC cases;
- impulse cases;
- positive/negative full scale;
- saturation cases.

After RTL simulation, `compare_rtl_golden.m` converts the hexadecimal output back to signed 16-bit values, searches the allowed alignment range, and then compares I/Q sample-by-sample.

Final result:

```text
MATLAB bit-accurate golden model vs RTL: PASS
```

The current regression uses `FIR_ROUND=0`, matching the implemented FIR output scaling behavior.

## 9. Signal-Quality Metrics

The algorithm model is evaluated using:

- time-domain I/Q comparisons;
- spectrum/FFT comparisons;
- RMSE;
- EVM;
- 64-QAM constellation plots;
- VSA-compatible exports.

Final EVM values are summarized in [Results](Results.md).
