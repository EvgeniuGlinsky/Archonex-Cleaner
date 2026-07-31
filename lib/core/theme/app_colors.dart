import 'package:flutter/material.dart';

/// Every colour literal in the application.
///
/// `Color(0x…)` appears here and nowhere else. A widget that needs a colour
/// Material does not define reads it from the [AppColors] extension on the
/// current theme — `Theme.of(context).extension<AppColors>()!` — so the light
/// and dark answers are chosen in one place instead of at each call site.
///
/// A `ThemeExtension` rather than a pair of static getters taking a
/// [Brightness]: the getters compile just as well and quietly return the light
/// colour inside a dark dialog, because nothing forces the caller to pass the
/// brightness that is actually in effect.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.freed,
    required this.caution,
    required this.protectedAccent,
  });

  /// The colour the app grows out of. Green rather than the Converter's blue:
  /// the two are siblings, not the same product.
  static const Color seed = Color(0xFF17A47B);

  static const Color _dangerLight = Color(0xFFB3261E);
  static const Color _dangerDark = Color(0xFFFF7B72);
  static const Color _onDangerLight = Color(0xFFFFFFFF);
  static const Color _onDangerDark = Color(0xFF3B0906);
  static const Color _dangerContainerLight = Color(0xFFFCE8E6);
  static const Color _dangerContainerDark = Color(0xFF4A1512);

  static const Color _freedLight = Color(0xFF11785A);
  static const Color _freedDark = Color(0xFF5FE3B4);

  static const Color _cautionLight = Color(0xFF9A6400);
  static const Color _cautionDark = Color(0xFFFFC65C);

  static const Color _protectedLight = Color(0xFF5A6472);
  static const Color _protectedDark = Color(0xFF9AA5B4);

  /// Deleting, and only deleting. Nothing else in the app is allowed to be red,
  /// or the one button that cannot be taken back stops standing out.
  final Color danger;
  final Color onDanger;

  /// The wash behind a warning, not the warning itself.
  final Color dangerContainer;

  /// How much space a run gave back. The single number the user came for.
  final Color freed;

  /// A category that is junk by the letter and might not be by intent — the
  /// recycle bin, downloaded installers. Amber because it wants a second look,
  /// not because it is dangerous.
  final Color caution;

  /// Something found and deliberately left alone. Deliberately quiet: it is
  /// there to be reassuring, not to be read.
  final Color protectedAccent;

  static const AppColors light = AppColors(
    danger: _dangerLight,
    onDanger: _onDangerLight,
    dangerContainer: _dangerContainerLight,
    freed: _freedLight,
    caution: _cautionLight,
    protectedAccent: _protectedLight,
  );

  static const AppColors dark = AppColors(
    danger: _dangerDark,
    onDanger: _onDangerDark,
    dangerContainer: _dangerContainerDark,
    freed: _freedDark,
    caution: _cautionDark,
    protectedAccent: _protectedDark,
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? freed,
    Color? caution,
    Color? protectedAccent,
  }) {
    return AppColors(
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      freed: freed ?? this.freed,
      caution: caution ?? this.caution,
      protectedAccent: protectedAccent ?? this.protectedAccent,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) {
      return this;
    }

    return AppColors(
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      freed: Color.lerp(freed, other.freed, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      protectedAccent:
          Color.lerp(protectedAccent, other.protectedAccent, t)!,
    );
  }
}
