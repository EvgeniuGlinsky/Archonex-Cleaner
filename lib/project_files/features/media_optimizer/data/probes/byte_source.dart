import 'dart:typed_data';

/// A file the probes can read pieces of, without knowing it is a file.
///
/// The whole point of the indirection: an MP4's `moov` box is routinely at the
/// *end* of the file, so the probes need to seek, and a probe that took a
/// `RandomAccessFile` could only be tested against a real one. With this, the
/// parsers are pure and `media_probes_test.dart` builds its fixtures as byte
/// lists in the test file — which is also the only honest way to test a header
/// parser, because a fixture checked in as a binary is one nobody can review.
///
/// [read] never throws for an over-long request. It returns what it has, and
/// every parser is written to treat a short read as "this file is truncated"
/// rather than as an error: a half-downloaded video is a normal thing to find
/// in a Downloads folder.
abstract interface class ByteSource {
  int get length;

  Future<Uint8List> read(int offset, int count);
}

/// A [ByteSource] over bytes already in memory.
///
/// Used by the tests, and in production for the small formats whose whole
/// header arrives in the first read — see `MediaProbeReader`.
class BytesSource implements ByteSource {
  const BytesSource(this._bytes, {int? length}) : _length = length;

  final Uint8List _bytes;

  /// The size of the file these bytes came from, where that is larger than the
  /// bytes themselves.
  ///
  /// A JPEG's dimensions are in its first kilobyte and its size is not, and
  /// several parsers need both.
  final int? _length;

  @override
  int get length => _length ?? _bytes.length;

  @override
  Future<Uint8List> read(int offset, int count) async {
    if (offset < 0 || offset >= _bytes.length || count <= 0) {
      return Uint8List(0);
    }

    final int end = (offset + count).clamp(0, _bytes.length);

    return Uint8List.sublistView(_bytes, offset, end);
  }
}

/// Big-endian and little-endian reads over a chunk, with a short buffer
/// answering zero rather than throwing.
///
/// Every parser here is walking a structure whose offsets come from the file
/// itself, so a corrupt length field points anywhere. Bounds-checking at each
/// read and returning zero turns that into a probe that fails to find what it
/// wanted — which the caller already handles — instead of an exception that
/// would have to be caught around every field.
extension ByteReads on Uint8List {
  int u8(int offset) => offset >= 0 && offset < length ? this[offset] : 0;

  int u16(int offset) => (u8(offset) << 8) | u8(offset + 1);

  int u16le(int offset) => u8(offset) | (u8(offset + 1) << 8);

  int u24(int offset) => (u16(offset) << 8) | u8(offset + 2);

  int u32(int offset) =>
      (u8(offset) << 24) | (u8(offset + 1) << 16) | (u8(offset + 2) << 8) | u8(offset + 3);

  int u32le(int offset) =>
      u8(offset) |
      (u8(offset + 1) << 8) |
      (u8(offset + 2) << 16) |
      (u8(offset + 3) << 24);

  /// A 32-bit little-endian value read as signed. BMP writes a negative height
  /// for a top-down bitmap, and the absolute value is the one that means
  /// anything here.
  int i32le(int offset) {
    final int value = u32le(offset);

    return value >= 0x80000000 ? value - 0x100000000 : value;
  }

  int u64(int offset) => (u32(offset) << 32) | u32(offset + 4);

  /// Four bytes as ASCII. Box types, RIFF chunk names and codec codes are all
  /// spelled this way.
  String fourCc(int offset) {
    final StringBuffer buffer = StringBuffer();

    for (int index = offset; index < offset + 4; index++) {
      buffer.writeCharCode(u8(index));
    }

    return buffer.toString();
  }

  bool startsWith(List<int> signature, [int offset = 0]) {
    if (offset + signature.length > length) {
      return false;
    }

    for (int index = 0; index < signature.length; index++) {
      if (this[offset + index] != signature[index]) {
        return false;
      }
    }

    return true;
  }
}
