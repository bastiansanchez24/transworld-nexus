import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tw_toast.dart';

/// Colección pequeña de widgets reutilizables para no repetir boilerplate
/// de estados de carga / error / vacío en cada pantalla.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Presente solo bajo [MainShellScaffold], donde la bottom nav está a la vista.
/// Las rutas push (Actualizaciones, Perfil, etc.) no lo heredan.
class ShellNavScope extends InheritedWidget {
  const ShellNavScope({super.key, required super.child});

  static bool visibleOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellNavScope>() != null;

  @override
  bool updateShouldNotify(ShellNavScope oldWidget) => false;
}

/// Aviso breve al usuario. Un solo camino para toda la app: el toast del
/// rediseño ([TwToast]). Antes los errores salían por `SnackBar` y el resto
/// por otro toast, así que el mismo evento se veía distinto según la pantalla.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final bottomOffset =
      ShellNavScope.visibleOf(context) &&
          !GlassNavTokens.usesSideRailOf(context)
      ? GlassNavTokens.shellToastLift()
      : TwToast.kBottom;

  if (isError) {
    TwToast.error(context, message, bottomOffset: bottomOffset);
  } else {
    TwToast.success(context, message, bottomOffset: bottomOffset);
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: !destructive,
    builder: (context) => AlertDialog(
      icon: destructive
          ? const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 36,
            )
          : null,
      title: Text(title, textAlign: destructive ? TextAlign.center : null),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
