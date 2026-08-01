import 'dart:typed_data';

import 'package:archonex_cleaner/project_files/features/media_optimizer/data/probes/byte_source.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/video_codec.dart';

/// AVI and WebP, which have nothing in common except the box they arrive in.
///
/// RIFF is a chunk format from the same era and idea as ISO base media, and
/// little-endian throughout because it came from the PC rather than the
/// network. Two formats here still use it: camcorder AVI files, which are the
/// largest single win this tool ever finds, and WebP, which it deliberately
/// leaves alone.
class RiffProbe {
  const RiffProbe._();

  /// The AVI header sits at the front, so this bounds how far to look for it.
  static const int _searchWindow = 256 * 1024;

  static bool matches(Uint8List head) => head.fourCc(0) == 'RIFF';

  static Future<MediaProbe?> read(ByteSource source, Uint8List head) async {
    if (!matches(head)) {
      return null;
    }

    return switch (head.fourCc(8)) {
      'AVI ' => _avi(source),
      'WEBP' => _webp(head),
      _ => null,
    };
  }

  // ----------------------------------------------------------------- avi ----

  /// `avih` for the shape of the file, `strh` for what encoded it.
  ///
  /// The main header is the only place AVI states its frame rate, and it states
  /// it as microseconds per frame rather than frames per second — which is the
  /// more honest unit and the one that makes 29.97 exact.
  static Future<MediaProbe?> _avi(ByteSource source) async {
    final int windowEnd =
        source.length < _searchWindow ? source.length : _searchWindow;
    final Uint8List bytes = await source.read(0, windowEnd);

    final _Chunk? avih = _find(bytes, 'avih', 12, bytes.length);

    if (avih == null) {
      return const MediaProbe(container: MediaContainer.avi, width: 0, height: 0);
    }

    final int microsPerFrame = bytes.u32le(avih.contentStart);
    final int totalFrames = bytes.u32le(avih.contentStart + 16);
    final int width = bytes.u32le(avih.contentStart + 32);
    final int height = bytes.u32le(avih.contentStart + 36);

    return MediaProbe(
      container: MediaContainer.avi,
      width: width,
      height: height,
      codec: _codec(bytes),
      durationMs: microsPerFrame > 0 && totalFrames > 0
          ? totalFrames * microsPerFrame ~/ 1000
          : null,
      frameRate: microsPerFrame > 0 ? 1000000 / microsPerFrame : null,
    );
  }

  /// The handler of the first stream whose type is `vids`.
  ///
  /// Checked rather than assumed, because an AVI's audio stream header has the
  /// same shape and reading its handler would report a codec that is not the
  /// video's — silently, and with a plausible-looking four letters.
  static VideoCodec _codec(Uint8List bytes) {
    int offset = 12;

    while (offset < bytes.length) {
      final _Chunk? chunk = _readChunk(bytes, offset, bytes.length);

      if (chunk == null) {
        return VideoCodec.unknown;
      }

      if (chunk.id == 'strh') {
        if (bytes.fourCc(chunk.contentStart) == 'vids') {
          return VideoCodec.fromFourCc(bytes.fourCc(chunk.contentStart + 4));
        }
      } else if (chunk.isList) {
        // Descend: `strh` lives inside `LIST hdrl` inside `LIST strl`.
        offset = chunk.contentStart + 4;

        continue;
      }

      offset = chunk.end;
    }

    return VideoCodec.unknown;
  }

  // ---------------------------------------------------------------- webp ----

  /// WebP in its three flavours, all of which pack the dimensions into bit
  /// fields rather than whole bytes.
  ///
  /// Parsed only so the screen can say what it is leaving alone and how big it
  /// is. The estimator answers `unsupportedFormat` for every WebP — it is
  /// already the efficient answer for a photograph.
  static MediaProbe? _webp(Uint8List head) {
    return switch (head.fourCc(12)) {
      // Extended: the canvas size as two 24-bit values, each stored one less
      // than it is.
      'VP8X' => MediaProbe(
          container: MediaContainer.webp,
          width: _u24le(head, 24) + 1,
          height: _u24le(head, 27) + 1,
        ),
      // Lossy: fourteen bits each, after a three-byte start code.
      'VP8 ' => MediaProbe(
          container: MediaContainer.webp,
          width: head.u16le(26) & 0x3FFF,
          height: head.u16le(28) & 0x3FFF,
        ),
      // Lossless: fourteen bits each, packed across a four-byte field.
      'VP8L' => _lossless(head),
      _ => null,
    };
  }

  static MediaProbe _lossless(Uint8List head) {
    final int packed = head.u32le(21);

    return MediaProbe(
      container: MediaContainer.webp,
      width: (packed & 0x3FFF) + 1,
      height: ((packed >> 14) & 0x3FFF) + 1,
    );
  }

  static int _u24le(Uint8List bytes, int offset) =>
      bytes.u8(offset) | (bytes.u8(offset + 1) << 8) | (bytes.u8(offset + 2) << 16);

  // ---------------------------------------------------------------- walk ----

  static _Chunk? _find(Uint8List bytes, String id, int start, int end) {
    int offset = start;

    while (offset < end) {
      final _Chunk? chunk = _readChunk(bytes, offset, end);

      if (chunk == null) {
        return null;
      }

      if (chunk.id == id) {
        return chunk;
      }

      // A list holds chunks rather than data, and the wanted one is inside it.
      offset = chunk.isList ? chunk.contentStart + 4 : chunk.end;
    }

    return null;
  }

  static _Chunk? _readChunk(Uint8List bytes, int offset, int end) {
    if (offset + 8 > end) {
      return null;
    }

    final String id = bytes.fourCc(offset);
    final int size = bytes.u32le(offset + 4);

    if (size < 0) {
      return null;
    }

    // Chunks are word-aligned: an odd-sized one is followed by a pad byte that
    // is not counted in its length.
    final int padded = size.isOdd ? size + 1 : size;
    final int chunkEnd = offset + 8 + padded;

    if (chunkEnd > end || chunkEnd <= offset) {
      return null;
    }

    return _Chunk(
      id: id,
      isList: id == 'LIST' || id == 'RIFF',
      contentStart: offset + 8,
      end: chunkEnd,
    );
  }
}

class _Chunk {
  const _Chunk({
    required this.id,
    required this.isList,
    required this.contentStart,
    required this.end,
  });

  final String id;
  final bool isList;
  final int contentStart;
  final int end;
}
