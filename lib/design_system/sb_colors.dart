import 'package:flutter/material.dart';

/// Adaptive color that resolves light/dark from [SBColors.brightness].
/// The app root keeps this in sync with the platform brightness, mirroring
/// the UIColor dynamic-provider behaviour of the iOS app.
class _Adaptive extends Color {
  const _Adaptive(this.light, this.dark) : super(0);

  final Color light;
  final Color dark;

  Color get _resolved => SBColors.brightness == Brightness.dark ? dark : light;

  @override
  // ignore: deprecated_member_use
  int get value => _resolved.value;

  @override
  double get a => _resolved.a;
  @override
  double get r => _resolved.r;
  @override
  double get g => _resolved.g;
  @override
  double get b => _resolved.b;
}

Color _rgb(double r, double g, double b, [double a = 1]) =>
    Color.fromRGBO((r * 255).round(), (g * 255).round(), (b * 255).round(), a);

class SBColors {
  SBColors._();

  /// Updated by the app root when the platform brightness changes.
  static Brightness brightness = Brightness.light;

  static bool get isDark => brightness == Brightness.dark;

  // MARK: - Surfaces
  static final Color page =
      _Adaptive(_rgb(0.961, 0.973, 0.992), _rgb(0.041, 0.049, 0.071));
  static final Color white =
      _Adaptive(_rgb(1.0, 1.0, 1.0), _rgb(0.075, 0.086, 0.118));
  static final Color field =
      _Adaptive(_rgb(0.937, 0.957, 0.984), _rgb(0.102, 0.118, 0.157));
  static final Color fieldFocus =
      _Adaptive(_rgb(1.0, 1.0, 1.0), _rgb(0.125, 0.145, 0.188));

  // MARK: - Text
  static final Color navy =
      _Adaptive(_rgb(0.027, 0.075, 0.247), _rgb(0.898, 0.933, 0.988));
  static final Color ink =
      _Adaptive(_rgb(0.039, 0.086, 0.259), _rgb(0.824, 0.875, 0.965));
  static final Color muted =
      _Adaptive(_rgb(0.369, 0.424, 0.557), _rgb(0.686, 0.745, 0.855));
  static final Color softText =
      _Adaptive(_rgb(0.541, 0.596, 0.706), _rgb(0.573, 0.635, 0.753));

  // MARK: - Brand taxonomy (vivid, non-adaptive accents)
  static final Color blue = _rgb(0.027, 0.353, 1.0);
  static final Color deepBlue = _rgb(0.043, 0.227, 0.953);
  static final Color sky = _rgb(0.176, 0.510, 1.0);
  static final Color cyan = _rgb(0.000, 0.804, 0.886);

  // MARK: - Extended vivid spectrum
  static final Color indigo = _rgb(0.345, 0.286, 0.973);
  static final Color violet = _rgb(0.557, 0.243, 0.980);
  static final Color magenta = _rgb(0.949, 0.231, 0.651);
  static final Color pink = _rgb(1.0, 0.353, 0.557);
  static final Color rose = _rgb(1.0, 0.290, 0.420);
  static final Color teal = _rgb(0.000, 0.812, 0.690);
  static final Color mint = _rgb(0.118, 0.871, 0.580);
  static final Color lime = _rgb(0.482, 0.843, 0.176);
  static final Color amber = _rgb(1.0, 0.722, 0.094);
  static final Color coral = _rgb(1.0, 0.451, 0.298);

  // MARK: - Lines
  static final Color line =
      _Adaptive(_rgb(0.906, 0.929, 0.969), _rgb(0.184, 0.208, 0.271));
  static final Color softLine =
      _Adaptive(_rgb(0.933, 0.953, 0.980), _rgb(0.137, 0.157, 0.216));
  static final Color softBlue =
      _Adaptive(_rgb(0.918, 0.953, 1.0), _rgb(0.071, 0.118, 0.220));
  static final Color selectedBlue =
      _Adaptive(_rgb(0.918, 0.949, 1.0), _rgb(0.075, 0.133, 0.251));

  // MARK: - Status and semantic accents
  static final Color green = _rgb(0.063, 0.733, 0.357);
  static final Color greenBg =
      _Adaptive(_rgb(0.918, 0.984, 0.945), _rgb(0.051, 0.180, 0.102));
  static final Color red = _rgb(1.0, 0.231, 0.286);
  static final Color redBg =
      _Adaptive(_rgb(1.0, 0.937, 0.937), _rgb(0.224, 0.067, 0.071));
  static final Color warning = _rgb(0.984, 0.643, 0.043);
  static final Color warningBg =
      _Adaptive(_rgb(1.0, 0.969, 0.902), _rgb(0.216, 0.141, 0.043));
  static final Color purple = _rgb(0.518, 0.271, 0.969);
  static final Color orange = _rgb(1.0, 0.420, 0.075);

  // MARK: - Semantic tints
  static Color get primaryActionTint => blue;
  static Color get questionTint => cyan;
  static Color get summaryTint => purple;
  static Color get successTint => green;
  static Color get decisionTint => orange;

  /// A small lift (lighten) of a color toward white, for gradient highlights.
  static Color lift(Color c, [double amount = 0.18]) =>
      Color.lerp(c, Colors.white, amount) ?? c;

  /// A slight deepen of a color toward black, for gradient depth.
  static Color deepen(Color c, [double amount = 0.16]) =>
      Color.lerp(c, Colors.black, amount) ?? c;

  // MARK: - Gradients
  static LinearGradient get primaryGradient => LinearGradient(
        colors: [sky, blue, indigo],
        stops: const [0.0, 0.55, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get brandGradient => LinearGradient(
        colors: [cyan, blue, violet],
        stops: const [0.0, 0.52, 1.0],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      );

  /// A vivid multi-stop gradient built from any tint — lighter on top-left,
  /// saturated in the middle, deeper at the bottom-right. Gives buttons,
  /// tiles and badges a dimensional, candy-like finish.
  static LinearGradient vividGradient(Color tint) => LinearGradient(
        colors: [lift(tint, 0.22), tint, deepen(tint, 0.18)],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Ordered vivid spectrum used to assign distinct accents and to seed the
  /// animated ambient background.
  static List<Color> get spectrum =>
      [blue, cyan, teal, violet, magenta, amber, lime, indigo];

  /// Colors for the drifting aurora blobs behind every page.
  static List<Color> get auroraColors =>
      [blue, cyan, violet, magenta, teal, amber];

  /// Very subtle top-to-bottom page wash that adds depth behind cards.
  static LinearGradient get pageGradient => LinearGradient(
        colors: [
          _Adaptive(_rgb(0.984, 0.990, 1.0), _rgb(0.047, 0.055, 0.078)),
          page,
          _Adaptive(_rgb(0.945, 0.961, 0.988), _rgb(0.059, 0.071, 0.102)),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  /// Soft tint used as a hero/card accent fill.
  static LinearGradient heroWash(Color tint) => LinearGradient(
        colors: [
          tint.withValues(alpha: 0.22),
          tint.withValues(alpha: 0.06),
          white,
        ],
        stops: const [0.0, 0.45, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Soft diagonal gradient for icon tiles.
  static LinearGradient tileGradient(Color tint) => LinearGradient(
        colors: [tint.withValues(alpha: 0.28), tint.withValues(alpha: 0.12)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Rich diagonal gradient from a base tint to a slightly deeper shade.
  static LinearGradient deepGradient(Color tint) => LinearGradient(
        colors: [lift(tint, 0.16), tint, deepen(tint, 0.2)],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
