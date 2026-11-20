import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Colori e font presi dal sito francescoferri.me.
class FD {
  static const bg = Color(0xFF0D0D0D);
  static const surface = Color(0xFF161616);
  static const surfaceHigh = Color(0xFF1B1B1B);
  static const line = Color(0x1AFFFFFF); // white/10
  static const lineSoft = Color(0x0DFFFFFF); // white/5
  static const text = Color(0xFFF2F2F2);
  static const muted = Color(0xFF8A8A8A);
  static const accent = Color(0xFF4664FF);
  static const accentHover = Color(0xFF5A72FF);
  static const danger = Color(0xFFEF4444);

  static const display = 'FD Display';
  static const mono = 'Menlo';
  static const monoFallback = ['SF Mono', 'Consolas', 'Cascadia Mono', 'DejaVu Sans Mono', 'monospace'];

  /// Titoli: FD Display, maiuscolo, stretto come sul sito.
  static TextStyle displayStyle(double size, {Color color = text}) =>
      TextStyle(fontFamily: display, fontSize: size, height: 0.9, letterSpacing: size * 0.01, color: color);

  /// Etichette: monospace maiuscolo con tracking largo.
  static TextStyle monoStyle({double size = 11, Color color = muted, FontWeight weight = FontWeight.w500}) => TextStyle(
    fontFamily: mono,
    fontFamilyFallback: monoFallback,
    fontSize: size,
    letterSpacing: size * 0.2,
    fontWeight: weight,
    color: color,
  );
}

/// Link del brand. I parametri UTM fanno vedere in Analytics chi arriva dall'app.
class FDLinks {
  static const _utm = 'utm_source=trasloco&utm_medium=app&utm_campaign=trasloco';

  static final site = Uri.parse('https://www.francescoferri.me/?$_utm');
  static final email = Uri.parse('mailto:info@francescoferri.me?subject=Trasloco');

  static final socials = <({String label, Uri uri})>[
    (label: 'LinkedIn', uri: Uri.parse('https://www.linkedin.com/in/francescoferri97/')),
    (label: 'Instagram', uri: Uri.parse('https://www.instagram.com/fdesign1997')),
    (label: 'Behance', uri: Uri.parse('https://www.behance.net/francescodesign97')),
    (label: 'Facebook', uri: Uri.parse('https://www.facebook.com/share/14v4FfKoxgz/?mibextid=wwXIfr')),
    (label: 'GitHub', uri: Uri.parse('https://github.com/Francisff97')),
  ];
}

Future<void> openLink(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: FD.bg,
    colorScheme: const ColorScheme.dark(
      primary: FD.accent,
      secondary: FD.accent,
      surface: FD.surface,
      onSurface: FD.text,
      error: FD.danger,
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: FD.accent, selectionColor: Color(0x554664FF)),
    sliderTheme: const SliderThemeData(
      activeTrackColor: FD.accent,
      inactiveTrackColor: FD.line,
      thumbColor: FD.text,
      overlayColor: Color(0x224664FF),
      trackHeight: 2,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: FD.surfaceHigh,
        border: Border.all(color: FD.line),
      ),
      textStyle: FD.monoStyle(size: 10, color: FD.text),
    ),
    textTheme: base.textTheme.apply(bodyColor: FD.text, displayColor: FD.text),
  );
}
