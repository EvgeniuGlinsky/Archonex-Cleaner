import 'package:equatable/equatable.dart';

import 'package:storage_cleaner/core/constants/app_quarantine_policy.dart';
import 'package:storage_cleaner/project_files/features/quarantine/domain/models/quarantine_entry.dart';

/// One cleanup's worth of files, kept together so an undo is one action.
///
/// Per run rather than per file: a user who wants something back rarely knows
/// which of nine thousand files it was, and "undo the cleanup I just did" is
/// the only request they can actually formulate.
final class QuarantineBatch extends Equatable {
  const QuarantineBatch({
    required this.id,
    required this.createdAt,
    required this.entries,
  });

  /// Also the name of the directory holding the files.
  final String id;

  final DateTime createdAt;

  final List<QuarantineEntry> entries;

  int get fileCount => entries.length;

  int get totalBytes =>
      entries.fold(0, (sum, entry) => sum + entry.sizeInBytes);

  DateTime get expiresAt => createdAt.add(AppQuarantinePolicy.retention);

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// Whole days left before it goes, floored, never below zero.
  ///
  /// Floored rather than rounded: "1 day left" on something that has eighteen
  /// hours left is the safer of the two roundings.
  int daysLeftAt(DateTime now) {
    final Duration left = expiresAt.difference(now);

    return left.isNegative ? 0 : left.inDays;
  }

  @override
  List<Object?> get props => <Object?>[id, createdAt, entries];
}
