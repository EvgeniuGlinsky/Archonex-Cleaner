import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:archonex_cleaner/project_files/features/media_optimizer/data/probes/byte_source.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/probes/media_probe_reader.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/video_codec.dart';

import 'fixtures.dart';

/// The header parsers, against files built byte by byte in `fixtures.dart`.
///
/// Built rather than checked in. A binary fixture is one nobody can review, and
/// the whole risk in a header parser is an offset being wrong in a way that
/// still produces a plausible number — so the fixture that proves the parser
/// right has to be readable beside it.
void main() {
  const MediaProbeReader reader = MediaProbeReader();

  Future<MediaProbe?> probe(Uint8List bytes, {int? length}) =>
      reader.read(BytesSource(bytes, length: length));

  group('still images', () {
    test('a JPEG whose dimensions sit past an EXIF block', () async {
      // The case a fixed-offset parser gets wrong. Everything a camera writes
      // before the frame — EXIF, a colour profile, an embedded thumbnail — is a
      // variable-length segment, so the chain has to be walked.
      final MediaProbe? result = await probe(
        jpegBytes(width: 4032, height: 3024, exifBytes: 12000),
      );

      expect(result?.container, MediaContainer.jpeg);
      expect(result?.width, 4032);
      expect(result?.height, 3024);
    });

    test('and the height is not read as the width', () async {
      // The one field order in the format that reads backwards. Getting it the
      // wrong way round produces a plausible number rather than an error, so a
      // non-square fixture is the only thing that catches it.
      final MediaProbe? result = await probe(jpegBytes(width: 1920, height: 1080));

      expect(result?.width, 1920);
      expect(result?.height, 1080);
    });

    test('a progressive JPEG, whose frame marker is a different one', () async {
      final MediaProbe? result = await probe(
        jpegBytes(width: 800, height: 600, startOfFrameMarker: 0xC2),
      );

      expect(result?.width, 800);
    });

    test('a Huffman table is not mistaken for a frame', () async {
      // 0xC4 sits inside the start-of-frame range and is not one, which is why
      // the check is not a range check.
      final MediaProbe? result = await probe(
        jpegBytes(width: 640, height: 480, withHuffmanTable: true),
      );

      expect(result?.width, 640);
      expect(result?.height, 480);
    });

    test('a PNG', () async {
      final MediaProbe? result = await probe(pngBytes(width: 1170, height: 2532));

      expect(result?.container, MediaContainer.png);
      expect(result?.width, 1170);
      expect(result?.height, 2532);
    });

    test('a GIF, which is little-endian where PNG is not', () async {
      final MediaProbe? result = await probe(gifBytes(width: 500, height: 300));

      expect(result?.container, MediaContainer.gif);
      expect(result?.width, 500);
      expect(result?.height, 300);
    });

    test('a BMP stored top-down, whose height is negative', () async {
      final MediaProbe? result = await probe(bmpBytes(width: 320, height: -240));

      expect(result?.container, MediaContainer.bmp);
      expect(result?.width, 320);
      expect(result?.height, 240);
    });

    test('a TIFF, in both byte orders', () async {
      for (final bool little in <bool>[true, false]) {
        final MediaProbe? result =
            await probe(tiffBytes(width: 2000, height: 1500, little: little));

        expect(result?.container, MediaContainer.tiff, reason: 'little=$little');
        expect(result?.width, 2000, reason: 'little=$little');
        expect(result?.height, 1500, reason: 'little=$little');
      }
    });

    test('a TIFF that stored its dimensions as longs rather than shorts',
        () async {
      final MediaProbe? result =
          await probe(tiffBytes(width: 2000, height: 1500, asLong: true));

      expect(result?.width, 2000);
      expect(result?.height, 1500);
    });
  });

  group('ISO base media', () {
    test('an H.264 MP4 with the moov box at the end', () async {
      // The reason the parsers take a `ByteSource` instead of a head buffer.
      // A phone writes moov last, after gigabytes of frames, so a parser that
      // only saw the front would find nothing on exactly the files that matter.
      final Uint8List bytes = mp4Bytes(
        width: 1920,
        height: 1080,
        codec: 'avc1',
        durationSeconds: 300,
        frameRate: 30,
        moovAtEnd: true,
      );

      final MediaProbe? result = await probe(bytes);

      expect(result?.container, MediaContainer.mp4);
      expect(result?.codec, VideoCodec.h264);
      expect(result?.width, 1920);
      expect(result?.height, 1080);
      expect(result?.durationMs, 300000);
      expect(result?.frameRate, closeTo(30, 0.01));
      expect(result?.isComplete, isTrue);
    });

    test('an HEVC MP4 is recognised as HEVC and not as H.264', () async {
      final MediaProbe? result = await probe(
        mp4Bytes(
          width: 3840,
          height: 2160,
          codec: 'hvc1',
          durationSeconds: 60,
          frameRate: 60,
        ),
      );

      expect(result?.codec, VideoCodec.hevc);
      expect(result?.frameRate, closeTo(60, 0.01));
    });

    test('the audio track is not read as the video track', () async {
      // A file whose audio comes first is ordinary, and reading its sample
      // entry would report an audio codec and no dimensions — silently.
      final MediaProbe? result = await probe(
        mp4Bytes(
          width: 1280,
          height: 720,
          codec: 'avc1',
          durationSeconds: 30,
          frameRate: 25,
          audioTrackFirst: true,
        ),
      );

      expect(result?.width, 1280);
      expect(result?.codec, VideoCodec.h264);
    });

    test('a 64-bit box size, which every file over 4 GB uses', () async {
      final MediaProbe? result = await probe(
        mp4Bytes(
          width: 1920,
          height: 1080,
          codec: 'avc1',
          durationSeconds: 120,
          frameRate: 30,
          largeBoxSize: true,
        ),
      );

      expect(result?.width, 1920);
      expect(result?.durationMs, 120000);
    });

    test('a variable-rate table is averaged over its own span', () async {
      // The regression the probe found on a real machine. Reading part of a
      // long `stts` and dividing by the *track's* duration counts a fraction of
      // the frames against all of the seconds: a two-hour film came out at 0.96
      // frames a second, looked twenty-five times more wasteful than it was,
      // and the app offered to free twelve gigabytes it could not.
      final MediaProbe? result = await probe(
        mp4Bytes(
          width: 1920,
          height: 816,
          codec: 'avc1',
          durationSeconds: 7200,
          frameRate: 24,
          // Far more rows than the parser will read, which is the whole point.
          sttsEntries: 20000,
        ),
      );

      expect(result?.frameRate, closeTo(24, 0.5));
      expect(result?.durationMs, 7200000);
    });

    test('a QuickTime brand is still parsed, and named as one', () async {
      final MediaProbe? result = await probe(
        mp4Bytes(
          width: 1920,
          height: 1080,
          codec: 'avc1',
          durationSeconds: 10,
          frameRate: 30,
          brand: 'qt  ',
        ),
      );

      expect(result?.container, MediaContainer.quickTime);
      expect(result?.codec, VideoCodec.h264);
    });

    test('a HEIC photograph gives up its dimensions from ispe', () async {
      // Always left alone by the estimator, and parsed anyway: "3024 × 4032,
      // already efficient" is an answer where "unreadable" is an admission.
      final MediaProbe? result = await probe(heicBytes(width: 4032, height: 3024));

      expect(result?.container, MediaContainer.heif);
      expect(result?.width, 4032);
      expect(result?.height, 3024);
    });

    test('a video with no moov box is recognised but incomplete', () async {
      // Distinct from "not a video". The screen says the two differently.
      final MediaProbe? result = await probe(ftypOnlyBytes());

      expect(result, isNotNull);
      expect(result?.container, MediaContainer.mp4);
      expect(result?.isComplete, isFalse);
    });
  });

  group('matroska', () {
    test('an MKV, with its variable-width element headers', () async {
      final MediaProbe? result = await probe(
        mkvBytes(
          width: 1920,
          height: 1080,
          codecId: 'V_MPEG4/ISO/AVC',
          durationSeconds: 600,
          frameRate: 24,
        ),
      );

      expect(result?.container, MediaContainer.matroska);
      expect(result?.codec, VideoCodec.h264);
      expect(result?.width, 1920);
      expect(result?.height, 1080);
      expect(result?.durationMs, 600000);
      expect(result?.frameRate, closeTo(24, 0.01));
    });

    test('HEVC in Matroska is not mistaken for MPEG-4 part 2', () async {
      // Both codec strings begin `V_MPEG`, so the order the tail is matched in
      // is what keeps a modern file from being read as a fifteen-year-old one
      // and re-encoded for nothing.
      final MediaProbe? result = await probe(
        mkvBytes(
          width: 1920,
          height: 1080,
          codecId: 'V_MPEGH/ISO/HEVC',
          durationSeconds: 60,
          frameRate: 30,
        ),
      );

      expect(result?.codec, VideoCodec.hevc);
    });

    test('a WebM is named as one', () async {
      final MediaProbe? result = await probe(
        mkvBytes(
          width: 854,
          height: 480,
          codecId: 'V_VP9',
          durationSeconds: 30,
          frameRate: 30,
          docType: 'webm',
        ),
      );

      expect(result?.container, MediaContainer.webm);
      expect(result?.codec, VideoCodec.vp9);
    });

    test('a non-millisecond timecode scale is honoured', () async {
      // Assuming milliseconds would make a microsecond-scaled file read as a
      // thousand times longer, and therefore as absurdly efficient.
      final MediaProbe? result = await probe(
        mkvBytes(
          width: 1920,
          height: 1080,
          codecId: 'V_MPEG4/ISO/AVC',
          durationSeconds: 100,
          frameRate: 30,
          timecodeScaleNanos: 1000,
        ),
      );

      expect(result?.durationMs, 100000);
    });

    test('a variable-rate file with no DefaultDuration is left incomplete',
        () async {
      // The estimator refuses rather than assuming thirty: a wrong frame rate
      // moves the judgement by exactly its own factor.
      final MediaProbe? result = await probe(
        mkvBytes(
          width: 1920,
          height: 1080,
          codecId: 'V_MPEG4/ISO/AVC',
          durationSeconds: 100,
          frameRate: null,
        ),
      );

      expect(result?.frameRate, isNull);
      expect(result?.isComplete, isFalse);
    });
  });

  group('riff', () {
    test('a DivX AVI, little-endian throughout', () async {
      final MediaProbe? result = await probe(
        aviBytes(
          width: 720,
          height: 576,
          fourCc: 'DX50',
          frames: 135000,
          microsPerFrame: 40000,
        ),
      );

      expect(result?.container, MediaContainer.avi);
      expect(result?.codec, VideoCodec.mpeg4Part2);
      expect(result?.width, 720);
      expect(result?.height, 576);
      expect(result?.durationMs, 5400000);
      expect(result?.frameRate, closeTo(25, 0.01));
    });

    test('the audio stream header is not read as the video one', () async {
      final MediaProbe? result = await probe(
        aviBytes(
          width: 640,
          height: 480,
          fourCc: 'xvid',
          frames: 1000,
          microsPerFrame: 40000,
          audioStreamFirst: true,
        ),
      );

      expect(result?.codec, VideoCodec.mpeg4Part2);
    });

    test('a lossy WebP', () async {
      final MediaProbe? result = await probe(webpBytes(width: 1200, height: 800));

      expect(result?.container, MediaContainer.webp);
      expect(result?.width, 1200);
      expect(result?.height, 800);
    });

    test('an extended WebP, whose dimensions are stored one less', () async {
      final MediaProbe? result =
          await probe(webpBytes(width: 4000, height: 3000, extended: true));

      expect(result?.width, 4000);
      expect(result?.height, 3000);
    });
  });

  group('what the reader refuses', () {
    test('a file whose extension lied about its container', () async {
      // The whole reason the dispatch is on magic bytes. Called through a
      // `.mp4` name, this is still a Matroska file and is parsed as one.
      final MediaProbe? result = await probe(
        mkvBytes(
          width: 1920,
          height: 1080,
          codecId: 'V_MPEG4/ISO/AVC',
          durationSeconds: 60,
          frameRate: 30,
        ),
      );

      expect(result?.container, MediaContainer.matroska);
    });

    test('a text file that happens to be in a Pictures folder', () async {
      expect(
        await probe(Uint8List.fromList('not media at all, just some text'.codeUnits)),
        isNull,
      );
    });

    test('a file too short to hold any signature', () async {
      expect(await probe(Uint8List.fromList(<int>[0xFF, 0xD8])), isNull);
    });

    test('a truncated download does not throw', () async {
      // Half a video is a normal thing to find in a Downloads folder.
      final Uint8List whole = mp4Bytes(
        width: 1920,
        height: 1080,
        codec: 'avc1',
        durationSeconds: 300,
        frameRate: 30,
        moovAtEnd: true,
      );

      final MediaProbe? result =
          await probe(Uint8List.sublistView(whole, 0, whole.length ~/ 3));

      expect(result?.isComplete ?? false, isFalse);
    });

    test('a box claiming a size of zero ends the walk instead of looping',
        () async {
      expect(
        () => probe(mp4WithZeroSizedBox()),
        returnsNormally,
      );
      expect((await probe(mp4WithZeroSizedBox()))?.isComplete, isFalse);
    });

    test('a box claiming a size past the end of the file is refused', () async {
      expect((await probe(mp4WithOversizedBox()))?.isComplete, isFalse);
    });
  });
}
