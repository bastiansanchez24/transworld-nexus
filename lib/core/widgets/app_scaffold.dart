import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'offline_banner.dart';

/// Plantilla base de todas las pantallas autenticadas, con navegación al
/// estilo iOS: sin AppBar de Material — el título vive integrado en el
/// contenido, con una pequeña flecha a la izquierda para volver cuando hay
/// una pantalla anterior en la pila.
///
/// Centraliza además el [OfflineBanner] y el ancho máximo del contenido
/// (en Web/escritorio el contenido queda centrado con un ancho legible).
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

  /// Alternativa a [title] cuando el título es dinámico (ej. nombre del
  /// evento cargándose).
  final Widget? titleWidget;
  final List<Widget>? actions;

  /// Widget fijo bajo la fila del título (ej. un buscador), fuera del
  /// scroll del contenido.
  final Widget? headerBottom;
  final Widget? floatingActionButton;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Fondo claro en toda la pantalla → iconos oscuros en la status bar.
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        floatingActionButton: floatingActionButton,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const OfflineBanner(),
              _constrained(
                _Header(
                  title: title,
                  titleWidget: titleWidget,
                  actions: actions,
                ),
              ),
              if (headerBottom != null) _constrained(headerBottom!),
              Expanded(child: _constrained(body)),
            ],
          ),
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

class _Header extends StatelessWidget {
  const _Header({this.title, this.titleWidget, this.actions});

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final puedeVolver = context.canPop();
    final estiloTitulo = Theme.of(context).textTheme.headlineSmall!;

    return Padding(
      padding: EdgeInsets.fromLTRB(puedeVolver ? 4 : 20, 8, 12, 8),
      child: Row(
        children: [
          if (puedeVolver)
            IconButton(
              tooltip: 'Volver',
              onPressed: () => context.pop(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.primaryDark,
              ),
            ),
          Expanded(
            child: DefaultTextStyle(
              style: estiloTitulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: Semantics(
                header: true,
                child: titleWidget ?? Text(title ?? ''),
              ),
            ),
          ),
          if (actions != null)
            IconTheme(
              data: const IconThemeData(color: AppColors.primaryDark),
              child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
            ),
        ],
      ),
    );
  }
}
