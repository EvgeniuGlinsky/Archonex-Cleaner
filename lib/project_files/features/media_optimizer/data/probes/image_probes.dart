import 'dart:typed_data';

import 'package:storage_cleaner/project_files/features/media_optimizer/data/probes/byte_source.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_container.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';

/// The five still formats whose dimensions are near the front of the file.
///
/// One file rather than five, because each is a dozen lines of offset
/// arithmetic and a file apiece would be five imports buying nothing. The two
/// formats that need a structure walked — ISO base media and Matroska — have
/// files of their own for the opposite reason.
///
/// Every one of them returns `null` rather than throwing. A truncated or
/// mislabelled file is the normal case in a Downloads folder, and the caller
/// already has a verdict for it.
class ImageProbes {
  const ImageProbes._();

  /// JPEG: walk the marker chain to the frame header.
  ///
  /// The dimensions are not at a fixed offset, because everything before the
  /// frame — EXIF, colour profiles, the thumbnail a camera embeds — is a
  /// variable-length segment. So this follows the chain: each marker is `FF`,
  /// a type, and a two-byte length that includes itself.
  static MediaProbe? jpeg(Uint8List head) {
    if (!head.startsWith(<int>[0xFF, 0xD8])) {
      return null;
    }

    int offset = 2;

    while (offset + 9 < head.length) {
      if (head.u8(offset) != 0xFF) {
        // Out of step with the chain. Anything read past here would be
        // arithmetic on rubbish.
        return null;
      }

      final int marker = head.u8(offset + 1);

      // Padding: a run of FF bytes before the next marker is legal.
      if (marker == 0xFF) {
        offset++;

        continue;
      }

      // Start of frame, in any of its flavours. C4 is the Huffman table, C8 is
      // reserved and CC is arithmetic coding — none of them a frame — and they
      // sit in the middle of the range, which is why this is not a range check.
      final bool isStartOfFrame = marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;

      if (isStartOfFrame) {
        return MediaProbe(
          container: MediaContainer.jpeg,
          // Height first. It is the one field order in this file that reads
          // backwards, and getting it the wrong way round produces a plausible
          // number rather than an error.
          height: head.u16(offset + 5),
          width: head.u16(offset + 7),
        );
      }

      final int segmentLength = head.u16(offset + 2);

      if (segmentLength < 2) {
        return null;
      }

      offset += 2 + segmentLength;
    }

    return null;
  }

  /// PNG: the signature, then IHDR, which the format requires to come first.
  static MediaProbe? png(Uint8List head) {
    const List<int> signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

    if (!head.startsWith(signature) || head.fourCc(12) != 'IHDR') {
      return null;
    }

    return MediaProbe(
      container: MediaContainer.png,
      width: head.u32(16),
      height: head.u32(20),
    );
  }

  /// GIF: the header carries the logical screen size, little-endian.
  static MediaProbe? gif(Uint8List head) {
    if (!head.startsWith('GIF87a'.codeUnits) &&
        !head.startsWith('GIF89a'.codeUnits)) {
      return null;
    }

    return MediaProbe(
      container: MediaContainer.gif,
      width: head.u16le(6),
      height: head.u16le(8),
    );
  }

  /// BMP: fixed offsets in the info header.
  ///
  /// The height is signed, and negative means the rows are stored top-down.
  /// Only the magnitude means anything to a size estimate.
  static MediaProbe? bmp(Uint8List head) {
    if (!head.startsWith('BM'.codeUnits)) {
      return null;
    }

    return MediaProbe(
      container: MediaContainer.bmp,
      width: head.i32le(18).abs(),
      height: head.i32le(22).abs(),
    );
  }

  /// TIFF: an offset to a tag directory, in whichever byte order the first two
  /// bytes declare.
  ///
  /// The only format here that can be either-endian, which is what the leading
  /// `II` or `MM` is for. Tags 256 and 257 are the dimensions; both can be
  /// stored as a short or as a long, and a writer choosing the wider type for a
  /// small picture is legal and happens.
  static MediaProbe? tiff(Uint8List head) {
    final bool little = head.startsWith(<int>[0x49, 0x49, 0x2A, 0x00]);
    final bool big = head.startsWith(<int>[0x4D, 0x4D, 0x00, 0x2A]);

    if (!little && !big) {
      return null;
    }

    int read32(int offset) => little ? head.u32le(offset) : head.u32(offset);
    int read16(int offset) => little ? head.u16le(offset) : head.u16(offset);

    final int directory = read32(4);

    if (directory <= 0 || directory + 2 > head.length) {
      return null;
    }

    final int entryCount = read16(directory);
    int width = 0;
    int height = 0;

    for (int index = 0; index < entryCount; index++) {
      final int entry = directory + 2 + index * 12;

      if (entry + 12 > head.length) {
        break;
      }

      final int tag = read16(entry);
      final int type = read16(entry + 2);
      // Type 3 is a 16-bit short, and it is written into the *first* two bytes
      // of the four-byte value field rather than right-aligned in it.
      final int value = type == 3 ? read16(entry + 8) : read32(entry + 8);

      if (tag == 256) {
        width = value;
      } else if (tag == 257) {
        height = value;
      }
    }

    if (width <= 0 || height <= 0) {
      return null;
    }

    return MediaProbe(container: MediaContainer.tiff, width: width, height: height);
  }
}
