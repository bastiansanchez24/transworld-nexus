import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';
import 'desktop_window_metrics.dart';

Future<void> bootstrapDesktopWindow() async {
  if (!Platform.isWindows) return;

  await windowManager.ensureInitialized();

  final sizes = await _resolveWindowSizes();

  final options = WindowOptions(
    size: sizes.size,
    minimumSize: sizes.minSize,
    center: true,
    backgroundColor: AppColors.background,
    skipTaskbar: false,
    title: 'RegisPro',
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
  );

  await windowManager.waitUntilReadyToShow(options);
}

Future<({Size size, Size minSize})> _resolveWindowSizes() async {
  try {
    final display = await screenRetriever.getPrimaryDisplay();
    final work = display.visibleSize ?? display.size;
    final scale = (display.scaleFactor ?? 1).toDouble();
    return (
      size: DesktopWindowMetrics.defaultSizeForWorkArea(work),
      minSize: DesktopWindowMetrics.minSizeFor(
        workArea: work,
        scaleFactor: scale,
      ),
    );
  } catch (_) {
    return (
      size: DesktopWindowMetrics.fallbackSize,
      minSize: DesktopWindowMetrics.minSize,
    );
  }
}

/// El caption es el nativo de Windows. No se pinta otra barra en Flutter.
class DesktopWindowFrame extends StatelessWidget {
  const DesktopWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
