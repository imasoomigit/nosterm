#!/usr/bin/env python3
"""Synthesise the short samples used by the optional IBM style audio.

Everything the application plays is generated here so the repository never
has to carry a binary blob of unknown provenance:

  app/qml/sounds/keyclick.wav       a dry, single-shot key click in the
                                    spirit of the buckling-spring keyboards
                                    IBM shipped with the 3270/PC era
                                    terminals -- the factory keyboard tick
  app/qml/sounds/keyclick-deep.wav  the same thunk pitched down
  app/qml/sounds/keyclick-deeper.wav  and down again: the deeper picks
                                    offered beside it in Settings
  app/qml/sounds/bell.wav           the classic terminal attention beep

Usage:  python3 scripts/gen-sounds.py
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(os.path.dirname(HERE), "app", "qml", "sounds")


def write_wav(path, samples, sample_rate=SAMPLE_RATE):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(value * 32767))))
            for value in samples
        )
        handle.writeframes(frames)
    print("wrote %s (%.1f ms)" % (path, 1000.0 * len(samples) / sample_rate))


def key_click(duration=0.050, decay=110.0, pitch=1.0, noise_amp=0.10):
    """A short, low key thunk: the hammer hitting the keycap.

    The partials sit well below a typical tick so the click reads as a
    typewriter "tigh" rather than a chirp; three incommensurate tones keep
    a hint of metallic edge, and an envelope with a fast attack keeps it
    crisp rather than musical.  `pitch` drops the whole partial set (the
    deeper picks), each given a little more time and a softer hiss so the
    lower tones ring out instead of turning to mud.
    """
    samples = []
    partials = ((520.0 * pitch, 1.0), (970.0 * pitch, 0.55),
                 (1450.0 * pitch, 0.30))
    for index in range(int(SAMPLE_RATE * duration)):
        t = index / SAMPLE_RATE
        envelope = math.exp(-decay * t)
        # A touch of deterministic noise keeps each click from sounding
        # perfectly periodic without needing a random source.
        noise = math.sin(2.0 * math.pi * 6200.0 * t) * noise_amp
        value = sum(
            amplitude * math.sin(2.0 * math.pi * freq * t)
            for freq, amplitude in partials
        )
        samples.append(0.35 * envelope * (value * 0.6 + noise))
    return samples


def bell(duration=0.18, decay=13.0, frequencies=(1046.5, 2093.0)):
    """The attention beep: a bright partial with a second harmonic on top."""
    samples = []
    for index in range(int(SAMPLE_RATE * duration)):
        t = index / SAMPLE_RATE
        # Gentle attack so the beep does not click at the start.
        attack = min(1.0, t / 0.004)
        envelope = attack * math.exp(-decay * t)
        value = (
            0.72 * math.sin(2.0 * math.pi * frequencies[0] * t)
            + 0.28 * math.sin(2.0 * math.pi * frequencies[1] * t)
        )
        samples.append(0.30 * envelope * value)
    return samples


def main():
    # The factory tick: every argument at its default, so this stays the
    # very sample the application has always shipped.
    write_wav(os.path.join(OUT_DIR, "keyclick.wav"), key_click())
    # Two deeper picks for the keyboard tick sound choice.
    write_wav(os.path.join(OUT_DIR, "keyclick-deep.wav"),
              key_click(duration=0.060, decay=85.0, pitch=0.75,
                        noise_amp=0.09))
    write_wav(os.path.join(OUT_DIR, "keyclick-deeper.wav"),
              key_click(duration=0.070, decay=70.0, pitch=0.55,
                        noise_amp=0.08))
    write_wav(os.path.join(OUT_DIR, "bell.wav"), bell())


if __name__ == "__main__":
    main()
