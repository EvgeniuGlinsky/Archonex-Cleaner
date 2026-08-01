import 'dart:convert';

import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_batch.dart';
import 'package:archonex_cleaner/project_files/features/quarantine/domain/models/quarantine_entry.dart';
import 'package:archonex_cleaner/project_files/features/storage_cleaner/domain/models/junk_category.dart';

/// Reads and writes the quarantine index.
///
/// Its own file, and in `data/`, so the domain models stay free of
/// serialisation: a `toJson` on `QuarantineBatch` would be a storage format
/// living in the layer that is supposed to have no idea one exists.
///
/// Every read is defensive. This file is the only thing standing between a
/// quarantine directory and a set of orphaned files nobody can put back, and it
/// is written to disk by a process that can be killed mid-write. A row that
/// will not parse is dropped and the rest of the index survives — the
/// alternative, throwing, loses every other batch to one bad line.
class QuarantineManifest {
  const QuarantineManifest._();

  static const int _version = 1;

  static String encode(List<QuarantineBatch> batches) {
    return jsonEncode(<String, Object?>{
      'version': _version,
      'batches': batches.map(_encodeBatch).toList(growable: false),
    });
  }

  /// Never throws. An unreadable manifest is an empty one.
  static List<QuarantineBatch> decode(String source) {
    try {
      final Object? root = jsonDecode(source);

      if (root is! Map<String, Object?>) {
        return const <QuarantineBatch>[];
      }

      final Object? batches = root['batches'];

      if (batches is! List<Object?>) {
        return const <QuarantineBatch>[];
      }

      return batches
          .map(_decodeBatch)
          .whereType<QuarantineBatch>()
          .toList(growable: false);
    } on FormatException {
      return const <QuarantineBatch>[];
    }
  }

  static Map<String, Object?> _encodeBatch(QuarantineBatch batch) {
    return <String, Object?>{
      'id': batch.id,
      'createdAt': batch.createdAt.toIso8601String(),
      'entries': batch.entries.map(_encodeEntry).toList(growable: false),
    };
  }

  static Map<String, Object?> _encodeEntry(QuarantineEntry entry) {
    return <String, Object?>{
      'originalPath': entry.originalPath,
      'storedName': entry.storedName,
      'sizeInBytes': entry.sizeInBytes,
      'category': entry.category.name,
      'wasDirectory': entry.wasDirectory,
    };
  }

  static QuarantineBatch? _decodeBatch(Object? source) {
    if (source is! Map<String, Object?>) {
      return null;
    }

    final Object? id = source['id'];
    final DateTime? createdAt = _parseDate(source['createdAt']);
    final Object? entries = source['entries'];

    if (id is! String || createdAt == null || entries is! List<Object?>) {
      return null;
    }

    return QuarantineBatch(
      id: id,
      createdAt: createdAt,
      entries: entries
          .map(_decodeEntry)
          .whereType<QuarantineEntry>()
          .toList(growable: false),
    );
  }

  static QuarantineEntry? _decodeEntry(Object? source) {
    if (source is! Map<String, Object?>) {
      return null;
    }

    final Object? originalPath = source['originalPath'];
    final Object? storedName = source['storedName'];
    final Object? sizeInBytes = source['sizeInBytes'];
    final JunkCategory? category = _parseCategory(source['category']);

    if (originalPath is! String ||
        storedName is! String ||
        sizeInBytes is! int ||
        category == null) {
      return null;
    }

    return QuarantineEntry(
      originalPath: originalPath,
      storedName: storedName,
      sizeInBytes: sizeInBytes,
      category: category,
      wasDirectory: source['wasDirectory'] == true,
    );
  }

  static DateTime? _parseDate(Object? source) =>
      source is String ? DateTime.tryParse(source) : null;

  /// A category renamed in a later version leaves entries naming one that no
  /// longer exists. Those rows are dropped rather than mapped to a default,
  /// because the category decides nothing about a restore and guessing it wrong
  /// would put the file in the wrong row of the quarantine screen.
  static JunkCategory? _parseCategory(Object? source) {
    if (source is! String) {
      return null;
    }

    for (final JunkCategory category in JunkCategory.values) {
      if (category.name == source) {
        return category;
      }
    }

    return null;
  }
}
