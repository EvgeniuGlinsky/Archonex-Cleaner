/// The two kinds of file this tool knows how to make smaller.
///
/// A closed set of two, and it stays two. Audio is the obvious third and is
/// deliberately absent: a music library is either already in a lossy format at
/// a bitrate the owner chose, or it is lossless *on purpose*, and re-encoding
/// either of those is taking a decision that was already taken.
///
/// Declaration order is display order — videos first, because on a device with
/// a space problem the videos are the space problem.
enum MediaKind {
  video,
  photo,
}
