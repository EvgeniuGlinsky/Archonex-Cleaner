import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner/project_files/features/storage_insights/data/rules/slice_ruleset.dart';
import 'package:storage_cleaner/project_files/features/storage_insights/domain/models/storage_slice.dart';

void main() {
  StorageSliceCategory of(String name) => SliceRuleset.categoryOf(name);

  test('the four kinds a phone is actually full of', () {
    expect(of('IMG_0001.JPG'), StorageSliceCategory.photos);
    expect(of('VID_20240101_120000.mp4'), StorageSliceCategory.videos);
    expect(of('voice-note.opus'), StorageSliceCategory.audio);
    expect(of('boarding pass.pdf'), StorageSliceCategory.documents);
  });

  test('installers sit with the archives, because they are one answer', () {
    // A large file downloaded to be opened once. It is also the row the cleaner
    // already offers to act on.
    expect(of('app-release.apk'), StorageSliceCategory.archives);
    expect(of('backup.zip'), StorageSliceCategory.archives);
  });

  test('the extension is read case-insensitively', () {
    expect(of('HOLIDAY.MOV'), StorageSliceCategory.videos);
    expect(of('holiday.mov'), StorageSliceCategory.videos);
  });

  test('a name with no extension is other, not dropped', () {
    // A dropped byte reappears in the system slice, labelled as something the
    // app could not look inside — which would be a lie about a file it walked
    // straight past.
    expect(of('LICENSE'), StorageSliceCategory.other);
    expect(of('archive.'), StorageSliceCategory.other);
    expect(of('.gitignore'), StorageSliceCategory.other);
  });

  test('an unknown extension is other', () {
    expect(of('save.dat'), StorageSliceCategory.other);
  });

  test('a dot in the folder name is not the file extension', () {
    // The rule reads the last dot in the *basename*, and the walker hands it
    // one. Asserted here so a future caller handing it a whole path is a
    // failing test rather than every file on the disk becoming a photograph.
    expect(of('report.final.docx'), StorageSliceCategory.documents);
  });

  test('HEIF is a photograph here even though the optimiser refuses it', () {
    // This screen says where the space is, not what can be done about it.
    expect(of('IMG_0002.HEIC'), StorageSliceCategory.photos);
  });
}
