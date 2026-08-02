import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:storage_cleaner/core/app/storage_cleaner_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Upright only, on every platform that listens.
  //
  // Not a stylistic choice. Every screen here is one column of rows under one
  // primary button, and landscape turns that into a button below the fold with
  // a strip of list above it. It is also a second width for the tiles to be
  // argued about at, and the narrow one has already produced a real layout bug
  // — the story is in `JunkCategoryTile`.
  //
  // Android is told twice, here and with `android:screenOrientation` in the
  // manifest. The manifest is what keeps the launch theme upright before Dart
  // has run at all; this is what covers the platforms that have no manifest.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const StorageCleanerApp());
}
