import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';
import 'windows_title_bar.dart';

/// Se activa solo tras [bootstrapDesktopWindow], para que los tests y
/// Android/iOS (mismo `dart:io`) no monten chrome ni toquen el plugin.
var _desktopWindowChromeEnabled = false;

Future<void> bootstrapDesktopWindow() async {
  if (!Platform.isWindows) return;

  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(900, 600),
    center: true,
    backgroundColor: AppColors.primaryDeep,
    skipTaskbar: false,
    title: 'RegisPro',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(options);

  _desktopWindowChromeEnabled = true;
}

/// Barra de título propia encima del navigator. Identidad en toda la app.
class DesktopWindowFrame extends StatelessWidget {
  const DesktopWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!_desktopWindowChromeEnabled) return child;
    return Column(
      children: [
        const _WindowsTitleBarHost(),
        Expanded(child: child),
      ],
    );
  }
}

class _WindowsTitleBarHost extends StatefulWidget {
  const _WindowsTitleBarHost();

  @override
  State<_WindowsTitleBarHost> createState() => _WindowsTitleBarHostState();
}

class _WindowsTitleBarHostState extends State<_WindowsTitleBarHost>
    with WindowListener {
  var _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (!mounted || maximized == _maximized) return;
    setState(() => _maximized = maximized);
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  void onWindowMaximize() {
    if (!mounted) return;
    setState(() => _maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (!mounted) return;
    setState(() => _maximized = false);
  }

  @override
  Widget build(BuildContext context) {
    return WindowsTitleBar(
      isMaximized: _maximized,
      onMinimize: () => windowManager.minimize(),
      onToggleMaximize: _toggleMaximize,
      onClose: () => windowManager.close(),
      wrapDrag: (child) => DragToMoveArea(child: child),
    );
  }
}
