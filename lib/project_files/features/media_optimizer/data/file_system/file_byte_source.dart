import 'dart:io';
import 'dart:typed_data';

import 'package:storage_cleaner/project_files/features/media_optimizer/data/probes/byte_source.dart';

/// A [ByteSource] over an open file.
///
/// The io side of the seam that keeps the header parsers pure. It is here in
/// `data/file_system/` rather than beside them in `data/probes/` for the reason
/// the whole feature is arranged that way: the parsers are the part worth
/// testing and they must not import `dart:io` to be testable.
///
/// [close] is the caller's to call, and `IoMediaScanRepo` does it in a
/// `finally`. A scan of a camera roll opens thousands of files, and a handle
/// left behind per file exhausts the process's limit long before the walk ends.
class FileByteSource implements ByteSource {
  FileByteSource._(this._file, this.length);

  /// Opens [path], or `null` where the file cannot be read.
  ///
  /// A permission refusal or a file that vanished between being listed and
  /// being opened is the normal case in a folder somebody is using, not an
  /// error worth ending a scan over.
  static Future<FileByteSource?> open(String path) async {
    try {
      final File file = File(path);
      final int length = await file.length();

      return FileByteSource._(await file.open(), length);
    } on FileSystemException {
      return null;
    }
  }

  final RandomAccessFile _file;

  @override
  final int length;

  @override
  Future<Uint8List> read(int offset, int count) async {
    if (offset < 0 || offset >= length || count <= 0) {
      return Uint8List(0);
    }

    try {
      await _file.setPosition(offset);

      // Clamped rather than left to the OS: a corrupt length field inside the
      // file can ask for gigabytes, and every parser here is written to treat a
      // short read as a truncated file.
      final int wanted = offset + count > length ? length - offset : count;

      return _file.read(wanted);
    } on FileSystemException {
      return Uint8List(0);
    }
  }

  Future<void> close() async {
    try {
      await _file.close();
    } on FileSystemException {
      // Already gone. Nothing to do and nothing that depends on it.
    }
  }
}
