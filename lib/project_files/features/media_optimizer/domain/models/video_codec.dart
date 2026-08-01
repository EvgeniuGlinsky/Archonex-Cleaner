/// How the frames inside a video were compressed, and how good that method is
/// at it.
///
/// [efficientBitsPerPixelPerFrame] is the whole reason this is an enum with a
/// field rather than a list of names. It is the one number that answers "is
/// this file worth re-encoding", and it belongs to the codec: a 4K clip and a
/// phone clip in the same codec at the same visual quality land at wildly
/// different bitrates but at nearly the same bits per pixel per frame, because
/// dividing by the pixel rate is exactly what removes resolution and frame rate
/// from the question.
///
/// The figures are for camera and screen-recording content at the point where
/// more bitrate stops being visible. They are conservative — a file has to be
/// meaningfully above its codec's figure before anything is offered — because
/// being wrong in this direction costs unclaimed megabytes and being wrong in
/// the other costs the user their footage for nothing.
enum VideoCodec {
  /// The default of the last fifteen years, and what nearly every phone and
  /// camera still writes. Also the reason this tool exists: it is a generation
  /// behind, and everything shot on it has room in it.
  h264(fourCcs: <String>['avc1', 'avc3', 'h264'], efficientBitsPerPixelPerFrame: 0.10),

  /// What this app re-encodes to. Roughly forty per cent smaller than H.264 at
  /// the same visual quality, and hardware-decoded by every device made since
  /// about 2015 — which matters, because a file the phone cannot play back
  /// without draining the battery is not a saving.
  hevc(fourCcs: <String>['hvc1', 'hev1', 'hvc2'], efficientBitsPerPixelPerFrame: 0.06),

  /// Better still, and left alone. Nothing this app can reach encodes AV1 in
  /// reasonable time, and a file already in it has nothing to gain.
  av1(fourCcs: <String>['av01'], efficientBitsPerPixelPerFrame: 0.045),

  /// Between H.264 and HEVC, and close enough to the target that re-encoding a
  /// sensibly-made VP9 file would be work for nothing.
  vp9(fourCcs: <String>['vp09'], efficientBitsPerPixelPerFrame: 0.065),

  /// DivX, Xvid, and what camcorders wrote onto `.avi` files. Twice the size of
  /// H.264 for the same picture, so these are the largest wins on the list and
  /// also the rarest.
  mpeg4Part2(fourCcs: <String>['mp4v', 'divx', 'xvid', 'dx50'], efficientBitsPerPixelPerFrame: 0.20),

  /// Every frame a separate JPEG, with no compression between them at all.
  /// Older action cameras and some screen recorders. Enormous.
  mjpeg(fourCcs: <String>['mjpg', 'jpeg'], efficientBitsPerPixelPerFrame: 0.60),

  /// The header parsed but named something this table does not know.
  ///
  /// [efficientBitsPerPixelPerFrame] is `null` rather than a guess, and the
  /// estimator refuses rather than assuming: an unknown codec could be anything
  /// from a lossless intermediate to something already better than HEVC, and
  /// "probably H.264" is how a tool ends up re-encoding an archive master.
  unknown(fourCcs: <String>[], efficientBitsPerPixelPerFrame: null);

  const VideoCodec({
    required this.fourCcs,
    required this.efficientBitsPerPixelPerFrame,
  });

  /// The sample-entry codes an MP4 or QuickTime `stsd` box uses for this codec,
  /// lower case.
  final List<String> fourCcs;

  /// Bits per pixel per frame at which this codec stops improving visibly, or
  /// `null` where the codec is not known well enough to say.
  final double? efficientBitsPerPixelPerFrame;

  /// Whether re-encoding into HEVC could plausibly help at all.
  ///
  /// False for the two codecs that are already at least as good as the target.
  /// A file in one of those is left alone however large it is, which is the
  /// branch that stops the app spending twenty minutes of battery for three per
  /// cent.
  bool get isAtLeastAsGoodAsTarget => this == hevc || this == av1;

  /// The codec an MP4 sample-entry code names.
  static VideoCodec fromFourCc(String fourCc) {
    final String lower = fourCc.toLowerCase();

    for (final VideoCodec codec in values) {
      if (codec.fourCcs.contains(lower)) {
        return codec;
      }
    }

    return unknown;
  }

  /// The codec a Matroska `CodecID` element names.
  ///
  /// Matroska spells them as strings rather than four-byte codes —
  /// `V_MPEG4/ISO/AVC`, `V_MPEGH/ISO/HEVC` — so this matches on the tail rather
  /// than the whole, which is what keeps the profile suffixes some muxers add
  /// from turning a known codec into an unknown one.
  static VideoCodec fromMatroskaCodecId(String codecId) {
    final String upper = codecId.toUpperCase();

    if (upper.contains('ISO/AVC') || upper.contains('V_AVC')) {
      return h264;
    }
    if (upper.contains('ISO/HEVC') || upper.contains('V_HEVC')) {
      return hevc;
    }
    if (upper.contains('V_AV1')) {
      return av1;
    }
    if (upper.contains('V_VP9')) {
      return vp9;
    }
    if (upper.contains('V_MJPEG')) {
      return mjpeg;
    }
    // Checked last: every string above also starts `V_MPEG4` or similar, so an
    // earlier position here would swallow AVC.
    if (upper.contains('V_MPEG4')) {
      return mpeg4Part2;
    }

    return unknown;
  }
}
