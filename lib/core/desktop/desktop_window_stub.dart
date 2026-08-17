import 'package:flutter/widgets.dart';

/// No-op fuera de Windows (web y tests sin bootstrap).
Future<void> bootstrapDesktopWindow() async {}

/// El caption es el nativo de Windows. En este stub no hay chrome extra.
class DesktopWindowFrame extends StatelessWidget {
  const DesktopWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
