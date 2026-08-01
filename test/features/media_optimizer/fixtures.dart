import 'dart:typed_data';

/// Media files built byte by byte, so the fixtures that prove the header
/// parsers right are readable beside them.
///
/// Checked-in binaries would be shorter and worthless: the whole risk in a
/// header parser is an offset being off by a few bytes in a way that still
/// yields a plausible number, and nobody can review that against a blob. Every
/// structure here is written out field by field with the field names in the
/// code, which is the only form in which the offsets can be argued about.
///
/// The files are structurally real and semantically empty — the boxes, chunks
/// and elements are correct and there are no frames in them. That is exactly
/// what a probe reads and no more.

// ------------------------------------------------------------------ bytes --

List<int> _u16(int value) => <int>[(value >> 8) & 0xFF, value & 0xFF];

List<int> _u32(int value) => <int>[
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

List<int> _u64(int value) => <int>[..._u32(value >> 32), ..._u32(value & 0xFFFFFFFF)];

List<int> _u16le(int value) => <int>[value & 0xFF, (value >> 8) & 0xFF];

List<int> _u24le(int value) =>
    <int>[value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF];

List<int> _u32le(int value) => <int>[
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];

List<int> _i32le(int value) => _u32le(value < 0 ? value + 0x100000000 : value);

List<int> _ascii(String value) => value.codeUnits;

Uint8List _bytes(List<int> parts) => Uint8List.fromList(parts);

// ------------------------------------------------------------------- jpeg --

/// A JPEG with an APP1 segment of [exifBytes] in front of the frame header.
///
/// The segment is what makes this worth building: a camera writes EXIF, a
/// colour profile and an embedded thumbnail before the frame, so the
/// dimensions are never at a fixed offset and the marker chain has to be
/// walked to find them.
Uint8List jpegBytes({
  required int width,
  required int height,
  int exifBytes = 0,
  int startOfFrameMarker = 0xC0,
  bool withHuffmanTable = false,
}) {
  return _bytes(<int>[
    0xFF, 0xD8, // SOI
    if (exifBytes > 0) ...<int>[
      0xFF, 0xE1, // APP1
      ..._u16(exifBytes + 2), // length, counting itself
      ...List<int>.filled(exifBytes, 0),
    ],
    if (withHuffmanTable) ...<int>[
      0xFF, 0xC4, // DHT — inside the SOF range and not a frame
      ..._u16(6),
      0, 0, 0, 0,
    ],
    0xFF, startOfFrameMarker, // SOFn
    ..._u16(11), // length
    8, // sample precision
    ..._u16(height), // height comes first — the one field order that reads back
    ..._u16(width),
    1, // component count
    1, 0x11, 0,
    0xFF, 0xD9, // EOI
  ]);
}

// -------------------------------------------------------------------- png --

Uint8List pngBytes({required int width, required int height}) {
  return _bytes(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
    ..._u32(13), // IHDR length
    ..._ascii('IHDR'),
    ..._u32(width),
    ..._u32(height),
    8, 6, 0, 0, 0, // depth, colour type, compression, filter, interlace
    ..._u32(0), // CRC, not checked by anything here
  ]);
}

// -------------------------------------------------------------------- gif --

Uint8List gifBytes({required int width, required int height}) {
  return _bytes(<int>[
    ..._ascii('GIF89a'),
    ..._u16le(width), // little-endian, where PNG is not
    ..._u16le(height),
    0xF7, 0, 0,
    ...List<int>.filled(16, 0),
  ]);
}

// -------------------------------------------------------------------- bmp --

/// A BMP. A negative [height] means the rows are stored top-down, which is
/// legal and which a parser reading the field as unsigned turns into a
/// four-billion-pixel image.
Uint8List bmpBytes({required int width, required int height}) {
  return _bytes(<int>[
    ..._ascii('BM'),
    ..._u32le(1078), // file size
    ..._u32le(0), // reserved
    ..._u32le(54), // pixel data offset
    ..._u32le(40), // DIB header size
    ..._i32le(width),
    ..._i32le(height),
    ..._u16le(1), // planes
    ..._u16le(24), // bits per pixel
    ...List<int>.filled(24, 0),
  ]);
}

// ------------------------------------------------------------------- tiff --

/// A TIFF in either byte order, with the dimensions as shorts or as longs.
///
/// Both axes of variation are real: the leading `II` or `MM` is the format's
/// own declaration of its endianness, and a writer choosing the wider type for
/// a small picture is legal and happens.
Uint8List tiffBytes({
  required int width,
  required int height,
  bool little = true,
  bool asLong = false,
}) {
  List<int> u16(int value) => little ? _u16le(value) : _u16(value);
  List<int> u32(int value) => little ? _u32le(value) : _u32(value);

  // Type 3 is a short and is written into the *first* two bytes of the
  // four-byte value field rather than right-aligned in it.
  List<int> entry(int tag, int value) => <int>[
        ...u16(tag),
        ...u16(asLong ? 4 : 3),
        ...u32(1),
        if (asLong) ...u32(value) else ...<int>[...u16(value), 0, 0],
      ];

  return _bytes(<int>[
    if (little) ...<int>[0x49, 0x49, 0x2A, 0x00] else ...<int>[0x4D, 0x4D, 0x00, 0x2A],
    ...u32(8), // offset of the first directory
    ...u16(2), // entry count
    ...entry(256, width),
    ...entry(257, height),
    ...u32(0), // no next directory
  ]);
}

// ------------------------------------------------------------- iso bmff ----

List<int> _box(String type, List<int> payload, {bool largeSize = false}) {
  if (largeSize) {
    // Size 1 means the real size is a 64-bit field after the type, which is how
    // a single box holds more than four gigabytes of frames.
    return <int>[..._u32(1), ..._ascii(type), ..._u64(payload.length + 16), ...payload];
  }

  return <int>[..._u32(payload.length + 8), ..._ascii(type), ...payload];
}

List<int> _fullBox(String type, List<int> payload, {int version = 0}) =>
    _box(type, <int>[version, 0, 0, 0, ...payload]);

List<int> _ftyp(String brand) =>
    _box('ftyp', <int>[..._ascii(brand), ..._u32(512), ..._ascii(brand)]);

/// `mvhd` — the whole file's length in its own units.
List<int> _mvhd({required int timescale, required int duration}) => _fullBox(
      'mvhd',
      <int>[
        ..._u32(0), // creation time
        ..._u32(0), // modification time
        ..._u32(timescale),
        ..._u32(duration),
        ...List<int>.filled(80, 0),
      ],
    );

List<int> _hdlr(String handler) => _fullBox(
      'hdlr',
      <int>[..._u32(0), ..._ascii(handler), ...List<int>.filled(12, 0)],
    );

List<int> _mdhd({required int timescale, required int duration}) => _fullBox(
      'mdhd',
      <int>[
        ..._u32(0),
        ..._u32(0),
        ..._u32(timescale),
        ..._u32(duration),
        ..._u16(0x55C4), // language
        ..._u16(0),
      ],
    );

/// A visual sample entry, whose layout has not changed since the format was
/// written: six reserved bytes and a data reference index, then sixteen bytes
/// of pre-defined and reserved fields, and the dimensions at thirty-two.
List<int> _stsd(String codec, int width, int height) {
  final List<int> entry = _box(codec, <int>[
    ...List<int>.filled(6, 0), // reserved
    ..._u16(1), // data reference index
    ..._u16(0), // pre_defined
    ..._u16(0), // reserved
    ...List<int>.filled(12, 0), // pre_defined[3]
    ..._u16(width),
    ..._u16(height),
    ...List<int>.filled(50, 0),
  ]);

  return _fullBox('stsd', <int>[..._u32(1), ...entry]);
}

/// `stts` — a run-length table pairing a sample count with the ticks those
/// samples last, and the only place the frame rate can be got from.
///
/// [entries] splits the same samples across that many rows, which is what a
/// variable-rate file looks like. The parser must average over the span of the
/// rows it read rather than divide by the whole track's duration: doing the
/// latter counted a fraction of the frames against all of the seconds, and a
/// two-hour film came out at 0.96 frames a second.
List<int> _stts(int sampleCount, int delta, {int entries = 1}) {
  final int perEntry = (sampleCount / entries).ceil();
  final List<int> rows = <int>[];
  int remaining = sampleCount;

  for (int index = 0; index < entries && remaining > 0; index++) {
    final int count = remaining < perEntry ? remaining : perEntry;

    rows.addAll(<int>[..._u32(count), ..._u32(delta)]);
    remaining -= count;
  }

  return _fullBox('stts', <int>[..._u32(rows.length ~/ 8), ...rows]);
}

List<int> _videoTrak({
  required String codec,
  required int width,
  required int height,
  required int timescale,
  required int duration,
  required int sampleCount,
  int sttsEntries = 1,
}) {
  final List<int> stbl = _box('stbl', <int>[
    ..._stsd(codec, width, height),
    ..._stts(sampleCount, duration ~/ sampleCount, entries: sttsEntries),
  ]);

  return _box('trak', <int>[
    ..._box('mdia', <int>[
      ..._hdlr('vide'),
      ..._mdhd(timescale: timescale, duration: duration),
      ..._box('minf', <int>[...stbl]),
    ]),
  ]);
}

/// A track whose handler says `soun`, to prove the video one is found by its
/// handler rather than by being first.
List<int> _audioTrak() => _box('trak', <int>[
      ..._box('mdia', <int>[
        ..._hdlr('soun'),
        ..._mdhd(timescale: 44100, duration: 44100),
        ..._box('minf', <int>[
          ..._box('stbl', <int>[..._stsd('mp4a', 0, 0)]),
        ]),
      ]),
    ]);

/// An MP4, optionally with its `moov` after the frames — which is where a phone
/// writes it, and the case a head-only parser gets wrong.
Uint8List mp4Bytes({
  required int width,
  required int height,
  required String codec,
  required int durationSeconds,
  required double frameRate,
  bool moovAtEnd = false,
  bool audioTrackFirst = false,
  bool largeBoxSize = false,
  String brand = 'isom',
  int sttsEntries = 1,
}) {
  // A timescale the frame rate divides exactly, which is what a real muxer
  // picks — 24000 for 24 fps, 30000 for 29.97. A round 1000 would make the
  // per-sample delta a truncated integer and the fixture's own frame rate a
  // per cent out, which is the fixture lying rather than the parser.
  final int timescale = (frameRate * 1000).round();
  final int duration = durationSeconds * timescale;
  // Which makes the per-sample delta exactly 1000 ticks.
  final int sampleCount = (durationSeconds * frameRate).round();

  final List<int> moov = _box(
    'moov',
    <int>[
      ..._mvhd(timescale: timescale, duration: duration),
      if (audioTrackFirst) ..._audioTrak(),
      ..._videoTrak(
        codec: codec,
        width: width,
        height: height,
        timescale: timescale,
        duration: duration,
        sampleCount: sampleCount,
        sttsEntries: sttsEntries,
      ),
    ],
    largeSize: largeBoxSize,
  );

  final List<int> mdat = _box('mdat', List<int>.filled(4096, 0));

  return _bytes(<int>[
    ..._ftyp(brand),
    if (moovAtEnd) ...<int>[...mdat, ...moov] else ...<int>[...moov, ...mdat],
  ]);
}

/// A HEIC photograph, whose dimensions are five boxes down in `ispe`.
Uint8List heicBytes({required int width, required int height}) {
  final List<int> ispe = _fullBox('ispe', <int>[..._u32(width), ..._u32(height)]);
  final List<int> ipco = _box('ipco', ispe);
  final List<int> iprp = _box('iprp', ipco);

  // `meta` is a full box, so its children start past the version and flags.
  // Every other container box here is not, and mixing the two up puts the walk
  // four bytes out.
  return _bytes(<int>[..._ftyp('heic'), ..._fullBox('meta', iprp)]);
}

/// Recognisably ISO base media, with no `moov` at all.
///
/// Distinct from "not a video": the screen says the two differently.
Uint8List ftypOnlyBytes() =>
    _bytes(<int>[..._ftyp('isom'), ..._box('free', List<int>.filled(64, 0))]);

/// A box declaring a size of zero, which would spin a naive walk for ever.
Uint8List mp4WithZeroSizedBox() => _bytes(<int>[
      ..._ftyp('isom'),
      ..._u32(0), // size
      ..._ascii('junk'),
      ...List<int>.filled(32, 0),
    ]);

/// A box claiming more bytes than the file holds, which is what a corrupt
/// length field looks like.
Uint8List mp4WithOversizedBox() => _bytes(<int>[
      ..._ftyp('isom'),
      ..._u32(0x7FFFFFFF),
      ..._ascii('moov'),
      ...List<int>.filled(32, 0),
    ]);

// --------------------------------------------------------------- matroska --

/// An EBML element: a variable-width identifier, a variable-width length, and
/// the payload.
List<int> _ebml(int id, List<int> payload) =>
    <int>[..._ebmlId(id), ..._ebmlSize(payload.length), ...payload];

/// The identifier keeps its marker bit, which is what makes `0xAE` and `0x83`
/// the constants the parser matches on.
List<int> _ebmlId(int id) {
  if (id <= 0xFF) {
    return <int>[id];
  }
  if (id <= 0xFFFF) {
    return _u16(id);
  }
  if (id <= 0xFFFFFF) {
    return <int>[(id >> 16) & 0xFF, (id >> 8) & 0xFF, id & 0xFF];
  }

  return _u32(id);
}

/// The length has its marker bit stripped by the reader, so it is set here.
/// Four bytes always, which is legal and keeps the builder simple.
List<int> _ebmlSize(int size) => <int>[
      0x10 | ((size >> 24) & 0x0F),
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
    ];

List<int> _ebmlUint(int id, int value) {
  final List<int> bytes = <int>[];
  int remaining = value;

  do {
    bytes.insert(0, remaining & 0xFF);
    remaining >>= 8;
  } while (remaining > 0);

  return _ebml(id, bytes);
}

List<int> _ebmlFloat(int id, double value) {
  final ByteData data = ByteData(8)..setFloat64(0, value);

  return _ebml(id, data.buffer.asUint8List());
}

/// An MKV or WebM.
///
/// [frameRate] null leaves out `DefaultDuration`, which is what a
/// variable-rate file looks like and which the estimator must refuse rather
/// than guess at.
Uint8List mkvBytes({
  required int width,
  required int height,
  required String codecId,
  required int durationSeconds,
  required double? frameRate,
  String docType = 'matroska',
  int timecodeScaleNanos = 1000000,
}) {
  final double ticks =
      durationSeconds * 1000000000 / timecodeScaleNanos;

  final List<int> info = _ebml(0x1549A966, <int>[
    ..._ebmlUint(0x2AD7B1, timecodeScaleNanos),
    ..._ebmlFloat(0x4489, ticks),
  ]);

  final List<int> video = _ebml(0xE0, <int>[
    ..._ebmlUint(0xB0, width),
    ..._ebmlUint(0xBA, height),
  ]);

  final List<int> trackEntry = _ebml(0xAE, <int>[
    ..._ebmlUint(0xD7, 1), // TrackNumber
    ..._ebmlUint(0x83, 1), // TrackType: video
    ..._ebml(0x86, _ascii(codecId)),
    if (frameRate != null)
      ..._ebmlUint(0x23E383, (1000000000 / frameRate).round()),
    ...video,
  ]);

  final List<int> tracks = _ebml(0x1654AE6B, trackEntry);
  final List<int> segment = _ebml(0x18538067, <int>[...info, ...tracks]);

  final List<int> header = _ebml(0x1A45DFA3, <int>[
    ..._ebml(0x4282, _ascii(docType)), // DocType
  ]);

  return _bytes(<int>[...header, ...segment]);
}

// ------------------------------------------------------------------- riff --

List<int> _riffChunk(String id, List<int> payload) {
  // Chunks are word-aligned: an odd-sized one is followed by a pad byte that is
  // not counted in its length.
  final bool needsPad = payload.length.isOdd;

  return <int>[
    ..._ascii(id),
    ..._u32le(payload.length),
    ...payload,
    if (needsPad) 0,
  ];
}

List<int> _riffList(String type, List<int> payload) =>
    _riffChunk('LIST', <int>[..._ascii(type), ...payload]);

/// An AVI. [audioStreamFirst] puts a `strh` of type `auds` before the video
/// one, whose handler a parser reading the first stream would report as the
/// codec — silently, and with a plausible-looking four letters.
Uint8List aviBytes({
  required int width,
  required int height,
  required String fourCc,
  required int frames,
  required int microsPerFrame,
  bool audioStreamFirst = false,
}) {
  final List<int> avih = _riffChunk('avih', <int>[
    ..._u32le(microsPerFrame),
    ..._u32le(0), // max bytes per second
    ..._u32le(0), // padding granularity
    ..._u32le(0), // flags
    ..._u32le(frames),
    ..._u32le(0), // initial frames
    ..._u32le(1), // stream count
    ..._u32le(0), // suggested buffer size
    ..._u32le(width),
    ..._u32le(height),
    ...List<int>.filled(16, 0),
  ]);

  List<int> strh(String type, String handler) => _riffChunk('strh', <int>[
        ..._ascii(type),
        ..._ascii(handler),
        ...List<int>.filled(48, 0),
      ]);

  final List<int> hdrl = _riffList('hdrl', <int>[
    ...avih,
    if (audioStreamFirst) ..._riffList('strl', strh('auds', 'mp3 ')),
    ..._riffList('strl', strh('vids', fourCc)),
  ]);

  return _bytes(<int>[
    ..._ascii('RIFF'),
    ..._u32le(hdrl.length + 4),
    ..._ascii('AVI '),
    ...hdrl,
  ]);
}

/// A WebP, lossy or extended. Both pack the dimensions into bit fields rather
/// than whole bytes, and the extended one stores them one less than they are.
Uint8List webpBytes({
  required int width,
  required int height,
  bool extended = false,
}) {
  final List<int> chunk = extended
      ? _riffChunk('VP8X', <int>[
          ..._u32le(0), // flags
          ..._u24le(width - 1),
          ..._u24le(height - 1),
        ])
      : _riffChunk('VP8 ', <int>[
          0, 0, 0, // frame tag
          0x9D, 0x01, 0x2A, // sync code
          ..._u16le(width),
          ..._u16le(height),
        ]);

  return _bytes(<int>[
    ..._ascii('RIFF'),
    ..._u32le(chunk.length + 4),
    ..._ascii('WEBP'),
    ...chunk,
  ]);
}
