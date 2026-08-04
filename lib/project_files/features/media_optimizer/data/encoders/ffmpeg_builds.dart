import 'dart:ffi' show Abi;

import 'package:flutter/foundation.dart';

/// One published `ffmpeg` build, and how to know it arrived intact.
///
/// The checksum comes in two forms because the two publishers behave
/// differently, and choosing one publisher for the sake of a uniform table would
/// cost the user real minutes: Gyan keeps a `.sha256` file beside a link that
/// moves, and his Windows build is a third the size of the alternative; BtbN
/// keeps the link still under a dated tag, so the digest can be written down
/// here. Either way the app has a published figure to compare against something
/// it is about to execute.
@immutable
class FfmpegBuild {
  const FfmpegBuild({
    required this.archiveUrl,
    required this.approximateBytes,
    required this.executableName,
    this.sha256,
    this.sha256Url,
  }) : assert(
          sha256 != null || sha256Url != null || archiveUrl == '',
          'a build with no published checksum has to say so on purpose',
        );

  /// A build whose publisher offers no checksum at all.
  ///
  /// macOS only, and it is the reason this constructor is named rather than a
  /// `null` in the ordinary one: nothing about "we could not check" should be
  /// possible to write by omission. What stands in for it is the last step of an
  /// install, which runs the binary and reads its version — weaker than a digest
  /// and stronger than nothing.
  const FfmpegBuild.unverified({
    required this.archiveUrl,
    required this.approximateBytes,
    required this.executableName,
  })  : sha256 = null,
        sha256Url = null;

  final String archiveUrl;

  /// Bytes over the wire, for the sentence that offers the download. The figure
  /// each publisher reports for the file, not an average.
  final int approximateBytes;

  /// What the executable is called inside the archive. Searched for rather than
  /// pathed to, because every publisher lays its archive out differently and
  /// two of them put a version number in the folder name.
  final String executableName;

  /// A digest written down here, for a link that does not move.
  final String? sha256;

  /// A digest published beside a link that does, fetched just before the
  /// archive.
  final String? sha256Url;
}

/// Which build this machine needs.
///
/// Keyed by ABI rather than by operating system: an arm64 Windows laptop
/// downloading the x64 build gets a file that exists, verifies, installs and
/// then will not run — the one failure this table exists to make impossible.
class FfmpegBuilds {
  const FfmpegBuilds._();

  /// The dated BtbN tag everything below it is pinned to.
  ///
  /// A tag and not `latest`, because `latest` is moved in place: the digests
  /// written down here would silently stop matching, and the app would start
  /// refusing a download that was perfectly good.
  static const String _btbnTag = 'autobuild-2026-08-03-14-02';
  static const String _btbnBuild = 'ffmpeg-N-125953-gd3ad8a7fee';

  static String _btbn(String name) =>
      'https://github.com/BtbN/FFmpeg-Builds/releases/download/$_btbnTag/$name';

  static const int _megabyte = 1024 * 1024;

  /// `null` where nothing is published for this machine, which the caller
  /// reports as "not available here" rather than offering a button.
  static FfmpegBuild? forThisMachine() => _builds[Abi.current().toString()];

  static final Map<String, FfmpegBuild> _builds = <String, FfmpegBuild>{
    // Gyan's "essentials" build: libx265 and libx264 without the codecs this
    // app never asks for, which is 45 MB against BtbN's 162.
    'windows_x64': FfmpegBuild(
      archiveUrl:
          'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip',
      sha256Url:
          'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip.sha256',
      approximateBytes: 45 * _megabyte,
      executableName: 'ffmpeg.exe',
    ),
    // No arm64 essentials build exists, so this one pays the full size.
    'windows_arm64': FfmpegBuild(
      archiveUrl: _btbn('$_btbnBuild-winarm64-gpl.zip'),
      sha256:
          '984134189ecc2f86479c053c9bbcd57b92e38a832fe8a1d0583a0993188768d6',
      approximateBytes: 110 * _megabyte,
      executableName: 'ffmpeg.exe',
    ),
    'linux_x64': FfmpegBuild(
      archiveUrl: _btbn('$_btbnBuild-linux64-gpl.tar.xz'),
      sha256:
          'e9a3ef45f350d15a48b09d52e2705e9450ee3fe077f13ba31d946225115bf93e',
      approximateBytes: 121 * _megabyte,
      executableName: 'ffmpeg',
    ),
    'linux_arm64': FfmpegBuild(
      archiveUrl: _btbn('$_btbnBuild-linuxarm64-gpl.tar.xz'),
      sha256:
          '4ba3e9a7d0d40c06a9816cb6f8f192c35d4ca0c3861091ee17d920dd402bd11f',
      approximateBytes: 104 * _megabyte,
      executableName: 'ffmpeg',
    ),
    // Martin Riedl publishes the binary on its own — 25 MB rather than a
    // hundred — and publishes no checksum with it. See `FfmpegBuild.unverified`.
    'macos_arm64': const FfmpegBuild.unverified(
      archiveUrl:
          'https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffmpeg.zip',
      approximateBytes: 25 * _megabyte,
      executableName: 'ffmpeg',
    ),
    'macos_x64': const FfmpegBuild.unverified(
      archiveUrl:
          'https://ffmpeg.martin-riedl.de/redirect/latest/macos/amd64/release/ffmpeg.zip',
      approximateBytes: 25 * _megabyte,
      executableName: 'ffmpeg',
    ),
  };
}
