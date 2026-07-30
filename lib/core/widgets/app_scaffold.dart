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

/// Chip cuadrado de la cabecera push.
///
/// Lo usan tanto el botón "atrás" como las acciones de la derecha (eliminar),
/// para que no queden asimétricos: antes el atrás era un chip con borde y la
/// acción un `IconButton` desnudo, que además imponía su `minHeight` de 48 y
/// hacía que la barra midiera distinto según hubiera o no botón eliminar.
class NexusHeaderAction extends StatelessWidget {
  const NexusHeaderAction({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.loading = false,
    this.danger = false,
  });

  /// Lado del chip. También es el ancho de los huecos que deja la cabecera
  /// cuando no hay botón, para que el título siga centrado.
  static const double size = 40;

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool loading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null && !loading;
    final color = !habilitado
        ? AppColors.textTertiary
        : (danger ? AppColors.danger : AppColors.ink);

    Widget chip = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18, color: color),
    );

    if (habilitado) {
      chip = Pressable(scale: 0.92, onTap: onTap, child: chip);
    }

    if (tooltip != null) {
      chip = Tooltip(message: tooltip!, child: chip);
    }

    return Semantics(button: true, label: tooltip, child: chip);
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
          padding: EdgeInsets.fromLTRB(12, top + 14, 12, 14),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.92),
            border: const Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              if (puedeVolver)
                NexusHeaderAction(
                  icon: Symbols.arrow_back_ios_new_rounded,
                  tooltip: 'Volver',
                  onTap: () => context.pop(),
                )
              else
                const SizedBox(width: NexusHeaderAction.size),
              Expanded(
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontSize: 16,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                )
              else
                const SizedBox(width: NexusHeaderAction.size),
            ],
          ),
        ),
      ),
    );
  }
}
