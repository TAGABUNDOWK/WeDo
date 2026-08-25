import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  const sampleRate = 44100;
  const durationSec = 4.0;
  final totalSamples = (sampleRate * durationSec).toInt();

  final samples = Int16List(totalSamples);

  // Classic phone ring: dual-tone (440Hz + 480Hz) with proper cadence
  // Ring pattern: 2s on, 4s off (standard North American cadence)
  // Within the "on" period: alternating ring-pause-ring
  const ringOn = 1.0;
  const ringPause = 0.4;
  const cyclePause = 0.8;

  for (int i = 0; i < totalSamples; i++) {
    final t = i / sampleRate;
    final cycleDuration = ringOn + ringPause + ringOn + cyclePause;
    final cyclePos = t % cycleDuration;

    double amplitude = 0;

    // First ring burst
    if (cyclePos < ringOn) {
      amplitude = 1.0;
    }
    // Short pause
    else if (cyclePos < ringOn + ringPause) {
      amplitude = 0.0;
    }
    // Second ring burst
    else if (cyclePos < ringOn * 2 + ringPause) {
      amplitude = 1.0;
    }
    // Longer pause before next cycle
    else {
      amplitude = 0.0;
    }

    // Apply smooth envelope (attack 10ms, release 20ms)
    if (amplitude > 0) {
      final burstStart = cyclePos < ringOn ? 0.0 : ringOn + ringPause;
      final posInBurst = cyclePos - burstStart;
      final attack = 0.010;
      final release = 0.020;
      if (posInBurst < attack) {
        amplitude *= posInBurst / attack;
      } else if (posInBurst > ringOn - release) {
        amplitude *= (ringOn - posInBurst) / release;
      }
    }

    // Classic dual-tone: 440Hz + 480Hz (US phone standard)
    final sig = 0.5 * sin(2 * pi * 440 * t) + 0.5 * sin(2 * pi * 480 * t);
    samples[i] = (sig * amplitude * 32767 * 0.8).round().clamp(-32767, 32767);
  }

  // Write WAV file
  final wav = _buildWav(samples, sampleRate);
  final outPath = 'assets/audio/ringtone.wav';
  File(outPath).writeAsBytesSync(wav);
  print('Generated $outPath (${wav.length} bytes)');
}

Uint8List _buildWav(Int16List samples, int sampleRate) {
  final numChannels = 1;
  final bitsPerSample = 16;
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final dataSize = samples.lengthInBytes;
  final fileSize = 36 + dataSize;

  final buf = ByteData(44 + dataSize);
  int offset = 0;

  // RIFF header
  buf.setUint8(offset++, 0x52); // R
  buf.setUint8(offset++, 0x49); // I
  buf.setUint8(offset++, 0x46); // F
  buf.setUint8(offset++, 0x46); // F
  buf.setUint32(offset, fileSize, Endian.little); offset += 4;
  buf.setUint8(offset++, 0x57); // W
  buf.setUint8(offset++, 0x41); // A
  buf.setUint8(offset++, 0x56); // V
  buf.setUint8(offset++, 0x45); // E

  // fmt chunk
  buf.setUint8(offset++, 0x66); // f
  buf.setUint8(offset++, 0x6D); // m
  buf.setUint8(offset++, 0x74); // t
  buf.setUint8(offset++, 0x20); // (space)
  buf.setUint32(offset, 16, Endian.little); offset += 4;
  buf.setUint16(offset, 1, Endian.little); offset += 2;
  buf.setUint16(offset, numChannels, Endian.little); offset += 2;
  buf.setUint32(offset, sampleRate, Endian.little); offset += 4;
  buf.setUint32(offset, byteRate, Endian.little); offset += 4;
  buf.setUint16(offset, blockAlign, Endian.little); offset += 2;
  buf.setUint16(offset, bitsPerSample, Endian.little); offset += 2;

  // data chunk
  buf.setUint8(offset++, 0x64); // d
  buf.setUint8(offset++, 0x61); // a
  buf.setUint8(offset++, 0x74); // t
  buf.setUint8(offset++, 0x61); // a
  buf.setUint32(offset, dataSize, Endian.little); offset += 4;

  for (int i = 0; i < samples.length; i++) {
    buf.setInt16(offset, samples[i], Endian.little);
    offset += 2;
  }

  return Uint8List.view(buf.buffer);
}
