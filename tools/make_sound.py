"""Writes probe_ramp.wav: 20 s of a soft chime (about -36 dB), then 8 s of a loud two-tone alarm."""
import math, struct, sys, wave

RATE = 22050

def make(path):
    frames = []
    for i in range(20 * RATE):           # soft chime: 0.3 s beep each second
        t = i / RATE
        on = (t % 1.0) < 0.3
        frames.append(0.015 * math.sin(2 * math.pi * 880 * t) if on else 0.0)
    for i in range(8 * RATE):            # loud alternating 1000/1500 Hz
        t = i / RATE
        f = 1000 if int(t * 4) % 2 == 0 else 1500
        frames.append(0.9 * (1 if math.sin(2 * math.pi * f * t) >= 0 else -1))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x)) * 32767)) for x in frames))

if __name__ == "__main__":
    make(sys.argv[1] if len(sys.argv) > 1 else "../App/Resources/probe_ramp.wav")
