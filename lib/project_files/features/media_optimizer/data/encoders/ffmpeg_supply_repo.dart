import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'package:storage_cleaner/project_files/features/media_optimizer/data/encoders/ffmpeg_builds.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/data/encoders/ffmpeg_location.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/encoder_supply_repo.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/encoder_supply_job.dart';
import 'package:storage_cleaner/project_files/features/media_optimizer/domain/models/optimize_failure.dart';

/// Fetches a published `ffmpeg` build and installs it where
/// `FfmpegVideoEncoder` looks.
///
/// The three desktops. What it replaces is a sentence telling the user to
/// install FFmpeg and put it on their path — see `EncoderSupplyRepo` for why
/// fetching is the answer rather than bundling.
///
/// The order of the steps is the safety of it, and it is the same ladder
/// `IoMediaOptimizeRepo` uses for a different reason: download into a working
/// directory *beside* the destination, verify, unpack, and only then move the one
/// file into place. A download written straight to the final path is an encoder
/// that exists, half arrives, and is then run.
class FfmpegSupplyRepo implements EncoderSupplyRepo {
  FfmpegSupplyRepo({FfmpegBuild? build})
      : _build = build ?? FfmpegBuilds.forThisMachine();

  final FfmpegBuild? _build;

  @override
  bool get isSupported => _build != null;

  @override
  int get downloadBytes => _build?.approximateBytes ?? 0;

  @override
  Future<bool> get isInstalled async =>
      await FfmpegLocation.installed() != null;

  @override
  EncoderSupplyJob fetch() {
    final FfmpegBuild? build = _build;

    if (build == null) {
      return const _RefusingSupplyJob();
    }

    return _FfmpegFetchJob(build);
  }
}

/// What a platform with nothing published for it hands back.
///
/// An error rather than an empty stream, for the reason `UnavailableEncoder`
/// gives: a job that closes without doing anything looks exactly like a job that
/// worked, and the screen would then hide the offer and still have no encoder.
class _RefusingSupplyJob implements EncoderSupplyJob {
  const _RefusingSupplyJob();

  @override
  Stream<double> get progress =>
      Stream<double>.error(const EncoderFetchFailure());

  @override
  Future<void> cancel() async {}
}

class _FfmpegFetchJob implements EncoderSupplyJob {
  _FfmpegFetchJob(this._build) {
    _controller = StreamController<double>(onListen: _start);
  }

  /// Where the download stops and the rest of the work begins.
  ///
  /// The unpack and the version check take seconds against the download's
  /// minutes, but they are not free, and a bar that sat at 100% while `tar` ran
  /// would read as a hang at the very end. So the transfer owns the first
  /// [_transferShare] of the bar and the steps after it own the rest.
  static const double _transferShare = 0.9;

  /// Emitted at most this often, rather than per chunk: a 45 MB download is
  /// thousands of chunks, and a bloc rebuild per chunk is the same mistake the
  /// scan jobs batch their findings to avoid.
  static const double _progressStep = 0.005;

  final FfmpegBuild _build;

  late final StreamController<double> _controller;

  HttpClient? _client;
  bool _isCancelling = false;
  double _reported = 0;

  @override
  Stream<double> get progress => _controller.stream;

  @override
  Future<void> cancel() async {
    _isCancelling = true;
    // Closed with force: a socket waiting on a stalled server does not notice a
    // flag, and the read loop below sees the resulting error as a cancellation.
    _client?.close(force: true);
  }

  Future<void> _start() async {
    Directory? working;

    try {
      final Directory destination = await FfmpegLocation.directory();
      await destination.create(recursive: true);

      // Beside the destination, so the last move is a rename on one volume
      // rather than a copy of a hundred megabytes across two.
      working = Directory(p.join(destination.path, '.fetching'));
      if (await working.exists()) {
        await working.delete(recursive: true);
      }
      await working.create(recursive: true);

      final File archive = File(p.join(working.path, 'ffmpeg-archive'));

      await _download(archive);
      _stopIfCancelled();

      await _verify(archive);
      _emit(_transferShare + 0.03);
      _stopIfCancelled();

      final String unpacked = await _unpack(archive: archive, into: working);
      _emit(_transferShare + 0.07);
      _stopIfCancelled();

      await _install(unpacked);
      _emit(1);

      await _controller.close();
    } on OptimizeFailure catch (failure, stackTrace) {
      _controller.addError(failure, stackTrace);
      await _controller.close();
    } on Object catch (_, stackTrace) {
      // Everything the network and the disk can throw, said as one piece of
      // news: from here the only answer is to try again.
      _controller.addError(
        _isCancelling
            ? const EncoderFetchCancelledFailure()
            : const EncoderFetchFailure(),
        stackTrace,
      );
      await _controller.close();
    } finally {
      _client?.close(force: true);
      _client = null;
      await _deleteQuietly(working);
    }
  }

  Future<void> _download(File into) async {
    final HttpClient client = HttpClient();
    _client = client;

    final HttpClientResponse response =
        await (await client.getUrl(Uri.parse(_build.archiveUrl))).close();

    if (response.statusCode != HttpStatus.ok) {
      throw const EncoderFetchFailure();
    }

    final int total = response.contentLength > 0
        ? response.contentLength
        : _build.approximateBytes;

    final IOSink sink = into.openWrite();
    int received = 0;

    try {
      await for (final List<int> chunk in response) {
        _stopIfCancelled();

        sink.add(chunk);
        received += chunk.length;

        _emit((received / total).clamp(0.0, 1.0) * _transferShare);
      }
    } finally {
      await sink.close();
    }
  }

  /// Compares what arrived against what the publisher published.
  ///
  /// The digest is read from the network first where it is published beside a
  /// moving link, and read from the table where the link is pinned — see
  /// `FfmpegBuild`. A mismatch is `EncoderContentsFailure` and never a retry:
  /// this is the last gate before the app runs the file.
  Future<void> _verify(File archive) async {
    final String? expected = _build.sha256 ?? await _publishedDigest();

    if (expected == null) {
      return;
    }

    final Digest actual = await sha256.bind(archive.openRead()).first;

    if (actual.toString().toLowerCase() != expected.toLowerCase()) {
      throw const EncoderContentsFailure();
    }
  }

  Future<String?> _publishedDigest() async {
    final String? url = _build.sha256Url;

    if (url == null) {
      return null;
    }

    final HttpClient client = HttpClient();

    try {
      final HttpClientResponse response =
          await (await client.getUrl(Uri.parse(url))).close();

      if (response.statusCode != HttpStatus.ok) {
        throw const EncoderFetchFailure();
      }

      final String body = await response.transform(utf8.decoder).join();

      // The file is the digest, sometimes followed by the file name.
      return body.trim().split(RegExp(r'\s+')).first;
    } finally {
      client.close(force: true);
    }
  }

  /// Unpacks with the `tar` every one of these platforms already has.
  ///
  /// Windows has carried bsdtar in System32 since 1803 and it reads zip as well
  /// as tar, which is what makes one command enough for a `.zip` on Windows and
  /// macOS and a `.tar.xz` on Linux. The alternative was a pure-Dart archive
  /// package and an xz decoder in Dart, to do what the operating system does in
  /// C.
  ///
  /// Returns the path of the executable found inside.
  Future<String> _unpack({
    required File archive,
    required Directory into,
  }) async {
    final ProcessResult result = await Process.run(
      'tar',
      <String>['-xf', archive.path, '-C', into.path],
    );

    if (result.exitCode != 0) {
      throw const EncoderContentsFailure();
    }

    // Deleted before the search, so a hundred megabytes are not held twice
    // while the tree is walked.
    await _deleteQuietly(archive);

    final String? found = await _findExecutable(into);

    if (found == null) {
      throw const EncoderContentsFailure();
    }

    return found;
  }

  /// Depth-first for [FfmpegBuild.executableName].
  ///
  /// Searched for rather than pathed to: one publisher puts it in
  /// `<name>-<version>/bin/`, another at the root, and a layout that changed
  /// between builds would be a download that verifies and installs nothing.
  Future<String?> _findExecutable(Directory root) async {
    await for (final FileSystemEntity entity
        in root.list(recursive: true, followLinks: false)) {
      if (entity is File && p.basename(entity.path) == _build.executableName) {
        return entity.path;
      }
    }

    return null;
  }

  /// Moves the one file into place and proves it runs.
  ///
  /// The proof is the last step and it is not decoration: on macOS nothing was
  /// verified by digest, and everywhere else an archive can hold a binary for
  /// another architecture, which installs perfectly and fails at the first
  /// encode — long after this screen could have said so.
  Future<void> _install(String executable) async {
    final String target = await FfmpegLocation.path();
    final File source = File(executable);

    // Rename over a file Windows will not overwrite while it exists, so the old
    // one goes first. Nothing is using it: an encode in flight holds its own
    // process, not this path.
    await _deleteQuietly(File(target));
    await source.rename(target);

    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['+x', target]);
    }

    try {
      final ProcessResult version =
          await Process.run(target, <String>['-version']);

      if (version.exitCode != 0) {
        throw const EncoderContentsFailure();
      }
    } on ProcessException {
      throw const EncoderContentsFailure();
    } on EncoderContentsFailure {
      await _deleteQuietly(File(target));

      rethrow;
    }
  }

  void _emit(double fraction) {
    if (_controller.isClosed) {
      return;
    }

    if (fraction < 1 && fraction - _reported < _progressStep) {
      return;
    }

    _reported = fraction;
    _controller.add(fraction.clamp(0.0, 1.0));
  }

  void _stopIfCancelled() {
    if (_isCancelling) {
      throw const EncoderFetchCancelledFailure();
    }
  }

  static Future<void> _deleteQuietly(FileSystemEntity? entity) async {
    if (entity == null) {
      return;
    }

    try {
      if (await entity.exists()) {
        await entity.delete(recursive: true);
      }
    } on FileSystemException {
      // Nothing to answer to. A leftover in the app's own support directory is
      // swept by the next fetch, which empties the working folder first.
    }
  }
}
