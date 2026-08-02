import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:storage_cleaner/project_files/features/media_optimizer/domain/run_notice.dart';

/// The foreground service and its notification, over a channel.
///
/// The same shape as `AndroidVideoEncoder` and for the same reasons: a method
/// channel for the commands, an event channel for the one thing the platform
/// says back, and `MissingPluginException` answered as "nothing happened"
/// rather than as an error — that is what a widget test and another platform's
/// build both look like.
///
/// Nothing here chooses a word. The service is handed strings the UI has
/// already translated, and it displays them; see `RunNoticeService` for why
/// that beats Android's own resource files here.
class AndroidRunNotice implements RunNotice {
  AndroidRunNotice({
    MethodChannel? channel,
    EventChannel? actions,
    Future<bool> Function()? askToNotify,
  })  : _channel = channel ?? const MethodChannel(_channelName),
        _actions = actions ?? const EventChannel(_actionsName),
        _askToNotify = askToNotify ?? _requestNotificationPermission;

  static const String _channelName =
      'io.github.evgeniuglinsky.storagecleaner/run_notice';
  static const String _actionsName =
      'io.github.evgeniuglinsky.storagecleaner/run_notice/actions';

  final MethodChannel _channel;
  final EventChannel _actions;
  final Future<bool> Function() _askToNotify;

  final StreamController<void> _stopRequests = StreamController<void>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  bool _hasAsked = false;

  @override
  Stream<void> get stopRequests {
    // Subscribed on the first read rather than in the constructor: the notice
    // is built when the app starts and most sessions never run anything.
    _subscription ??= _actions.receiveBroadcastStream().listen(
      (_) => _stopRequests.add(null),
      onError: (Object _) {
        // The channel is not registered. There is no notification, so there is
        // no button on it to press.
      },
    );

    return _stopRequests.stream;
  }

  @override
  Future<void> show({
    required String channelName,
    required String title,
    required String text,
    required String stopLabel,
    double? progress,
  }) async {
    await _askOnce();

    try {
      await _channel.invokeMethod<void>('show', <String, Object?>{
        'channelName': channelName,
        'title': title,
        'text': text,
        'stopLabel': stopLabel,
        // Whole per cent, because that is the resolution of Android's own
        // progress bar and the encoder reports in per cent anyway. Negative is
        // the indeterminate one.
        'progress': progress == null ? -1 : (progress.clamp(0, 1) * 100).round(),
      });
    } on PlatformException {
      // The service refused to start. The run is unaffected and carries on
      // exactly as it did before any of this existed.
    } on MissingPluginException {
      // Another platform's build, or a widget test.
    }
  }

  @override
  Future<void> hide() async {
    try {
      await _channel.invokeMethod<void>('hide');
    } on PlatformException {
      // Nothing was up.
    } on MissingPluginException {
      // Nothing is registered.
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _stopRequests.close();
    await hide();
  }

  /// Asks for `POST_NOTIFICATIONS` the first time a run starts, and ignores the
  /// answer.
  ///
  /// Ignoring it is the point. The permission governs whether the notification
  /// is *visible*, not whether the foreground service may run, so a refusal
  /// costs the user the progress bar and the Stop button and nothing else. The
  /// work still survives the screen going off, which is what they asked for.
  /// Asking at all is deferred to the first run rather than done on launch,
  /// because a permission prompt on the splash screen for a feature the user
  /// has not touched is the kind of thing that gets an app deleted.
  Future<void> _askOnce() async {
    if (_hasAsked) {
      return;
    }

    _hasAsked = true;

    try {
      await _askToNotify();
    } on Exception {
      // Below Android 13 there is no such permission and the plugin may say so
      // by throwing. Nothing to do either way.
    }
  }

  static Future<bool> _requestNotificationPermission() async =>
      (await Permission.notification.request()).isGranted;
}
