import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_theme.dart';
import 'offline_banner.dart';
import 'pressable.dart';

/// Plantilla push: header sticky con blur (HANDOFF §4.8).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.headerBottom,
    this.floatingActionButton,
    this.maxContentWidth = 760,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? headerBottom;
  final Widget? floatingActionButton;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: floatingActionButton,
        body: Column(
          children: [
            const OfflineBanner(),
            _PushHeader(
              title: title,
              titleWidget: titleWidget,
              actions: actions,
            ),
            if (headerBottom != null)
              _constrained(
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: headerBottom!,
                ),
              ),
            Expanded(child: _constrained(body)),
          ],
        ),
      ),
    );
  }

  Widget _constrained(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}

class _PushHeader extends StatelessWidget {
  const _PushHeader({this.title, this.titleWidget, this.actions});

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final puedeVolver = context.canPop();
    final top = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(12, top + 6, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.92),
            border: const Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              if (puedeVolver)
                Pressable(
                  scale: 0.92,
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Symbols.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppColors.ink,
                    ),
                  ),
                )
              else
                const SizedBox(width: 36),
              Expanded(
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  child: Semantics(
                    header: true,
                    child: titleWidget ?? Text(title ?? '', textAlign: TextAlign.center),
                  ),
                ),
              ),
              if (actions != null && actions!.isNotEmpty)
                SizedBox(
                  width: 36,
                  child: IconTheme(
                    data: const IconThemeData(color: AppColors.ink, size: 22),
                    child: actions!.length == 1
                        ? actions!.first
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions!,
                          ),
                  ),
                )
              else
                const SizedBox(width: 36),
            ],
          ),
        ),
      ),
    );
  }
}
