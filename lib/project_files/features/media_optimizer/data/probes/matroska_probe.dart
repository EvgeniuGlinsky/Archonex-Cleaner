import 'dart:typed_data';

import 'package:archonex_cleaner/project_files/features/media_optimizer/data/probes/byte_source.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/video_codec.dart';

/// MKV and WebM, which are the same format with a different set of allowed
/// codecs.
///
/// EBML is a tree like ISO base media, and unlike it in the one way that makes
/// this a separate file: both the element identifier and the length are
/// *variable* width, with the width encoded in the leading bits of the first
/// byte. So there is no reading a field at an offset — every element has to be
/// walked to find the next one.
///
/// Only three things are wanted from it: how long the file is, how big the
/// video is, and what encoded it. Everything else in the tree is skipped by its
/// declared length, which is what keeps a parse of a four-gigabyte film down to
/// a few kilobytes of reads.
class MatroskaProbe {
  const MatroskaProbe._();

  static const List<int> _signature = <int>[0x1A, 0x45, 0xDF, 0xA3];

  static const int _segment = 0x18538067;
  static const int _info = 0x1549A966;
  static const int _timecodeScale = 0x2AD7B1;
  static const int _duration = 0x4489;
  static const int _tracks = 0x1654AE6B;
  static const int _trackEntry = 0xAE;
  static const int _trackType = 0x83;
  static const int _codecId = 0x86;
  static const int _video = 0xE0;
  static const int _pixelWidth = 0xB0;
  static const int _pixelHeight = 0xBA;
  static const int _defaultDuration = 0x23E383;

  /// How much of the file to walk looking for the header elements.
  ///
  /// Matroska writes `Info` and `Tracks` at the front, before the frames, so
  /// everything wanted is in the first few hundred kilobytes. Four megabytes is
  /// far more than enough and bounds the cost on a file whose header is
  /// malformed enough to keep the walk going.
  static const int _searchWindow = 4 * 1024 * 1024;

  static bool matches(Uint8List head) => head.startsWith(_signature);

  static Future<MediaProbe?> read(ByteSource source, Uint8List head) async {
    if (!matches(head)) {
      return null;
    }

    final int windowEnd =
        source.length < _searchWindow ? source.length : _searchWindow;
    final Uint8List bytes = await source.read(0, windowEnd);

    final MediaContainer container =
        _isWebm(bytes) ? MediaContainer.webm : MediaContainer.matroska;

    final _Element? segment = _findChild(bytes, _segment, 0, bytes.length);

    if (segment == null) {
      return MediaProbe(container: container, width: 0, height: 0);
    }

    final _Duration duration = _duration_(bytes, segment);
    final _Track? track = _track(bytes, segment);

    return MediaProbe(
      container: container,
      width: track?.width ?? 0,
      height: track?.height ?? 0,
      codec: track?.codec ?? VideoCodec.unknown,
      durationMs: duration.milliseconds,
      frameRate: track?.frameRate,
    );
  }

  /// WebM is Matroska with `webm` in its DocType.
  ///
  /// Read as a substring of the opening bytes rather than by walking to the
  /// element: the header is tiny, the string is distinctive, and the only thing
  /// riding on the answer is which extension the app would write back.
  static bool _isWebm(Uint8List bytes) {
    final int limit = bytes.length < 64 ? bytes.length : 64;

    for (int index = 0; index + 4 <= limit; index++) {
      if (bytes.fourCc(index) == 'webm') {
        return true;
      }
    }

    return false;
  }

  /// `Duration` is a float in timecode units, and `TimecodeScale` says how many
  /// nanoseconds one of those is.
  ///
  /// The scale is almost always a millisecond, and "almost always" is why it is
  /// read rather than assumed — a file written at microsecond precision would
  /// otherwise come out a thousand times too long and be judged as absurdly
  /// efficient.
  static _Duration _duration_(Uint8List bytes, _Element segment) {
    final _Element? info = _findChild(bytes, _info, segment.contentStart, segment.end);

    if (info == null) {
      return const _Duration(null);
    }

    final _Element? scale =
        _findChild(bytes, _timecodeScale, info.contentStart, info.end);
    final _Element? ticks =
        _findChild(bytes, _duration, info.contentStart, info.end);

    if (ticks == null) {
      return const _Duration(null);
    }

    final double? value = _readFloat(bytes, ticks);

    if (value == null || value <= 0) {
      return const _Duration(null);
    }

    // One millisecond, which is what nearly every muxer writes.
    final int nanosPerTick =
        scale == null ? 1000000 : _readUnsigned(bytes, scale);

    if (nanosPerTick <= 0) {
      return const _Duration(null);
    }

    return _Duration((value * nanosPerTick / 1000000).round());
  }

  /// The first `TrackEntry` whose `TrackType` is 1, which means video.
  static _Track? _track(Uint8List bytes, _Element segment) {
    final _Element? tracks =
        _findChild(bytes, _tracks, segment.contentStart, segment.end);

    if (tracks == null) {
      return null;
    }

    int offset = tracks.contentStart;

    while (offset < tracks.end) {
      final _Element? entry = _readElement(bytes, offset, tracks.end);

      if (entry == null) {
        return null;
      }

      if (entry.id == _trackEntry) {
        final _Element? type =
            _findChild(bytes, _trackType, entry.contentStart, entry.end);

        if (type != null && _readUnsigned(bytes, type) == 1) {
          return _videoTrack(bytes, entry);
        }
      }

      offset = entry.end;
    }

    return null;
  }

  static _Track? _videoTrack(Uint8List bytes, _Element entry) {
    final _Element? video =
        _findChild(bytes, _video, entry.contentStart, entry.end);

    if (video == null) {
      return null;
    }

    final _Element? width =
        _findChild(bytes, _pixelWidth, video.contentStart, video.end);
    final _Element? height =
        _findChild(bytes, _pixelHeight, video.contentStart, video.end);
    final _Element? codec =
        _findChild(bytes, _codecId, entry.contentStart, entry.end);
    final _Element? perFrame =
        _findChild(bytes, _defaultDuration, entry.contentStart, entry.end);

    // Nanoseconds per frame, where the muxer bothered to write it. Absent on a
    // variable-rate file, and the estimator refuses rather than assuming.
    final int nanos = perFrame == null ? 0 : _readUnsigned(bytes, perFrame);

    return _Track(
      width: width == null ? 0 : _readUnsigned(bytes, width),
      height: height == null ? 0 : _readUnsigned(bytes, height),
      codec: codec == null
          ? VideoCodec.unknown
          : VideoCodec.fromMatroskaCodecId(_readString(bytes, codec)),
      frameRate: nanos > 0 ? 1000000000 / nanos : null,
    );
  }

  // ---------------------------------------------------------------- ebml ----

  /// The first element with [id] among the direct children of a range.
  static _Element? _findChild(Uint8List bytes, int id, int start, int end) {
    int offset = start;

    while (offset < end) {
      final _Element? element = _readElement(bytes, offset, end);

      if (element == null) {
        return null;
      }

      if (element.id == id) {
        return element;
      }

      offset = element.end;
    }

    return null;
  }

  /// One element header.
  ///
  /// Both the identifier and the length are variable width, and the width is
  /// the number of leading zero bits in the first byte plus one. The identifier
  /// keeps its marker bit — that is what makes `0xAE` and `0x83` the constants
  /// above — and the length has it stripped.
  static _Element? _readElement(Uint8List bytes, int offset, int end) {
    if (offset >= end || offset >= bytes.length) {
      return null;
    }

    final int idWidth = _widthOf(bytes.u8(offset));

    if (idWidth == 0 || offset + idWidth > end) {
      return null;
    }

    int id = 0;

    for (int index = 0; index < idWidth; index++) {
      id = (id << 8) | bytes.u8(offset + index);
    }

    final int lengthOffset = offset + idWidth;

    if (lengthOffset >= end) {
      return null;
    }

    final int lengthWidth = _widthOf(bytes.u8(lengthOffset));

    if (lengthWidth == 0 || lengthOffset + lengthWidth > end) {
      return null;
    }

    // The marker bit belongs to the encoding, not the number.
    int size = bytes.u8(lengthOffset) & (0xFF >> lengthWidth);

    for (int index = 1; index < lengthWidth; index++) {
      size = (size << 8) | bytes.u8(lengthOffset + index);
    }

    final int contentStart = lengthOffset + lengthWidth;

    // An all-ones length means "unknown", which only `Segment` is allowed to
    // use and means it runs to the end of the file.
    final bool isUnknown = size == (1 << (7 * lengthWidth)) - 1;
    final int contentEnd = isUnknown ? end : contentStart + size;

    if (contentEnd > end || contentEnd < contentStart) {
      return null;
    }

    return _Element(id: id, contentStart: contentStart, end: contentEnd);
  }

  /// Bytes this value occupies, from the leading bit of its first byte.
  static int _widthOf(int first) {
    for (int width = 1; width <= 8; width++) {
      if (first & (0x80 >> (width - 1)) != 0) {
        return width;
      }
    }

    return 0;
  }

  static int _readUnsigned(Uint8List bytes, _Element element) {
    int value = 0;

    for (int index = element.contentStart; index < element.end; index++) {
      value = (value << 8) | bytes.u8(index);
    }

    return value;
  }

  /// A four- or eight-byte IEEE float, which is how `Duration` is stored.
  static double? _readFloat(Uint8List bytes, _Element element) {
    final int size = element.end - element.contentStart;
    final ByteData view = ByteData.sublistView(
      bytes,
      element.contentStart,
      element.end,
    );

    return switch (size) {
      4 => view.getFloat32(0),
      8 => view.getFloat64(0),
      _ => null,
    };
  }

  static String _readString(Uint8List bytes, _Element element) {
    final StringBuffer buffer = StringBuffer();

    for (int index = element.contentStart; index < element.end; index++) {
      final int byte = bytes.u8(index);

      if (byte == 0) {
        break;
      }

      buffer.writeCharCode(byte);
    }

    return buffer.toString();
  }
}

class _Element {
  const _Element({required this.id, required this.contentStart, required this.end});

  final int id;
  final int contentStart;
  final int end;
}

class _Duration {
  const _Duration(this.milliseconds);

  final int? milliseconds;
}

class _Track {
  const _Track({
    required this.width,
    required this.height,
    required this.codec,
    required this.frameRate,
  });

  final int width;
  final int height;
  final VideoCodec codec;
  final double? frameRate;
}
