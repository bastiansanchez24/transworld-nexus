import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/splash_providers.dart';

/// Pantalla de arranque: draw-on del mark Transworld mientras se restaura
/// la sesión / perfil.
///
/// Reproduce [assets/motion/transworld-logo-draw.json] una sola vez y se
/// detiene en el hold (~2100 ms), sin el exit del loop de preview.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _asset = 'assets/motion/transworld-logo-draw.json';
  static const _totalMs = 2500.0;
  static const _holdMs = 2100.0;
  static const _holdProgress = _holdMs / _totalMs;

  late final AnimationController _controller;
  Timer? _fallbackTimer;
  var _markedReady = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    // Si el asset no carga (tests / fallo de I/O), no bloquear el router.
    _fallbackTimer = Timer(const Duration(milliseconds: 2500), _markReady);
  }

  void _onTick() {
    if (_markedReady) return;
    if (_controller.value >= _holdProgress) {
      _controller.stop();
      _controller.value = _holdProgress;
      _markReady();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _markReady();
    }
  }

  void _markReady() {
    if (_markedReady || !mounted) return;
    _markedReady = true;
    _fallbackTimer?.cancel();
    ref.read(splashReadyProvider.notifier).state = true;
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller
      ..removeListener(_onTick)
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.54;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Transform.translate(
          // Nudge óptico ~3.7% del mark box (spec §2).
          offset: Offset(0, width * 0.037),
          child: Lottie.asset(
            _asset,
            controller: _controller,
            width: width,
            height: width,
            fit: BoxFit.contain,
            frameRate: FrameRate.max,
            onLoaded: (composition) {
              _controller
                ..duration = composition.duration
                ..forward();
            },
          ),
        ),
      ),
    );
  }
}
