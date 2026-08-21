import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../network/offline_policy.dart';
import '../theme/tw_tokens.dart';
import '../../features/updates/services/update_platform.dart';
import 'app_modals.dart';
import 'app_widgets.dart';
import 'tw_components.dart';

const cuentaLogoutButtonKey = Key('externo_logout_button');

/// Hoja inferior de ajustes de cuenta, compartida por internos y externos.
Future<void> showCuentaSettingsSheet({
  required BuildContext context,
  required VoidCallback onMiPerfil,
  required VoidCallback onSincronizacion,
  required VoidCallback onActualizaciones,
  required VoidCallback onCerrarSesion,
  VoidCallback? onDesinstalar,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TwColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.58;
      final ota = otaUpdatesSupported;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
                child: TwSectionLabel('Ajustes', top: 0),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TwActionTile(
                        icon: Symbols.person_rounded,
                        iconStyle: TwIconBoxStyle.blueTint,
                        title: 'Mi perfil',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onMiPerfil();
                        },
                      ),
                      if (supportsOfflineCacheAqui) ...[
                        const SizedBox(height: 10),
                        TwActionTile(
                          icon: Symbols.sync_rounded,
                          iconStyle: TwIconBoxStyle.blueTint,
                          title: 'Sincronización',
                          onTap: () {
                            Navigator.of(ctx).pop();
                            onSincronizacion();
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      TwActionTile(
                        icon: ota
                            ? Symbols.system_update_rounded
                            : Symbols.history_rounded,
                        iconStyle: TwIconBoxStyle.blueTint,
                        title: ota
                            ? 'Actualizaciones'
                            : 'Historial de versiones',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onActualizaciones();
                        },
                      ),
                      if (onDesinstalar != null) ...[
                        const SizedBox(height: 10),
                        TwActionTile(
                          icon: Symbols.delete_forever_rounded,
                          iconStyle: TwIconBoxStyle.amberTint,
                          title: 'Desinstalar',
                          onTap: () {
                            Navigator.of(ctx).pop();
                            onDesinstalar();
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      TwActionTile(
                        key: cuentaLogoutButtonKey,
                        icon: Symbols.logout_rounded,
                        iconStyle: TwIconBoxStyle.amberTint,
                        title: 'Cerrar sesión',
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          final ok = await confirmDialog(
                            context,
                            title: 'Cerrar sesión',
                            message: '¿Está seguro que desea cerrar sesión?',
                            confirmLabel: 'Cerrar sesión',
                            destructive: true,
                          );
                          if (!ok || !context.mounted) return;
                          onCerrarSesion();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      );
    },
  );
}
