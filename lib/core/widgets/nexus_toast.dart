import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_theme.dart';

/// Toast custom via OverlayEntry (HANDOFF §4.11). No usa SnackBar.
class NexusToast {
  NexusToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(BuildContext context, String message) {
    hide();
    final overlay = Overlay.of(context);
    final reduce = AppMotion.reduceMotion(context);

    _entry = OverlayEntry(
      builder: (context) => _ToastBanner(message: message, reduceMotion: reduce),
    );
    overlay.insert(_entry!);
    _timer = Timer(AppMotion.toast, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastBanner extends StatefulWidget {
  const _ToastBanner({required this.message, required this.reduceMotion});

  final String message;
  final bool reduceMotion;

  @override
  State<_ToastBanner> createState() => _ToastBannerState();
}

class _ToastBannerState extends State<_ToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.reduceMotion
          ? const Duration(milliseconds: 150)
          : AppMotion.toast,
    );
    final enterEnd = widget.reduceMotion ? 0.2 : 0.12;
    final exitStart = widget.reduceMotion ? 0.8 : 0.85;

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: AppMotion.ease)),
        weight: enterEnd * 100,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: (exitStart - enterEnd) * 100,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: AppMotion.ease)),
        weight: (1 - exitStart) * 100,
      ),
    ]).animate(_ctrl);

    _offset = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .chain(CurveTween(curve: AppMotion.ease)),
        weight: enterEnd * 100,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: (1 - enterEnd) * 100,
      ),
    ]).animate(_ctrl);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1)
            .chain(CurveTween(curve: AppMotion.ease)),
        weight: enterEnd * 100,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: (1 - enterEnd) * 100,
      ),
    ]).animate(_ctrl);

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 72;
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _offset,
            child: ScaleTransition(
              scale: _scale,
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: AppColors.shadowToast,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Symbols.check_circle_rounded,
                          fill: 1,
                          color: AppColors.toastCheck,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
