import 'dart:typed_data';

import 'package:archonex_cleaner/project_files/features/media_optimizer/data/probes/byte_source.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/probes/image_probes.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/probes/iso_bmff_probe.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/probes/matroska_probe.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/data/probes/riff_probe.dart';
import 'package:archonex_cleaner/project_files/features/media_optimizer/domain/models/media_probe.dart';

/// Works out what a file actually is, and reads what its header will give up.
///
/// **The dispatch is on the magic bytes, never on the extension.** A `.mp4`
/// holding a Matroska stream is common enough to matter — one download manager
/// and one badly-behaved converter is all it takes — and a tool that trusted
/// the name would hand that file to an MP4 parser, get nothing, and report a
/// four-gigabyte video as unreadable. The extension's job is over by the time
/// this is called: `MediaRule.matchesFile` used it to decide the file was worth
/// opening, which is all it is good for.
///
/// One read of [_headBytes] serves every format. The still images are answered
/// out of it entirely; the three container formats take it as a starting point
/// and go back to the source for the parts of the tree that are elsewhere.
class MediaProbeReader {
  const MediaProbeReader();

  /// Enough for the signature of everything, the whole header of the simple
  /// formats, and a JPEG's marker chain past the EXIF block and the embedded
  /// thumbnail a camera writes — which is where a smaller read would stop
  /// short and find no dimensions.
  static const int _headBytes = 64 * 1024;

  /// `null` when the file is not media this tool recognises at all.
  ///
  /// Distinct from a probe that comes back with zeroed fields, which means
  /// "recognised, and the header would not say": the estimator turns the first
  /// into nothing at all and the second into a row the user can see.
  Future<MediaProbe?> read(ByteSource source) async {
    final Uint8List head = await source.read(0, _headBytes);

    if (head.length < 16) {
      return null;
    }

    // Containers first. They are the ones whose answer needs the whole file,
    // and the ones whose signature is least likely to appear by accident.
    if (IsoBmffProbe.matches(head)) {
      return IsoBmffProbe.read(source, head);
    }

    if (MatroskaProbe.matches(head)) {
      return MatroskaProbe.read(source, head);
    }

    if (RiffProbe.matches(head)) {
      return RiffProbe.read(source, head);
    }

    return ImageProbes.jpeg(head) ??
        ImageProbes.png(head) ??
        ImageProbes.gif(head) ??
        ImageProbes.bmp(head) ??
        ImageProbes.tiff(head);
  }
}
