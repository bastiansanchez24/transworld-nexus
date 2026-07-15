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
      decoration: BoxDecoration(
        color: pair.$1,
        shape: BoxShape.circle,
      ),
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
                  color: selected == opt ? Colors.white : AppColors.textSecondary,
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
    return Container(
      width: hero ? 52 : 48,
      height: hero ? 56 : 52,
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
            child: Icon(icon, size: 20, color: iconColor),
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
    this.finalizado = false,
  });

  final DateTime date;
  final String title;
  final String place;
  final VoidCallback onTap;
  final bool finalizado;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.shadowRest,
        ),
        child: Row(
          children: [
            DateTile(date: date, muted: finalizado),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
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
  const NexusToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

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
  });

  final Widget child;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: AppColors.dashedBorder,
          radius: AppRadius.lg,
        ),
        child: Container(
          height: height,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.tintNavy,
            borderRadius: BorderRadius.circular(AppRadius.lg),
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
    if (AppMotion.reduceMotion(context)) return child;
    final delay = AppMotion.stagger * (index.clamp(0, 10));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.cardIn + delay,
      curve: Interval(
        (delay.inMilliseconds / (AppMotion.cardIn.inMilliseconds + delay.inMilliseconds))
            .clamp(0.0, 0.9),
        1,
        curve: AppMotion.ease,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
