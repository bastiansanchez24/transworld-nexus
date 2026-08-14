import 'package:flutter/widgets.dart';

/// No-op fuera de Windows (web y tests sin bootstrap).
Future<void> bootstrapDesktopWindow() async {}

/// Envuelve [child] con la barra de título propia. En este stub no hace nada.
class DesktopWindowFrame extends StatelessWidget {
  const DesktopWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
