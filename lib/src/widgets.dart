import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'brand.dart';

/// Pulsante nello stile del sito: bordo sottile, testo mono maiuscolo,
/// al passaggio del mouse si inverte.
class FDButton extends StatefulWidget {
  const FDButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.big = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool big;
  final IconData? icon;

  @override
  State<FDButton> createState() => _FDButtonState();
}

class _FDButtonState extends State<FDButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final Color bg;
    final Color fg;
    final Color border;
    if (!enabled) {
      bg = Colors.transparent;
      fg = FD.muted.withValues(alpha: 0.5);
      border = FD.line;
    } else if (widget.filled) {
      bg = _hover ? FD.accentHover : FD.accent;
      fg = Colors.white;
      border = bg;
    } else {
      bg = _hover ? FD.text : Colors.transparent;
      fg = _hover ? FD.bg : FD.text;
      border = _hover ? FD.text : FD.text.withValues(alpha: 0.6);
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: widget.big ? 28 : 18, vertical: widget.big ? 20 : 12),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: widget.big ? 16 : 14, color: fg),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  widget.label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: FD.monoStyle(size: widget.big ? 12 : 10.5, color: fg, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Link testuale mono, si accende al passaggio del mouse.
class FDTextLink extends StatefulWidget {
  const FDTextLink({super.key, required this.label, required this.onTap, this.size = 10.5, this.arrow = false});

  final String label;
  final VoidCallback onTap;
  final double size;
  final bool arrow;

  @override
  State<FDTextLink> createState() => _FDTextLinkState();
}

class _FDTextLinkState extends State<FDTextLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: FD.monoStyle(size: widget.size, color: _hover ? FD.text : FD.muted),
          child: Text('${widget.label.toUpperCase()}${widget.arrow ? ' ↗' : ''}'),
        ),
      ),
    );
  }
}

/// Etichetta di sezione: "01 — FORMATO"
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.number, this.text, {super.key});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(number, style: FD.monoStyle(size: 10, color: FD.accent)),
          const SizedBox(width: 10),
          Container(width: 16, height: 1, color: FD.line),
          const SizedBox(width: 10),
          Expanded(child: Text(text.toUpperCase(), style: FD.monoStyle(size: 10))),
        ],
      ),
    );
  }
}

/// Piccolo selettore quadrato (larghezze, formato).
class FDChip extends StatefulWidget {
  const FDChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<FDChip> createState() => _FDChipState();
}

class _FDChipState extends State<FDChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? FD.text : Colors.transparent,
            border: Border.all(color: selected ? FD.text : (_hover ? FD.muted : FD.line)),
          ),
          child: Text(
            widget.label,
            style: FD.monoStyle(
              size: 11,
              color: selected ? FD.bg : (_hover ? FD.text : FD.muted),
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Riga con interruttore minimale.
class FDToggle extends StatelessWidget {
  const FDToggle({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: value ? FD.accent : Colors.transparent,
                  border: Border.all(color: value ? FD.accent : FD.muted),
                ),
                child: value ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 13, color: enabled ? FD.text : FD.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il monogramma FD.
class FDLogo extends StatelessWidget {
  const FDLogo({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/brand/fd.svg', height: height, semanticsLabel: 'Francesco Design');
}

/// L'icona dell'app, con gli angoli arrotondati.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.22),
    child: SvgPicture.asset('assets/brand/trasloco.svg', width: size, height: size, semanticsLabel: 'Trasloco'),
  );
}
