import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models/perfil.dart';
import '../theme/tw_tokens.dart';
import 'app_network_image.dart';
import 'nexus_components.dart';
import 'notificaciones_header_button.dart';
import 'pressable.dart';

/// Fila de identidad del home (interno y externo): foto, saludo, rol y ajustes.
class CuentaIdentityHeader extends StatelessWidget {
  const CuentaIdentityHeader({
    super.key,
    required this.perfil,
    required this.onAjustes,
    required this.onMiPerfil,
    this.ajustesKey,
    this.onNotificaciones,
    this.noLeidas = 0,
  });

  final Perfil? perfil;
  final VoidCallback onAjustes;
  final VoidCallback onMiPerfil;
  final Key? ajustesKey;
  final VoidCallback? onNotificaciones;
  final int noLeidas;

  static const avatarSize = 44.0;

  String get _firstName {
    final nombre = perfil?.nombreCompleto.trim() ?? '';
    if (nombre.isEmpty) return '';
    return nombre.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final first = _firstName;
    final saludo = first.isEmpty ? 'Hola 👋' : 'Hola, $first 👋';
    final rol = perfil?.rol.label ?? '';

    return Row(
      children: [
        Pressable(
          scale: 0.94,
          onTap: onMiPerfil,
          child: _CuentaAvatar(
            nombre: perfil?.nombreCompleto ?? '?',
            fotoUrl: perfil?.fotoUrl,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saludo,
                style: TwText.greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (rol.isNotEmpty) ...[
                const SizedBox(height: 6),
                _RoleChip(label: rol),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        _IconChip(
          key: ajustesKey,
          icon: Symbols.settings_rounded,
          tooltip: 'Ajustes de la cuenta',
          onTap: onAjustes,
        ),
        if (onNotificaciones != null) ...[
          const SizedBox(width: 12),
          NotificacionesHeaderButton(
            noLeidas: noLeidas,
            onTap: onNotificaciones!,
          ),
        ],
      ],
    );
  }
}

class _CuentaAvatar extends StatelessWidget {
  const _CuentaAvatar({required this.nombre, this.fotoUrl});

  final String nombre;
  final String? fotoUrl;

  static const _size = CuentaIdentityHeader.avatarSize;

  @override
  Widget build(BuildContext context) {
    final tieneFoto = fotoUrl != null && fotoUrl!.isNotEmpty;
    final fallback = AvatarInitials(name: nombre, size: _size);
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: tieneFoto
                ? AppNetworkImage(
                    url: fotoUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 132,
                    placeholder: fallback,
                    errorWidget: fallback,
                  )
                : fallback,
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: TwColors.hero700, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        scale: 0.92,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: TwColors.surface,
            borderRadius: TwRadii.iconLg,
            border: Border.fromBorderSide(BorderSide(color: TwColors.border08)),
            boxShadow: TwShadows.soft,
          ),
          child: Icon(icon, color: TwColors.iconInk, size: 20),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const BoxDecoration(
        color: TwColors.blueTint,
        borderRadius: TwRadii.badge,
      ),
      child: Text(label.toUpperCase(), style: TwText.roleBadge),
    );
  }
}
