import 'dart:typed_data';

import 'package:storage_cleaner/project_files/features/media_optimizer/data/probes/byte_source.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/video_codec.dart';

/// MP4, M4V, MOV and HEIC, which are all the same file format.
///
/// ISO base media is a tree of boxes — four bytes of size, four of type, then
/// either a payload or more boxes — and everything from an iPhone video to an
/// iPhone photograph is one. That is why they share a parser: telling them
/// apart is a matter of reading the brand in the first box and then looking for
/// a different branch of the same tree.
///
/// It reads pieces rather than the file, and that is the reason `ByteSource`
/// exists. A video's `moov` box holds every index the player needs and is
/// routinely written *last*, after gigabytes of frames, so a parser that only
/// saw the first kilobyte would find nothing on exactly the files this app
/// cares about most.
///
/// Everything is bounded. Box sizes come out of the file, so a corrupt one
/// points anywhere; each walk carries an end offset and a depth, and a box
/// claiming a size of zero ends the walk rather than looping on itself.
class IsoBmffProbe {
  const IsoBmffProbe._();

  /// How many boxes deep the walk will go before giving up.
  ///
  /// The deepest thing wanted here is `moov/trak/mdia/minf/stbl/stsd`, which is
  /// six. Ten leaves room and still ends a file that has been crafted to
  /// nest for ever.
  static const int _maxDepth = 10;

  /// Whether these opening bytes are an ISO base media file at all.
  static bool matches(Uint8List head) => head.fourCc(4) == 'ftyp';

  /// The brand, which says whether this is a video or a still.
  ///
  /// `heic`, `heix`, `mif1` and friends are photographs; everything else here
  /// is a video. QuickTime is told apart by `qt  `, and it matters only because
  /// the extension the app would write back differs.
  static MediaContainer containerFor(Uint8List head) {
    final String brand = head.fourCc(8).toLowerCase();

    if (brand.startsWith('hei') || brand.startsWith('mif') || brand == 'msf1') {
      return MediaContainer.heif;
    }

    if (brand.startsWith('qt')) {
      return MediaContainer.quickTime;
    }

    return MediaContainer.mp4;
  }

  /// Reads what the header will give up.
  ///
  /// `null` when the file is not ISO base media at all. A file that *is* but
  /// whose `moov` is missing or unreadable comes back with zeroed fields, which
  /// `MediaProbe.isComplete` rejects and the estimator reports as unreadable —
  /// a different outcome from "not a video", and the screen says so differently.
  static Future<MediaProbe?> read(ByteSource source, Uint8List head) async {
    if (!matches(head)) {
      return null;
    }

    final MediaContainer container = containerFor(head);

    if (container == MediaContainer.heif) {
      return _still(source, container);
    }

    return _video(source, container);
  }

  // --------------------------------------------------------------- video ----

  static Future<MediaProbe?> _video(
    ByteSource source,
    MediaContainer container,
  ) async {
    final _Box? moov = await _find(source, 'moov', 0, source.length);

    if (moov == null) {
      return MediaProbe(container: container, width: 0, height: 0);
    }

    final _MovieHeader header = await _movieHeader(source, moov);
    final _VideoTrack? track = await _videoTrack(source, moov);

    return MediaProbe(
      container: container,
      width: track?.width ?? 0,
      height: track?.height ?? 0,
      codec: track?.codec ?? VideoCodec.unknown,
      durationMs: header.durationMs,
      frameRate: track?.frameRate,
    );
  }

  /// `mvhd` — the whole file's length, in its own units.
  ///
  /// Version 1 widened the timestamps and the duration to 64 bits, which moves
  /// every field after them. A file long enough to need it is rare and a parser
  /// that assumed version 0 would read the duration out of the middle of a
  /// timestamp, so both are handled.
  static Future<_MovieHeader> _movieHeader(ByteSource source, _Box moov) async {
    final _Box? mvhd = await _find(source, 'mvhd', moov.contentStart, moov.end);

    if (mvhd == null) {
      return const _MovieHeader(durationMs: null);
    }

    final Uint8List bytes = await source.read(mvhd.contentStart, 32);
    final int version = bytes.u8(0);

    final int timescale = version == 1 ? bytes.u32(20) : bytes.u32(12);
    final int duration = version == 1 ? bytes.u64(24) : bytes.u32(16);

    if (timescale <= 0 || duration <= 0) {
      return const _MovieHeader(durationMs: null);
    }

    return _MovieHeader(durationMs: duration * 1000 ~/ timescale);
  }

  /// The first track whose handler says `vide`.
  ///
  /// The handler is checked rather than the track order, because a file whose
  /// audio track comes first is ordinary and reading its sample entry would
  /// report an audio codec and no dimensions.
  static Future<_VideoTrack?> _videoTrack(ByteSource source, _Box moov) async {
    int offset = moov.contentStart;

    while (offset < moov.end) {
      final _Box? trak = await _readBox(source, offset, moov.end);

      if (trak == null) {
        return null;
      }

      if (trak.type == 'trak') {
        final _VideoTrack? track = await _trackIfVideo(source, trak);

        if (track != null) {
          return track;
        }
      }

      offset = trak.end;
    }

    return null;
  }

  static Future<_VideoTrack?> _trackIfVideo(ByteSource source, _Box trak) async {
    final _Box? mdia = await _find(source, 'mdia', trak.contentStart, trak.end);

    if (mdia == null) {
      return null;
    }

    final _Box? hdlr = await _find(source, 'hdlr', mdia.contentStart, mdia.end);

    if (hdlr == null) {
      return null;
    }

    // Full box: version and flags, then a reserved word, then the handler.
    final Uint8List handlerBytes = await source.read(hdlr.contentStart, 12);

    if (handlerBytes.fourCc(8) != 'vide') {
      return null;
    }

    final _Box? minf = await _find(source, 'minf', mdia.contentStart, mdia.end);
    final _Box? stbl = minf == null
        ? null
        : await _find(source, 'stbl', minf.contentStart, minf.end);

    if (stbl == null) {
      return null;
    }

    final _SampleEntry? entry = await _sampleEntry(source, stbl);

    if (entry == null) {
      return null;
    }

    return _VideoTrack(
      width: entry.width,
      height: entry.height,
      codec: entry.codec,
      frameRate: await _frameRate(source, mdia, stbl),
    );
  }

  /// `stsd` — the codec and the coded dimensions, both at fixed offsets inside
  /// the first sample entry.
  ///
  /// The visual sample entry's layout has not changed since the format was
  /// written: an eight-byte box header, six reserved bytes and a data reference
  /// index, then four pre-defined and reserved fields totalling sixteen — and
  /// the dimensions at thirty-two.
  static Future<_SampleEntry?> _sampleEntry(ByteSource source, _Box stbl) async {
    final _Box? stsd = await _find(source, 'stsd', stbl.contentStart, stbl.end);

    if (stsd == null) {
      return null;
    }

    // Version and flags, then the entry count, then the first entry.
    final Uint8List bytes = await source.read(stsd.contentStart + 8, 40);

    if (bytes.length < 36) {
      return null;
    }

    return _SampleEntry(
      codec: VideoCodec.fromFourCc(bytes.fourCc(4)),
      width: bytes.u16(32),
      height: bytes.u16(34),
    );
  }

  /// Frames per second, derived rather than stored.
  ///
  /// The format has no field for it. What it has is `stts`, a run-length table
  /// pairing a sample count with the ticks each of those samples lasts, and
  /// `mdhd`, which says how long a tick is.
  ///
  /// The rate is worked out **from the table's own span**, not from the track
  /// duration, and that is the whole point of the arithmetic below. A film with
  /// a variable frame rate has tens of thousands of entries; reading all of
  /// them is a megabyte per file, and reading some of them and dividing by the
  /// *track's* duration counts a fraction of the frames against all of the
  /// seconds. That was a real bug and it was silent: a two-hour film read as
  /// 0.96 frames a second, which made it look twenty-five times more wasteful
  /// than it is, and the app offered to free twelve gigabytes it could not.
  ///
  /// Dividing the samples read by the time those same samples cover is exact
  /// for a constant-rate file and a correct local average for the rest.
  ///
  /// `null` where the table or the header is missing, and the estimator refuses
  /// the file rather than assuming thirty: a wrong frame rate moves the
  /// judgement by exactly its own factor.
  static Future<double?> _frameRate(
    ByteSource source,
    _Box mdia,
    _Box stbl,
  ) async {
    final _Box? mdhd = await _find(source, 'mdhd', mdia.contentStart, mdia.end);
    final _Box? stts = await _find(source, 'stts', stbl.contentStart, stbl.end);

    if (mdhd == null || stts == null) {
      return null;
    }

    final Uint8List header = await source.read(mdhd.contentStart, 32);
    final int version = header.u8(0);
    final int timescale = version == 1 ? header.u32(20) : header.u32(12);

    if (timescale <= 0) {
      return null;
    }

    final Uint8List table = await source.read(stts.contentStart, 8);
    final int entryCount = table.u32(4);

    if (entryCount <= 0) {
      return null;
    }

    // Bounded, because the count comes out of the file and a corrupt one would
    // ask for gigabytes. Truncating is safe here in a way it was not before:
    // the answer is an average over whatever was read.
    const int maxEntries = 8192;
    final int readCount = entryCount > maxEntries ? maxEntries : entryCount;
    final Uint8List entries =
        await source.read(stts.contentStart + 8, readCount * 8);

    int samples = 0;
    int ticks = 0;

    for (int index = 0; index < readCount; index++) {
      final int count = entries.u32(index * 8);
      final int delta = entries.u32(index * 8 + 4);

      samples += count;
      ticks += count * delta;
    }

    if (samples <= 0 || ticks <= 0) {
      return null;
    }

    return samples / (ticks / timescale);
  }

  // --------------------------------------------------------------- stills ---

  /// HEIC and its relatives: the dimensions live in `ispe`, five boxes down.
  ///
  /// Parsed even though the estimator always answers `unsupportedFormat` for
  /// these, because the screen shows the resolution of a file it is leaving
  /// alone and "3024 × 4032, already efficient" is an answer where "unreadable"
  /// is an admission.
  static Future<MediaProbe?> _still(
    ByteSource source,
    MediaContainer container,
  ) async {
    final _Box? meta = await _find(source, 'meta', 0, source.length);

    if (meta == null) {
      return MediaProbe(container: container, width: 0, height: 0);
    }

    // `meta` is a full box, so its children start four bytes in, past the
    // version and flags. Every other container box here is not.
    final _Box? iprp =
        await _find(source, 'iprp', meta.contentStart + 4, meta.end);
    final _Box? ipco = iprp == null
        ? null
        : await _find(source, 'ipco', iprp.contentStart, iprp.end);
    final _Box? ispe = ipco == null
        ? null
        : await _find(source, 'ispe', ipco.contentStart, ipco.end);

    if (ispe == null) {
      return MediaProbe(container: container, width: 0, height: 0);
    }

    final Uint8List bytes = await source.read(ispe.contentStart, 12);

    return MediaProbe(
      container: container,
      width: bytes.u32(4),
      height: bytes.u32(8),
    );
  }

  // ---------------------------------------------------------------- walk ----

  /// The first box of [type] among the direct children between [start] and
  /// [end].
  ///
  /// Direct children only. A recursive search would find an `stsd` belonging to
  /// the audio track while looking inside the video one, and the difference is
  /// silent.
  static Future<_Box?> _find(
    ByteSource source,
    String type,
    int start,
    int end, {
    int depth = 0,
  }) async {
    if (depth > _maxDepth) {
      return null;
    }

    int offset = start;

    while (offset < end) {
      final _Box? box = await _readBox(source, offset, end);

      if (box == null) {
        return null;
      }

      if (box.type == type) {
        return box;
      }

      offset = box.end;
    }

    return null;
  }

  /// One box header, or `null` where the file will not give a sane one.
  ///
  /// A size of 1 means the real size is a 64-bit field after the type, which is
  /// how a single box holds more than four gigabytes of frames — common in
  /// exactly the files this tool is for. A size of 0 means "to the end of the
  /// file" and is legal only for the last box; treated as such rather than as
  /// a zero-length box, which would spin the loop for ever.
  static Future<_Box?> _readBox(ByteSource source, int offset, int end) async {
    final Uint8List header = await source.read(offset, 16);

    if (header.length < 8) {
      return null;
    }

    final String type = header.fourCc(4);
    int size = header.u32(0);
    int contentStart = offset + 8;

    if (size == 1) {
      if (header.length < 16) {
        return null;
      }

      size = header.u64(8);
      contentStart = offset + 16;
    } else if (size == 0) {
      size = end - offset;
    }

    if (size < 8 || offset + size > end) {
      return null;
    }

    return _Box(type: type, contentStart: contentStart, end: offset + size);
  }
}

class _Box {
  const _Box({required this.type, required this.contentStart, required this.end});

  final String type;

  /// Where this box's payload or children begin.
  final int contentStart;

  /// One past the last byte of this box.
  final int end;
}

class _MovieHeader {
  const _MovieHeader({required this.durationMs});

  final int? durationMs;
}

class _VideoTrack {
  const _VideoTrack({
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

class _SampleEntry {
  const _SampleEntry({
    required this.codec,
    required this.width,
    required this.height,
  });

  final VideoCodec codec;
  final int width;
  final int height;
}
