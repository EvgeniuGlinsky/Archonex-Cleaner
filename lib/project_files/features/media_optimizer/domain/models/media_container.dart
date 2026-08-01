import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/media_kind.dart';

/// The file formats the walker recognises, and what each one is a container
/// for.
///
/// A container is the box, not the compression: an `.mp4` says how the frames
/// are laid out in the file and nothing at all about how they were encoded,
/// which is why `VideoCodec` is a separate question answered by reading the
/// header. Moving a stream from one box to another — the MKV-to-MP4 conversion
/// that looks like it should help — copies the frames byte for byte and frees
/// well under one per cent. This app changes containers only when it is
/// re-encoding anyway.
///
/// [fromExtension] is a first guess and not the answer. The walker uses it to
/// decide whether a file is worth opening; what the file actually is comes from
/// its magic bytes, because a `.mp4` holding a Matroska stream is common enough
/// to matter.
enum MediaContainer {
  jpeg(
    kind: MediaKind.photo,
    extensions: <String>['.jpg', '.jpeg', '.jpe'],
    canonicalExtension: '.jpg',
  ),
  png(
    kind: MediaKind.photo,
    extensions: <String>['.png'],
    canonicalExtension: '.png',
  ),
  heif(
    kind: MediaKind.photo,
    extensions: <String>['.heic', '.heif'],
    canonicalExtension: '.heic',
  ),
  webp(
    kind: MediaKind.photo,
    extensions: <String>['.webp'],
    canonicalExtension: '.webp',
  ),
  gif(
    kind: MediaKind.photo,
    extensions: <String>['.gif'],
    canonicalExtension: '.gif',
  ),
  bmp(
    kind: MediaKind.photo,
    extensions: <String>['.bmp', '.dib'],
    canonicalExtension: '.bmp',
  ),
  tiff(
    kind: MediaKind.photo,
    extensions: <String>['.tif', '.tiff'],
    canonicalExtension: '.tif',
  ),
  mp4(
    kind: MediaKind.video,
    extensions: <String>['.mp4', '.m4v'],
    canonicalExtension: '.mp4',
  ),
  quickTime(
    kind: MediaKind.video,
    extensions: <String>['.mov', '.qt'],
    canonicalExtension: '.mov',
  ),
  matroska(
    kind: MediaKind.video,
    extensions: <String>['.mkv'],
    canonicalExtension: '.mkv',
  ),
  webm(
    kind: MediaKind.video,
    extensions: <String>['.webm'],
    canonicalExtension: '.webm',
  ),
  avi(
    kind: MediaKind.video,
    extensions: <String>['.avi'],
    canonicalExtension: '.avi',
  );

  const MediaContainer({
    required this.kind,
    required this.extensions,
    required this.canonicalExtension,
  });

  final MediaKind kind;

  /// Every extension seen in the wild for this container, lower case and with
  /// the dot.
  final List<String> extensions;

  /// The one this app writes when it produces this container itself.
  final String canonicalExtension;

  /// The container an extension suggests, or `null` for a file this tool has no
  /// business opening.
  ///
  /// Case-insensitive: `IMG_0001.JPG` is what a camera writes.
  static MediaContainer? fromExtension(String extension) {
    final String lower = extension.toLowerCase();

    for (final MediaContainer container in values) {
      if (container.extensions.contains(lower)) {
        return container;
      }
    }

    return null;
  }

  /// Every extension across every container, for the walker's filter.
  static Set<String> get allExtensions => <String>{
        for (final MediaContainer container in values) ...container.extensions,
      };
}
