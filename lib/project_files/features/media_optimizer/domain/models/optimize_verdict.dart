/// Why a file is, or is not, on the list of things worth re-encoding.
///
/// Every finding carries one, including the ones nothing will be done to. A
/// tool that silently drops the files it decided against looks, to somebody
/// staring at a full disk and a three-gigabyte video, exactly like a tool that
/// failed to find it — so the screen shows those rows too and this is what it
/// says about them.
///
/// There is no `tooSmall` and no `tooNew`, and their absence is deliberate.
/// Both are decided by `OptimizeGuard` before the file is ever opened, and a
/// finding it refuses is dropped rather than listed: a camera roll holds
/// thousands of files under the size floor, and a screen reporting each of them
/// as "nothing to do here" is a screen nobody reads to the bottom of.
///
/// It carries no copy. `OptimizeVerdictUi` turns each into a sentence, for the
/// reason every domain enum here does: translating the app is an ARB file.
enum OptimizeVerdict {
  /// The estimate clears both thresholds in `AppOptimizerPolicy`. The only
  /// verdict that puts a file on the list with a tick beside it.
  worthIt,

  /// Re-encoding would free less than it is worth spending the battery on.
  ///
  /// The common answer for anything already in HEVC or AV1, and for a JPEG that
  /// was saved sensibly the first time.
  alreadyEfficient,

  /// The header would not parse, or parsed without saying how long the video
  /// is. The file is left alone, because everything downstream of here would be
  /// a guess.
  unreadable,

  /// A format this tool has no encoder for.
  ///
  /// HEIF, WebP and AVIF land here and it is not a gap: they are already the
  /// efficient answer, and re-encoding one would be spending quality to reach a
  /// size it is already at.
  unsupportedFormat,
}
