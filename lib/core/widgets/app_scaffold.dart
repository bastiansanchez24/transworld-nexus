import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tw_tokens.dart';
import '../theme/browser_theme_color.dart';
import 'offline_banner.dart';
import 'tw_components.dart';

/// Plantilla push: header sticky con blur (HANDOFF §4.8).
///
/// El cuerpo se ancla arriba, no al centro: un formulario corto
/// arranca igual que crear o editar evento.
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
    return BrowserThemeColor(
      color: TwColors.bg,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: TwColors.bg,
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
      ),
    );
  }

  Widget _constrained(Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}

/// Acción de la cabecera push (atrás, editar, eliminar…).
///
/// Es [TwIconButton] con el nombre que ya usan las pantallas: mismo botón que
/// los menús de evento y evento de leads, para que la app no tenga dos estilos de
/// cabecera conviviendo.
class NexusHeaderAction extends StatelessWidget {
  const NexusHeaderAction({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.loading = false,
    this.danger = false,
  });

  /// Lado del botón. También es el ancho de los huecos que deja la cabecera
  /// cuando no hay botón, para que el título siga centrado.
  static const double size = 44;

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool loading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return TwIconButton(
      icon: icon,
      iconSize: 20,
      size: size,
      onTap: onTap,
      tooltip: tooltip,
      loading: loading,
      danger: danger,
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
      child: TwGlassFilter(
        sigma: 12,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            TwSpacing.screenH,
            top + 14,
            TwSpacing.screenH,
            14,
          ),
          decoration: BoxDecoration(
            color: TwColors.bg.withValues(alpha: 0.92),
            border: const Border(
              bottom: BorderSide(color: TwColors.border07, width: 1),
            ),
          ),
          child: Row(
            children: [
              if (puedeVolver)
                NexusHeaderAction(
                  icon: Symbols.arrow_back_rounded,
                  tooltip: 'Volver',
                  onTap: () => context.pop(),
                )
              else
                const SizedBox(width: NexusHeaderAction.size),
              const SizedBox(width: 10),
              Expanded(
                child: DefaultTextStyle(
                  style: TwText.tileTitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  child: Semantics(
                    header: true,
                    child:
                        titleWidget ??
                        Text(title ?? '', textAlign: TextAlign.center),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (actions != null && actions!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      actions![i],
                    ],
                  ],
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
