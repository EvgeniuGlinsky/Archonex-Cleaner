/// The things this app does to a device's storage.
///
/// The list is on the home screen from the first release, with the second entry
/// visibly not finished yet, because the product is two tools and a screen
/// showing one of them teaches the user that it is one. Shipping the card as a
/// promise costs a badge; shipping it later costs re-teaching them what the app
/// is.
enum AppTool {
  cleaner(isAvailable: true),

  /// Walks the device for photos and videos and rewrites them smaller. Not
  /// built: the card explains itself and does not open.
  optimizer(isAvailable: false);

  const AppTool({required this.isAvailable});

  /// Whether tapping the card does anything. A field rather than a check at the
  /// call site, so the badge and the disabled tap cannot disagree.
  final bool isAvailable;
}
