import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Barra de título branded de RegisPro. Sin plugins: el host de Windows
/// inyecta arrastre nativo con [wrapDrag] y las acciones de ventana.
class WindowsTitleBar extends StatelessWidget {
  const WindowsTitleBar({
    super.key,
    this.isMaximized = false,
    this.onMinimize,
    this.onToggleMaximize,
    this.onClose,
    this.wrapDrag = _passthrough,
  });

  static const height = 36.0;

  static Widget _passthrough(Widget child) => child;

  final bool isMaximized;
  final VoidCallback? onMinimize;
  final VoidCallback? onToggleMaximize;
  final VoidCallback? onClose;
  final Widget Function(Widget child) wrapDrag;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryDeep,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: wrapDrag(
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: onToggleMaximize,
                  child: const _TitleBrand(),
                ),
              ),
            ),
            WindowsCaptionButton(
              tooltip: 'Minimizar',
              onPressed: onMinimize,
              child: const _CaptionGlyph.minimize(),
            ),
            WindowsCaptionButton(
              tooltip: isMaximized ? 'Restaurar' : 'Maximizar',
              onPressed: onToggleMaximize,
              child: isMaximized
                  ? const _CaptionGlyph.restore()
                  : const _CaptionGlyph.maximize(),
            ),
            WindowsCaptionButton(
              tooltip: 'Cerrar',
              danger: true,
              onPressed: onClose,
              child: const _CaptionGlyph.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBrand extends StatelessWidget {
  const _TitleBrand();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: WindowsTitleBar.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Image.asset(
              'assets/images/logo_nexus_transparente.png',
              height: 18,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox(width: 18, height: 18),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'RegisPro',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de caption estilo Windows (46×alto de barra), con hover rojo en cerrar.
class WindowsCaptionButton extends StatefulWidget {
  const WindowsCaptionButton({
    super.key,
    required this.child,
    required this.tooltip,
    this.onPressed,
    this.danger = false,
  });

  static const width = 46.0;

  final Widget child;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  State<WindowsCaptionButton> createState() => _WindowsCaptionButtonState();
}

class _WindowsCaptionButtonState extends State<WindowsCaptionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered && widget.onPressed != null;
    final background = !hovered
        ? Colors.transparent
        : (widget.danger
              ? AppColors.danger
              : Colors.white.withValues(alpha: 0.10));

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Semantics(
            button: true,
            label: widget.tooltip,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: WindowsCaptionButton.width,
              height: WindowsTitleBar.height,
              color: background,
              alignment: Alignment.center,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptionGlyph extends StatelessWidget {
  const _CaptionGlyph.minimize() : _kind = _CaptionKind.minimize;
  const _CaptionGlyph.maximize() : _kind = _CaptionKind.maximize;
  const _CaptionGlyph.restore() : _kind = _CaptionKind.restore;
  const _CaptionGlyph.close() : _kind = _CaptionKind.close;

  final _CaptionKind _kind;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(10, 10),
      painter: _CaptionGlyphPainter(_kind),
    );
  }
}

enum _CaptionKind { minimize, maximize, restore, close }

class _CaptionGlyphPainter extends CustomPainter {
  const _CaptionGlyphPainter(this.kind);

  final _CaptionKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    switch (kind) {
      case _CaptionKind.minimize:
        canvas.drawLine(
          Offset(0, size.height / 2),
          Offset(size.width, size.height / 2),
          paint,
        );
      case _CaptionKind.maximize:
        canvas.drawRect(Offset.zero & size, paint);
      case _CaptionKind.restore:
        canvas
          ..drawRect(const Rect.fromLTWH(2, 0, 8, 8), paint)
          ..drawRect(const Rect.fromLTWH(0, 2, 8, 8), paint);
      case _CaptionKind.close:
        canvas
          ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
          ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CaptionGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
