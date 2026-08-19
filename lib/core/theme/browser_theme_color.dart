import 'package:flutter/widgets.dart';

import 'browser_theme_color_stub.dart'
    if (dart.library.js_interop) 'browser_theme_color_web.dart'
    as impl;

/// Actualiza el `<meta name="theme-color">` del navegador.
///
/// En nativo es un no-op. En web tiñe la barra superior (Chrome Android / PWA).
void setBrowserThemeColor(Color color) => impl.setBrowserThemeColor(color);

/// Sincroniza el theme-color del navegador con [color] mientras el widget
/// esté montado.
class BrowserThemeColor extends StatefulWidget {
  const BrowserThemeColor({
    super.key,
    required this.color,
    required this.child,
  });

  final Color color;
  final Widget child;

  @override
  State<BrowserThemeColor> createState() => _BrowserThemeColorState();
}

class _BrowserThemeColorState extends State<BrowserThemeColor> {
  @override
  void initState() {
    super.initState();
    setBrowserThemeColor(widget.color);
  }

  @override
  void didUpdateWidget(covariant BrowserThemeColor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      setBrowserThemeColor(widget.color);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
