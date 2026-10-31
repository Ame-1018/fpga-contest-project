# 生成 VPU_audio_wave 的汉宁窗、旋转因子、频段表，以及第 123 秒样本。
# 整数 FFT 与 RTL 同一套：DIF、每级右移 1、Q15 旋转因子、输出按位反序读。

import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
WAV = ROOT / "doc" / "音乐" / "莫文蔚 盛夏的果实.wav"
N = 256
CAP = 1024
WAVE_N = 640
FULL = 169


def q15_round(x):
    if x >= 0:
        return int(math.floor(x + 0.5))
    return int(math.ceil(x - 0.5))


def sat16(v):
    if v > 32767:
        return 32767
    if v < -32768:
        return -32768
    return int(v)


def sex16(v):
    v &= 0xFFFF
    if v >= 0x8000:
        return v - 0x10000
    return v


def mul_q15(a, b):
    return sat16((int(a) * int(b)) >> 15)


def bitrev8(a):
    r = 0
    for i in range(8):
        if a & (1 << i):
            r |= 1 << (7 - i)
    return r


def band_edges():
    edges = [1]
    for i in range(1, 33):
        e = int(round(128 ** (i / 32.0)))
        if e <= edges[-1]:
            e = edges[-1] + 1
        if e > 128:
            e = 128
        edges.append(e)
    edges[-1] = 128
    return edges


EDGES = band_edges()


def band_of(bin_i):
    for b in range(32):
        if EDGES[b] <= bin_i < EDGES[b + 1]:
            return b
    return 31


def hann_table():
    out = []
    for n in range(N):
        w = 0.5 * (1.0 - math.cos(2.0 * math.pi * n / N)) * 32767.0
        out.append(max(0, min(32767, q15_round(w))))
    return out


def twiddle_table():
    cos_q = []
    sin_q = []
    for k in range(N // 2):
        th = 2.0 * math.pi * k / N
        cos_q.append(sat16(q15_round(math.cos(th) * 32767.0)))
        sin_q.append(sat16(q15_round(-math.sin(th) * 32767.0)))
    return cos_q, sin_q


HANN = hann_table()
TW_COS, TW_SIN = twiddle_table()


def fft_mags(samples):
    re = [mul_q15(sex16(samples[n]), HANN[n]) for n in range(N)]
    im = [0] * N
    for stage in range(8):
        span = N >> stage
        half = span >> 1
        for start in range(0, N, span):
            for j in range(half):
                ia = start + j
                ib = ia + half
                tw = j << stage
                ar, ai = re[ia], im[ia]
                br, bi = re[ib], im[ib]
                sr = (ar + br) >> 1
                si = (ai + bi) >> 1
                dr = (ar - br) >> 1
                di = (ai - bi) >> 1
                wr, wi = TW_COS[tw], TW_SIN[tw]
                tr = sat16(mul_q15(dr, wr) - mul_q15(di, wi))
                ti = sat16(mul_q15(dr, wi) + mul_q15(di, wr))
                re[ia], im[ia] = sat16(sr), sat16(si)
                re[ib], im[ib] = tr, ti
    mags = [0] * N
    for k in range(N):
        i = bitrev8(k)
        ar = abs(re[i])
        ai = abs(im[i])
        if ar > 32767:
            ar = 32767
        if ai > 32767:
            ai = 32767
        hi = ar if ar >= ai else ai
        lo = ai if ar >= ai else ar
        mags[k] = hi + (lo >> 1)
    return mags


def bar_heights(mags):
    acc = [0] * 32
    for k in range(1, 128):
        b = band_of(k)
        acc[b] += mags[k]
        if acc[b] > 65535:
            acc[b] = 65535
    peak = max(acc) if acc else 0
    bars = []
    for v in acc:
        if peak == 0:
            bars.append(0)
        else:
            q = (v * FULL) // peak
            if q > FULL:
                q = FULL
            bars.append(q)
    return bars, acc, peak


def wave_y(sample):
    off = (sex16(sample) * 185) >> 15
    y = 384 - off
    if y < 300:
        return 300
    if y > 468:
        return 468
    return y


def write_mem(path, values, digits=4):
    path.write_text("\n".join(f"{v & ((1 << (digits * 4)) - 1):0{digits}X}" for v in values) + "\n", encoding="ascii")


def load_wav_left(second):
    with wave.open(str(WAV), "rb") as wf:
        ch = wf.getnchannels()
        rate = wf.getframerate()
        bits = wf.getsampwidth() * 8
        n = wf.getnframes()
        if (ch, rate, bits) != (2, 48000, 16):
            raise SystemExit(f"unexpected wav {ch}ch {rate}Hz {bits}bit")
        start = second * rate
        if start + CAP > n:
            raise SystemExit("wav is shorter than the requested window")
        wf.setpos(start)
        blob = wf.readframes(CAP)
    samples = []
    for i in range(CAP):
        left, _right = struct.unpack_from("<hh", blob, i * 4)
        samples.append(left & 0xFFFF)
    return samples


def sine_check():
    tone = []
    for n in range(N):
        tone.append(sat16(q15_round(math.sin(2.0 * math.pi * 10 * n / N) * 16000)))
    mags = fft_mags(tone)
    k = max(range(1, 128), key=lambda i: mags[i])
    if k != 10 and k != 246:
        raise SystemExit(f"sine peak bin {k}, want 10")
    print(f"sine peak bin {k} mag {mags[k]}")


def main():
    sine_check()
    samples = load_wav_left(123)
    wave_samples = samples[CAP - WAVE_N :]
    fft_samples = samples[CAP - N :]
    mags = fft_mags(fft_samples)
    bars, acc, peak = bar_heights(mags)
    ys = [wave_y(s) for s in wave_samples]
    write_mem(OUT / "audio_hann.mem", HANN)
    write_mem(OUT / "audio_tw_cos.mem", TW_COS)
    write_mem(OUT / "audio_tw_sin.mem", TW_SIN)
    write_mem(OUT / "audio_samples.mem", samples)
    write_mem(OUT / "audio_bar_gold.mem", bars, 2)
    write_mem(OUT / "audio_wave_y_gold.mem", ys)
    print("edges", EDGES)
    print("bars", bars)
    print("peak", peak, "acc", acc)
    print("y min/max", min(ys), max(ys))
    print("sample peak", max(abs(sex16(s)) for s in wave_samples))


if __name__ == "__main__":
    main()
