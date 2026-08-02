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
    required this.slices,
    required this.sliceOther,
    required this.sliceSystem,
  });

  /// The colour the app grows out of, read out of the app icon's own field.
  ///
  /// Not chosen beside the icon but taken from it — `tool/brand_assets.py`
  /// prints this number, and the launcher's adaptive background and the window
  /// behind a starting app are set from the same one. Three places that have to
  /// agree, because where they disagree the icon arrives framed by the
  /// difference: a bright square inside a pale one, which is what the whole
  /// exercise was to avoid.
  ///
  /// Muted rather than the artwork's original blue. Every colour below was
  /// pulled into the same register: this is a tool people run on their own
  /// files, and it should look like something that has been used for years
  /// rather than something demanding attention.
  static const Color seed = Color(0xFF5572A1);

  /// The field the app launches from, and the text that sits on it.
  ///
  /// Statics rather than members of the extension, because they are the one
  /// pair here that is the same in both themes and has to be: they match
  /// `@color/splash_background` in `android/app/src/main/res/values/colors.xml`
  /// and the icon's own background, neither of which knows what theme the phone
  /// is in. A light and a dark answer would mean the window the system draws
  /// and the first frame Flutter draws disagreeing half the time.
  static const Color launchBackground = seed;
  static const Color onLaunchBackground = Color(0xFFFFFFFF);

  static const Color _dangerLight = Color(0xFFA34A42);
  static const Color _dangerDark = Color(0xFFE0938C);
  static const Color _onDangerLight = Color(0xFFFFFFFF);
  static const Color _onDangerDark = Color(0xFF2E1211);
  static const Color _dangerContainerLight = Color(0xFFF3E4E2);
  static const Color _dangerContainerDark = Color(0xFF3A211F);

  static const Color _freedLight = Color(0xFF2F6B55);
  static const Color _freedDark = Color(0xFF8CC9AF);

  static const Color _cautionLight = Color(0xFF8A6A3C);
  static const Color _cautionDark = Color(0xFFD8B57E);

  static const Color _protectedLight = Color(0xFF5A6472);
  static const Color _protectedDark = Color(0xFF9AA5B4);

  /// The five hues the storage breakdown draws its categories in.
  ///
  /// The only place in this app where colour carries identity rather than
  /// meaning, which is a different problem and was solved by measurement rather
  /// than by eye. Both rows were run through the data-viz validator against
  /// this app's own surfaces — `#f9f9ff` and `#111318` — and clear every gate:
  /// the lightness band, the chroma floor, adjacent separation under protan,
  /// deutan and tritan simulation, the normal-vision floor, and 3:1 against the
  /// surface. Muted to sit in the same register as everything else here, and no
  /// further: two earlier attempts at the app's own quietness failed the chroma
  /// floor outright, which is the validator's way of saying they read as grey.
  ///
  /// The order is the safety mechanism and is not cosmetic. Adjacent slots are
  /// what a stacked ring puts next to each other, and they are the pairs the
  /// separation gates measure — reordering this list means running the
  /// validator again. Worst tritan separation is 6.0, inside the band that is
  /// only legal with a second channel, which is why every slice carries a
  /// visible label and every segment a gap.
  ///
  /// The dark row is the same five hues stepped for the dark surface, not a
  /// separate palette and not an automatic lightening.
  static const List<Color> _slicesLight = <Color>[
    Color(0xFF3070B8),
    Color(0xFFCF6220),
    Color(0xFF17906B),
    Color(0xFFAD8000),
    Color(0xFFC25C8A),
  ];

  static const List<Color> _slicesDark = <Color>[
    Color(0xFF4D86CC),
    Color(0xFFCC6F34),
    Color(0xFF28A37F),
    Color(0xFFB28A08),
    Color(0xFFC96992),
  ];

  /// Everything that fitted no category, and everything the app could not look
  /// inside. Grey on purpose: neither is a *kind* of file, and giving them a
  /// hue would put them in competition with the five that are.
  static const Color _sliceOtherLight = Color(0xFF6F737B);
  static const Color _sliceOtherDark = Color(0xFF8B8F98);
  static const Color _sliceSystemLight = Color(0xFFA6A9B2);
  static const Color _sliceSystemDark = Color(0xFF5A5E66);

  /// Deleting, and only deleting. Nothing else in the app is allowed to be red,
  /// or the one button that cannot be taken back stops standing out.
  final Color danger;
  final Color onDanger;

  /// The wash behind a warning, not the warning itself.
  final Color dangerContainer;

  /// How much space a run gave back. The single number the user came for.
  ///
  /// The one green left in a blue app, and it stays green for that reason: on a
  /// muted blue it is the only warm-shifted thing on the screen, which is more
  /// attention than it got when the whole app was green.
  final Color freed;

  /// A category that is junk by the letter and might not be by intent — the
  /// recycle bin, downloaded installers. Amber because it wants a second look,
  /// not because it is dangerous.
  final Color caution;

  /// Something found and deliberately left alone. Deliberately quiet: it is
  /// there to be reassuring, not to be read.
  final Color protectedAccent;

  /// Identity colours for the storage breakdown, in the order the slots are
  /// assigned. Read by index and never cycled: a sixth category is `sliceOther`
  /// rather than the first hue used twice.
  final List<Color> slices;

  /// Measured, but no kind anybody named.
  final Color sliceOther;

  /// Used space the walk could not see into.
  final Color sliceSystem;

  static const AppColors light = AppColors(
    danger: _dangerLight,
    onDanger: _onDangerLight,
    dangerContainer: _dangerContainerLight,
    freed: _freedLight,
    caution: _cautionLight,
    protectedAccent: _protectedLight,
    slices: _slicesLight,
    sliceOther: _sliceOtherLight,
    sliceSystem: _sliceSystemLight,
  );

  static const AppColors dark = AppColors(
    danger: _dangerDark,
    onDanger: _onDangerDark,
    dangerContainer: _dangerContainerDark,
    freed: _freedDark,
    caution: _cautionDark,
    protectedAccent: _protectedDark,
    slices: _slicesDark,
    sliceOther: _sliceOtherDark,
    sliceSystem: _sliceSystemDark,
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
    List<Color>? slices,
    Color? sliceOther,
    Color? sliceSystem,
  }) {
    return AppColors(
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      freed: freed ?? this.freed,
      caution: caution ?? this.caution,
      protectedAccent: protectedAccent ?? this.protectedAccent,
      slices: slices ?? this.slices,
      sliceOther: sliceOther ?? this.sliceOther,
      sliceSystem: sliceSystem ?? this.sliceSystem,
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
      slices: <Color>[
        for (int index = 0; index < slices.length; index++)
          Color.lerp(slices[index], other.slices[index], t)!,
      ],
      sliceOther: Color.lerp(sliceOther, other.sliceOther, t)!,
      sliceSystem: Color.lerp(sliceSystem, other.sliceSystem, t)!,
    );
  }
}
