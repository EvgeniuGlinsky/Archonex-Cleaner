import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where this app keeps the video encoder it fetched, and what it is called.
///
/// One file so that the encoder and the thing that downloads it cannot disagree
/// about the path: `FfmpegVideoEncoder` reads it to find something to run, and
/// `FfmpegSupplyRepo` writes there. Two copies of a directory name is a download
/// that succeeds and an encoder that is still missing, with nothing on screen to
/// explain it.
///
/// Under the application support directory rather than beside the executable:
/// `Program Files` is not writable by the user who installed the app, and a
/// portable build sitting on a read-only volume would fail at the last step of a
/// hundred-megabyte download.
class FfmpegLocation {
  const FfmpegLocation._();

  /// Its own folder inside the app's support directory, so that clearing it is
  /// one directory and never a guess about which loose files were ours.
  static const String _directoryName = 'encoders';

  /// What the file is called once installed.
  ///
  /// Fixed rather than taken from the archive: the archives name their builds,
  /// and a path with a version in it would have to be searched for every time
  /// the encoder is run.
  static String get executableName =>
      Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';

  static Future<Directory> directory() async {
    final Directory support = await getApplicationSupportDirectory();

    return Directory(p.join(support.path, _directoryName));
  }

  /// The full path an installed encoder would have, whether or not it is there.
  static Future<String> path() async =>
      p.join((await directory()).path, executableName);

  /// The path to an encoder this app fetched, or `null` if there is none.
  ///
  /// Only the file's presence is checked here. Whether it *runs* is
  /// `FfmpegVideoEncoder.isAvailable`, which is a different question with a
  /// different answer on a build that was interrupted or is for the wrong
  /// architecture.
  static Future<String?> installed() async {
    try {
      final String candidate = await path();

      return await File(candidate).exists() ? candidate : null;
    } on Object {
      // No support directory to look in — a platform without `path_provider`
      // answers this rather than throwing into whatever asked.
      return null;
    }
  }
}
