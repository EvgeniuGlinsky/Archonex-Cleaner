/// The four powers of 1024 the whole app counts in.
///
/// Their own class rather than constants on `FileSizeFormatter`, because the
/// clean and quarantine policies are written in gigabytes and megabytes too,
/// and a second definition of a kilobyte is how two screens end up disagreeing
/// about what a file weighs.
class AppByteUnits {
  const AppByteUnits._();

  static const int kilobyte = 1024;
  static const int megabyte = kilobyte * kilobyte;
  static const int gigabyte = megabyte * kilobyte;
  static const int terabyte = gigabyte * kilobyte;
}
