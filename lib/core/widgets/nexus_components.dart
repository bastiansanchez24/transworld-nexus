import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';

class AvatarInitials extends StatelessWidget {
  const AvatarInitials({
    super.key,
    required this.name,
    this.size = 40,
    this.index = 0,
  });

  final String name;
  final double size;
  final int index;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final pair = AppColors.avatarPairs[index % AppColors.avatarPairs.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: pair.$1, shape: BoxShape.circle),
      child: Text(
        _initials,
        style: TextStyle(
          color: pair.$2,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Avatar del usuario autenticado: foto de perfil o iniciales como fallback.
class AvatarPerfil extends StatelessWidget {
  const AvatarPerfil({
    super.key,
    required this.nombre,
    this.fotoUrl,
    this.size = 44,
    this.index = 0,
    this.mostrarLapiz = false,
    this.onTap,
  });

  final String nombre;
  final String? fotoUrl;
  final double size;
  final int index;
  final bool mostrarLapiz;
  final VoidCallback? onTap;

  bool get _tieneFoto => fotoUrl != null && fotoUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final avatar = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _AvatarCirculo(
            size: size,
            child: _tieneFoto
                ? CachedNetworkImage(
                    imageUrl: fotoUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: (size * 3).round(),
                    placeholder: (_, _) =>
                        AvatarInitials(name: nombre, size: size, index: index),
                    errorWidget: (_, _, _) =>
                        AvatarInitials(name: nombre, size: size, index: index),
                  )
                : AvatarInitials(name: nombre, size: size, index: index),
          ),
          if (mostrarLapiz)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.38,
                height: size * 0.38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  Symbols.edit_rounded,
                  size: size * 0.2,
                  color: Colors.white,
                  fill: 1,
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return avatar;
    return Pressable(scale: 0.94, onTap: onTap, child: avatar);
  }
}

class _AvatarCirculo extends StatelessWidget {
  const _AvatarCirculo({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

enum StatusChipVariant { success, warning, danger, navy, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.variant = StatusChipVariant.success,
  });

  final String label;
  final StatusChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      StatusChipVariant.success => (AppColors.successTint, AppColors.success),
      StatusChipVariant.warning => (AppColors.warningTint, AppColors.warning),
      StatusChipVariant.danger => (AppColors.dangerTint, AppColors.danger),
      StatusChipVariant.navy => (AppColors.primaryDeep, Colors.white),
      StatusChipVariant.neutral => (AppColors.tintNavy, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final opt in options) ...[
          Pressable(
            scale: 0.95,
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: AppMotion.toggle,
              curve: AppMotion.ease,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: selected == opt
                    ? AppColors.primaryDeep
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: selected == opt
                      ? AppColors.primaryDeep
                      : AppColors.border,
                ),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected == opt
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class DateTile extends StatelessWidget {
  const DateTile({
    super.key,
    required this.date,
    this.hero = false,
    this.muted = false,
  });

  final DateTime date;
  final bool hero;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final day = DateFormat('d', 'es').format(date);
    final month = DateFormat('MMM', 'es').format(date).toUpperCase();
    final escalaSolicitada = MediaQuery.textScalerOf(context).scale(1);
    final textScale = escalaSolicitada < 1 ? 1.0 : escalaSolicitada;
    final baseWidth = hero ? 52.0 : 48.0;
    final baseHeight = hero ? 56.0 : 52.0;
    return Container(
      width: baseWidth * textScale,
      height: baseHeight * textScale,
      decoration: BoxDecoration(
        color: muted ? AppColors.background : AppColors.tintNavy,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: hero ? 19 : 18,
              fontWeight: FontWeight.w800,
              color: muted ? AppColors.textTertiary : AppColors.primaryDeep,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            month.replaceAll('.', ''),
            style: TextStyle(
              fontSize: hero ? 10 : 9.5,
              fontWeight: FontWeight.w700,
              color: muted ? AppColors.textTertiary : AppColors.primary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.tint = AppColors.tintNavy,
    this.iconColor = AppColors.primary,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowRest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: iconColor, fill: 1),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class EventRow extends StatelessWidget {
  const EventRow({
    super.key,
    required this.date,
    required this.title,
    required this.place,
    required this.onTap,
    this.onLongPress,
    this.finalizado = false,
    this.fijado = false,
    this.trailing,
    this.actions,
  });

  final DateTime date;
  final String title;
  final String place;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool finalizado;
  final bool fijado;
  final Widget? trailing;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final chevron = trailing ??
        const Icon(
          Symbols.chevron_right_rounded,
          color: AppColors.chevronMuted,
        );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: fijado ? AppColors.primaryLight : AppColors.border,
          width: fijado ? 1.5 : 1,
        ),
        boxShadow: AppColors.shadowRest,
      ),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    DateTile(date: date, muted: finalizado),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (fijado) ...[
                                const Icon(
                                  Symbols.push_pin_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                    color: finalizado
                                        ? AppColors.textSecondary
                                        : AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (place.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Symbols.location_on_rounded,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    place,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (finalizado) ...[
                            const SizedBox(height: 6),
                            const StatusChip(
                              label: 'Evento finalizado',
                              variant: StatusChipVariant.danger,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (actions == null) chevron,
                  ],
                ),
              ),
            ),
          ),
          if (actions != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              ),
            ),
        ],
      ),
    );
  }
}

class PrimaryGradientButton extends StatelessWidget {
  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      onTap: loading ? null : onPressed,
      enabled: onPressed != null && !loading,
      child: AbsorbPointer(
        absorbing: loading || onPressed == null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppColors.shadowFab,
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class NexusExtendedFab extends StatelessWidget {
  const NexusExtendedFab({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.93,
      onTap: onPressed,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: AppColors.headerGradient,
          borderRadius: BorderRadius.circular(AppRadius.fab),
          boxShadow: AppColors.shadowFab,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NexusToggle extends StatelessWidget {
  const NexusToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.95,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: AppMotion.toggle,
        curve: AppMotion.ease,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.success : AppColors.toggleOff,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: AnimatedAlign(
          duration: AppMotion.toggle,
          curve: AppMotion.ease,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppColors.shadowRest,
            ),
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class NexusActionRow extends StatelessWidget {
  const NexusActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.shadowRest,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.tintNavy,
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Symbols.chevron_right_rounded,
              color: AppColors.chevronMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({
    super.key,
    required this.child,
    this.height = 150,
    this.onTap,
    this.circular = false,
  });

  final Widget child;

  /// `null` deja que lo dimensione el padre (p. ej. un [AspectRatio]).
  final double? height;
  final VoidCallback? onTap;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: CustomPaint(
        painter: circular
            ? _DashedCirclePainter(color: AppColors.dashedBorder)
            : _DashedRRectPainter(
                color: AppColors.dashedBorder,
                radius: AppRadius.lg,
              ),
        child: Container(
          height: height,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.tintNavy,
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circular ? null : BorderRadius.circular(AppRadius.lg),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        const dash = 6.0;
        const gap = 4.0;
        final next = distance + dash;
        dashPath.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final radius = (size.shortestSide - 1.5) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        const dash = 6.0;
        const gap = 4.0;
        final next = distance + dash;
        dashPath.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class StaggeredListItem extends StatelessWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Sin animación: el stagger (Opacity + Translate) trababa el scroll a
    // 120 Hz y dejaba filas “volando” al filtrar/buscar.
    return child;
  }
}

/// Etiqueta compacta sobre un campo de formulario (leads, registrados, etc.).
class NexusFieldLabel extends StatelessWidget {
  const NexusFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Campo de texto con la etiqueta Nexus encima y el hint dentro del input.
class NexusFormTextField extends StatelessWidget {
  const NexusFormTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.readOnly = false,
    this.textInputAction,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final bool readOnly;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NexusFieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hintText,
            alignLabelWithHint: maxLines > 1,
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        ),
      ],
    );
  }
}

/// Cabecera de identidad (nombre + correo) de un formulario.
///
/// Con [nombreController] el nombre se edita dentro de la propia card, en vez
/// de repetirse en un campo aparte más abajo. [leading] deja colgar una foto
/// a la izquierda (formulario de lead).
class PersonaIdentityBanner extends StatelessWidget {
  const PersonaIdentityBanner({
    super.key,
    required this.nombre,
    required this.email,
    this.badge,
    this.leading,
    this.nombreController,
    this.nombreHint = 'Nombre completo',
    this.nombreValidator,
    this.nombreEnabled = true,
    this.nombreSuffix,
    this.margenSuperior = 12,
  });

  /// Nombre a mostrar cuando la card es de solo lectura. Se ignora si hay
  /// [nombreController].
  final String nombre;

  final String email;
  final Widget? badge;
  final Widget? leading;

  /// Si viene, el nombre se edita aquí dentro.
  final TextEditingController? nombreController;

  final String nombreHint;
  final String? Function(String?)? nombreValidator;
  final bool nombreEnabled;

  /// Acción dentro del campo de nombre (p. ej. el dictado por voz del lead).
  final Widget? nombreSuffix;

  /// Aire sobre la card, para que no quede pegada a la cabecera.
  final double margenSuperior;

  static const _estiloNombre = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: Colors.white,
    height: 1.25,
  );

  static OutlineInputBorder _borde(double opacidad, {double grosor = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: opacidad),
        width: grosor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final correo = email.trim();
    final editable = nombreController != null;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: margenSuperior),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppColors.shadowRest,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _nombre()),
                    if (badge != null) ...[
                      const SizedBox(width: 10),
                      // El chip se alinea con el texto del campo, no con el
                      // borde del input.
                      Padding(
                        padding: EdgeInsets.only(top: editable ? 12 : 0),
                        child: badge!,
                      ),
                    ],
                  ],
                ),
                if (correo.isNotEmpty) ...[
                  SizedBox(height: editable ? 8 : 4),
                  Text(
                    correo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nombre() {
    final controller = nombreController;
    if (controller == null) {
      final titulo = nombre.trim().isEmpty ? 'Sin nombre' : nombre.trim();
      return Text(
        titulo,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _estiloNombre,
      );
    }

    return TextFormField(
      controller: controller,
      enabled: nombreEnabled,
      style: _estiloNombre,
      cursorColor: Colors.white,
      textCapitalization: TextCapitalization.words,
      validator: nombreValidator,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.10),
        hintText: nombreHint,
        hintStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.55),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        suffixIcon: nombreSuffix,
        border: _borde(0.28),
        enabledBorder: _borde(0.28),
        disabledBorder: _borde(0.14),
        focusedBorder: _borde(0.8, grosor: 1.5),
        // El rojo de error no se lee sobre el navy; la lima del brand sí.
        errorBorder: _borde(0.5).copyWith(
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        focusedErrorBorder: _borde(0.5).copyWith(
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
