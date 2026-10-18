import unittest, wave, struct, os, tempfile, math
from make_sound import make

def rms(frames):
    return math.sqrt(sum(f * f for f in frames) / len(frames)) if frames else 0.0

class TestSound(unittest.TestCase):
    def test_quiet_then_loud_under_30s(self):
        path = os.path.join(tempfile.mkdtemp(), "s.wav")
        make(path)
        with wave.open(path) as w:
            self.assertEqual(w.getsampwidth(), 2)
            self.assertEqual(w.getnchannels(), 1)
            rate = w.getframerate()
            n = w.getnframes()
            self.assertLess(n / rate, 30.0)
            data = struct.unpack("<%dh" % n, w.readframes(n))
        quiet = data[: 20 * rate]
        loud = data[20 * rate:]
        self.assertLess(rms(quiet), 0.05 * rms(loud))
        self.assertGreater(rms(quiet), 0)

if __name__ == "__main__":
    unittest.main()
