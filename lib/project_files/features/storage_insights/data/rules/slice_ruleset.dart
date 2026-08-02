import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';

/// Which slice a file belongs to, by the only thing this walk knows about it.
///
/// The extension, and nothing else. Everywhere else in this app that would be
/// unacceptable — `MediaProbeReader` reads magic bytes precisely because a
/// `.mp4` holding a Matroska stream is common — and here it is the right
/// answer, because the two walks are answering different questions. The
/// optimiser is deciding whether to *rewrite somebody's file* and has to be
/// certain; this is deciding which bar a byte lands in, and a misfiled
/// screenshot moves a chart by nothing at all. Being wrong costs a pixel, and
/// opening every file on a phone to be right would cost minutes.
///
/// A pure table with no platform in it, like `JunkRuleset` and `MediaRuleset`,
/// so the whole thing is testable from wherever CI runs.
class SliceRuleset {
  const SliceRuleset._();

  /// Unknown extensions, and files with none, land in `other` rather than being
  /// dropped. A dropped byte is a byte that reappears in the `system` slice,
  /// labelled as something the app could not look inside — which would be a
  /// lie about a file it walked straight past.
  static StorageSliceCategory categoryOf(String name) {
    final int dot = name.lastIndexOf('.');

    if (dot <= 0 || dot == name.length - 1) {
      return StorageSliceCategory.other;
    }

    return _byExtension[name.substring(dot).toLowerCase()] ??
        StorageSliceCategory.other;
  }

  /// Deliberately not exhaustive.
  ///
  /// It covers what is actually on a phone in quantity. A table trying to name
  /// every extension in existence would be longer, no more accurate about the
  /// nine tenths of a disk these already catch, and something nobody would ever
  /// dare delete a line from.
  static const Map<String, StorageSliceCategory> _byExtension =
      <String, StorageSliceCategory>{
    // Photographs. HEIF and AVIF included although the optimiser refuses them:
    // this screen says where the space is, not what can be done about it.
    '.jpg': StorageSliceCategory.photos,
    '.jpeg': StorageSliceCategory.photos,
    '.jpe': StorageSliceCategory.photos,
    '.png': StorageSliceCategory.photos,
    '.heic': StorageSliceCategory.photos,
    '.heif': StorageSliceCategory.photos,
    '.avif': StorageSliceCategory.photos,
    '.webp': StorageSliceCategory.photos,
    '.gif': StorageSliceCategory.photos,
    '.bmp': StorageSliceCategory.photos,
    '.dib': StorageSliceCategory.photos,
    '.tif': StorageSliceCategory.photos,
    '.tiff': StorageSliceCategory.photos,
    '.raw': StorageSliceCategory.photos,
    '.dng': StorageSliceCategory.photos,
    '.cr2': StorageSliceCategory.photos,
    '.nef': StorageSliceCategory.photos,
    '.svg': StorageSliceCategory.photos,

    '.mp4': StorageSliceCategory.videos,
    '.m4v': StorageSliceCategory.videos,
    '.mov': StorageSliceCategory.videos,
    '.qt': StorageSliceCategory.videos,
    '.mkv': StorageSliceCategory.videos,
    '.webm': StorageSliceCategory.videos,
    '.avi': StorageSliceCategory.videos,
    '.3gp': StorageSliceCategory.videos,
    '.3g2': StorageSliceCategory.videos,
    '.wmv': StorageSliceCategory.videos,
    '.flv': StorageSliceCategory.videos,
    '.mpg': StorageSliceCategory.videos,
    '.mpeg': StorageSliceCategory.videos,
    '.ts': StorageSliceCategory.videos,
    '.m2ts': StorageSliceCategory.videos,

    '.mp3': StorageSliceCategory.audio,
    '.m4a': StorageSliceCategory.audio,
    '.aac': StorageSliceCategory.audio,
    '.ogg': StorageSliceCategory.audio,
    '.oga': StorageSliceCategory.audio,
    '.opus': StorageSliceCategory.audio,
    '.flac': StorageSliceCategory.audio,
    '.wav': StorageSliceCategory.audio,
    '.wma': StorageSliceCategory.audio,
    '.amr': StorageSliceCategory.audio,
    '.mid': StorageSliceCategory.audio,

    '.pdf': StorageSliceCategory.documents,
    '.doc': StorageSliceCategory.documents,
    '.docx': StorageSliceCategory.documents,
    '.xls': StorageSliceCategory.documents,
    '.xlsx': StorageSliceCategory.documents,
    '.ppt': StorageSliceCategory.documents,
    '.pptx': StorageSliceCategory.documents,
    '.odt': StorageSliceCategory.documents,
    '.ods': StorageSliceCategory.documents,
    '.rtf': StorageSliceCategory.documents,
    '.txt': StorageSliceCategory.documents,
    '.md': StorageSliceCategory.documents,
    '.csv': StorageSliceCategory.documents,
    '.epub': StorageSliceCategory.documents,
    '.fb2': StorageSliceCategory.documents,
    '.mobi': StorageSliceCategory.documents,
    '.djvu': StorageSliceCategory.documents,

    // Archives and installers together, because they are one answer to the
    // user: a large file that was downloaded to be opened once. It is also the
    // one row here the cleaner already offers to act on.
    '.zip': StorageSliceCategory.archives,
    '.rar': StorageSliceCategory.archives,
    '.7z': StorageSliceCategory.archives,
    '.tar': StorageSliceCategory.archives,
    '.gz': StorageSliceCategory.archives,
    '.bz2': StorageSliceCategory.archives,
    '.xz': StorageSliceCategory.archives,
    '.iso': StorageSliceCategory.archives,
    '.apk': StorageSliceCategory.archives,
    '.apks': StorageSliceCategory.archives,
    '.xapk': StorageSliceCategory.archives,
    '.obb': StorageSliceCategory.archives,
    '.exe': StorageSliceCategory.archives,
    '.msi': StorageSliceCategory.archives,
    '.dmg': StorageSliceCategory.archives,
    '.pkg': StorageSliceCategory.archives,
    '.deb': StorageSliceCategory.archives,
    '.rpm': StorageSliceCategory.archives,
    '.appimage': StorageSliceCategory.archives,
  };
}
