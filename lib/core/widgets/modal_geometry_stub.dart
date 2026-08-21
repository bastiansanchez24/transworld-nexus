import 'package:flutter/widgets.dart';

/// En web no hay PlatformView UIKit que coordinar.
class AppModalGeometry extends StatelessWidget {
  const AppModalGeometry({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
