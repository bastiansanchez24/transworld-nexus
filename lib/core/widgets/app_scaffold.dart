import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tw_tokens.dart';
import '../theme/browser_theme_color.dart';
import 'ios_native_chrome.dart';
import 'tw_components.dart';

/// El pop interactivo de iOS (deslizar desde el borde) exige `canPop: true`.
///
/// Con [hasWillPop] el botón atrás de la cabecera sigue pidiendo confirmación;
/// el gesto nativo no se apaga. En Android/web el sistema back sí se intercepta.
bool scaffoldAllowsInteractivePop({
  required bool hasWillPop,
  bool? isWeb,
  TargetPlatform? platform,
}) {
  if (!hasWillPop) return true;
  if (isWeb ?? kIsWeb) return false;
  final resolved = platform ?? defaultTargetPlatform;
  return resolved == TargetPlatform.iOS || resolved == TargetPlatform.macOS;
}

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
    this.onWillPop,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? headerBottom;
  final Widget? floatingActionButton;
  final double maxContentWidth;

  /// Si no es null, intercepta el botón atrás de la cabecera (y el back
  /// del sistema en Android). En iOS nativo el gesto de deslizar se deja
  /// pasar: `canPop: false` apaga el pop interactivo de [CupertinoPage].
  final Future<bool> Function()? onWillPop;

  Future<void> _intentarVolver(BuildContext context) async {
    if (onWillPop != null) {
      final salir = await onWillPop!();
      if (!salir || !context.mounted) return;
    }
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = scaffoldAllowsInteractivePop(hasWillPop: onWillPop != null);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || onWillPop == null) return;
        final salir = await onWillPop!();
        if (salir && context.mounted) context.pop();
      },
      child: BrowserThemeColor(
        color: TwColors.bg,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: TwColors.bg,
            floatingActionButton: floatingActionButton,
            body: Column(
              children: [
                _PushHeader(
                  title: title,
                  titleWidget: titleWidget,
                  actions: actions,
                  mostrarAtras: onWillPop != null || context.canPop(),
                  onBack: () => _intentarVolver(context),
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
/// En iOS es el botón Liquid Glass nativo; en el resto, el mismo chip
/// [TwIconButton] que los menús de evento, para que la app no tenga dos
/// estilos de cabecera conviviendo.
class NexusHeaderAction extends StatelessWidget {
  const NexusHeaderAction({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.loading = false,
    this.danger = false,
    this.variant = TwIconButtonStyle.plain,
    this.sfSymbol,
  });

  /// Lado del botón. También es el ancho de los huecos que deja la cabecera
  /// cuando no hay botón, para que el título siga centrado.
  static const double size = 44;

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool loading;
  final bool danger;
  final TwIconButtonStyle variant;

  /// SF Symbol nativo (atrás, lápiz, papelera…). Si falta se infiere.
  final String? sfSymbol;

  @override
  Widget build(BuildContext context) {
    return TwIosGlassIconButton(
      icon: icon,
      iconSize: 20,
      size: size,
      variant: variant,
      onTap: onTap,
      tooltip: tooltip,
      loading: loading,
      danger: danger,
      sfSymbol: sfSymbol,
    );
  }
}

class _PushHeader extends StatelessWidget {
  const _PushHeader({
    this.title,
    this.titleWidget,
    this.actions,
    required this.mostrarAtras,
    required this.onBack,
  });

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool mostrarAtras;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    final nativoIos = usesNativeIosChrome;

    return ClipRect(
      child: TwGlassFilter(
        sigma: nativoIos ? 20 : 12,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            TwSpacing.screenH,
            top + 14,
            TwSpacing.screenH,
            14,
          ),
          decoration: BoxDecoration(
            color: TwColors.bg.withValues(alpha: nativoIos ? 0.42 : 0.92),
            border: nativoIos
                ? null
                : const Border(
                    bottom: BorderSide(color: TwColors.border07, width: 1),
                  ),
          ),
          child: Row(
            children: [
              if (mostrarAtras)
                NexusHeaderAction(
                  icon: Symbols.arrow_back_rounded,
                  tooltip: 'Volver',
                  sfSymbol: 'chevron.left',
                  onTap: onBack,
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
