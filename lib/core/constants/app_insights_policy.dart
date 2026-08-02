/// The numbers that bound a measurement of the whole disk.
///
/// Fewer than the other two policies, because this walk decides nothing — it
/// opens no file, deletes no file and rewrites no file. Every value here is
/// about not making the app unusable while it counts.
class AppInsightsPolicy {
  const AppInsightsPolicy._();

  /// Files summed before a batch of totals is sent to the UI.
  ///
  /// Far larger than the cleaner's sixty-four, because these arrive far faster:
  /// a `stat` and a string comparison, against the cleaner's rule matching and
  /// the optimiser's header read. At sixty-four a phone with a hundred thousand
  /// files would send fifteen hundred events and rebuild the chart as many
  /// times, for a picture that does not visibly change between them.
  static const int measuredBatchSize = 2000;

  /// How long a partial batch waits before being sent anyway.
  ///
  /// Otherwise the tail of a walk — the last few hundred files — sits unsent
  /// and the chart finishes on a figure a second out of date.
  static const Duration measuredFlushInterval = Duration(milliseconds: 400);

  /// How deep the walk may descend.
  ///
  /// Deeper than either of the others: this one starts at the top of the volume
  /// rather than at a folder somebody chose, and a project checkout or a
  /// synchronised folder nests further than a camera roll ever does. Files
  /// below it land nowhere, which is the one way the `system` slice can be
  /// overstated — and overstating the part labelled "could not look inside" is
  /// the safe direction.
  static const int maxScanDepth = 16;

  /// Files measured before the walk gives up and says so.
  ///
  /// A phone with more than this is real; the chart is already accurate to
  /// within a fraction of a per cent by then, and the alternative is a walk
  /// that runs for minutes to move a slice by nothing anybody can see. The UI
  /// says it stopped early rather than implying the disk is accounted for.
  static const int maxFiles = 400000;
}
