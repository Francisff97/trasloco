import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'brand.dart';
import 'strings.dart';
import 'widgets.dart';

/// Barra in alto: icona, nome e frase dell'app.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, required this.tagline, required this.onAbout});

  final String title;
  final String tagline;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.only(left: Platform.isMacOS ? 88 : 28, right: 28),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FD.lineSoft)),
      ),
      child: Row(
        children: [
          const AppIcon(size: 28),
          const SizedBox(width: 14),
          Text(title.toUpperCase(), style: FD.displayStyle(24)),
          const SizedBox(width: 16),
          Container(width: 1, height: 18, color: FD.line),
          const SizedBox(width: 16),
          Expanded(
            child: Text(tagline.toUpperCase(), style: FD.monoStyle(size: 10), overflow: TextOverflow.ellipsis),
          ),
          FDTextLink(label: S.current.about, onTap: onAbout),
        ],
      ),
    );
  }
}

/// Piè di pagina con i link di Francesco Design.
class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: FD.lineSoft)),
      ),
      child: Row(
        children: [
          FDTextLink(label: '© ${DateTime.now().year} Francesco Design', size: 10, onTap: () => openLink(FDLinks.site)),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              s.free,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: FD.muted),
            ),
          ),
          for (final social in FDLinks.socials) ...[
            const SizedBox(width: 18),
            FDTextLink(label: social.label, size: 10, onTap: () => openLink(social.uri)),
          ],
          const SizedBox(width: 18),
          Container(width: 1, height: 14, color: FD.line),
          const SizedBox(width: 18),
          FDTextLink(label: 'francescoferri.me', size: 10, arrow: true, onTap: () => openLink(FDLinks.site)),
        ],
      ),
    );
  }
}

/// Finestra "Info" con chi ha fatto l'app.
void showAboutApp(BuildContext context, {required String title, required String tagline, required String body}) {
  final s = S.current;
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (context) => Dialog(
      backgroundColor: FD.surface,
      shape: const RoundedRectangleBorder(side: BorderSide(color: FD.line)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FDLogo(height: 56),
              const SizedBox(height: 28),
              Text(title.toUpperCase(), style: FD.displayStyle(44)),
              const SizedBox(height: 8),
              Text(tagline.toUpperCase(), style: FD.monoStyle(size: 10, color: FD.accent)),
              const SizedBox(height: 24),
              Text(body, style: const TextStyle(fontSize: 14, height: 1.6, color: FD.text)),
              const SizedBox(height: 16),
              Text(s.free, style: const TextStyle(fontSize: 13, height: 1.5, color: FD.muted)),
              const SizedBox(height: 28),
              Container(height: 1, color: FD.line),
              const SizedBox(height: 20),
              Text(s.madeBy.toUpperCase(), style: FD.monoStyle(size: 10, color: FD.text)),
              const SizedBox(height: 4),
              Text(s.madeBySub, style: const TextStyle(fontSize: 13, color: FD.muted)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FDButton(label: 'francescoferri.me', onPressed: () => openLink(FDLinks.site)),
                  FDButton(label: s.writeMe, onPressed: () => openLink(FDLinks.email)),
                  FDButton(label: s.close, onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Campo di testo sottolineato, come in Snella.
class FDField extends StatelessWidget {
  const FDField({
    super.key,
    required this.controller,
    this.hint,
    this.mono = false,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? hint;
  final bool mono;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: mono
          ? FD.monoStyle(size: 12, color: FD.text).copyWith(letterSpacing: 0.4)
          : const TextStyle(fontSize: 14, color: FD.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: FD.muted.withValues(alpha: 0.6)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: FD.line)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: FD.accent)),
        disabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: FD.lineSoft)),
      ),
      onSubmitted: onSubmitted,
      onChanged: onChanged,
    );
  }
}
