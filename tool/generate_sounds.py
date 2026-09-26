"""Generates assets/sounds/*.wav (run: python3 tool/generate_sounds.py).

countdown.wav: short beeps at 0,1,2,3,4 s + long high beep at 5 s (= rest end).
end.wav:       only the long end beep.
"""
import math
import struct
import wave

RATE = 44100


def tone(freq, dur, amp=0.85):
    n = int(RATE * dur)
    fade = int(RATE * 0.008)
    out = []
    for i in range(n):
        env = min(1.0, i / fade, (n - i) / fade)
        t = i / RATE
        # Sine plus a little 3rd harmonic so it cuts through music.
        v = math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(2 * math.pi * 3 * freq * t)
        out.append(amp * env * v / 1.25)
    return out


def write(path, samples):
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32767)) for s in samples))


def place(total, events):
    buf = [0.0] * int(RATE * total)
    for start, samples in events:
        o = int(RATE * start)
        for i, s in enumerate(samples):
            buf[o + i] += s
    return buf


short = tone(880, 0.15)
final = tone(1320, 0.8)
write('assets/sounds/countdown.wav', place(5.9, [(s, short) for s in range(5)] + [(5, final)]))
write('assets/sounds/end.wav', place(0.9, [(0, final)]))
