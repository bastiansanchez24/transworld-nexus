import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/widgets.dart';

/// Publica el rectángulo del modal para el chrome UIKit solo en iOS.
class AppModalGeometry extends StatelessWidget {
  const AppModalGeometry({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) return child;
    return CNSheetGeometryProbe(child: child);
  }
}
