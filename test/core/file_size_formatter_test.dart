import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/core/constants/app_byte_units.dart';
import 'package:storage_cleaner/core/utils/file_size_formatter.dart';

void main() {
  test('bytes are shown whole, because a fraction of a byte is noise', () {
    expect(FileSizeFormatter.format(0), '0 B');
    expect(FileSizeFormatter.format(1), '1 B');
    expect(FileSizeFormatter.format(1023), '1023 B');
  });

  test('a round figure loses its decimal', () {
    expect(FileSizeFormatter.format(AppByteUnits.kilobyte), '1 KB');
    expect(FileSizeFormatter.format(AppByteUnits.megabyte), '1 MB');
    expect(FileSizeFormatter.format(AppByteUnits.gigabyte), '1 GB');
    expect(FileSizeFormatter.format(AppByteUnits.terabyte), '1 TB');
  });

  test('anything else keeps one', () {
    expect(FileSizeFormatter.format(1536), '1.5 KB');
    expect(
      FileSizeFormatter.format(AppByteUnits.megabyte * 3 + 512 * 1024),
      '3.5 MB',
    );
  });

  test('it stops at terabytes rather than inventing a unit', () {
    expect(FileSizeFormatter.format(AppByteUnits.terabyte * 2048), '2048 TB');
  });
}
