import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../network/connectivity_service.dart';
import '../theme/tw_tokens.dart';

const kTwOfflineNoticeTitle = 'Sin conexión a internet';
const kTwOfflineNoticeSubtitle =
    'Se han limitado las funciones de la aplicación hasta que recuperes la conexión';

/// Aviso de modo local: naranjo pálido, sin chevron ni tap.
///
/// Solo aparece cuando [isOnlineProvider] es `false`. Pendientes y conflictos
/// no lo disparan.
class TwOfflineNoticeCard extends ConsumerWidget {
  const TwOfflineNoticeCard({super.key, this.topGap = 0, this.bottomGap = 0});

  /// Aire sobre la card (p. ej. respecto al hero del menú de acciones).
  final double topGap;

  /// Espacio bajo la card cuando está visible (0 si el label de sección ya
  /// aporta aire).
  final double bottomGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hayRed = ref.watch(isOnlineProvider);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: hayRed
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.only(top: topGap, bottom: bottomGap),
              child: const _Tarjeta(),
            ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      decoration: BoxDecoration(
        color: TwColors.offlineNoticeBg,
        borderRadius: TwRadii.tile,
        border: Border.all(color: TwColors.offlineNoticeBorder),
        boxShadow: TwShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: TwColors.offlineNoticeIconBg,
              borderRadius: TwRadii.iconLg,
            ),
            child: const Icon(
              Symbols.warning_amber_rounded,
              size: 21,
              color: TwColors.offlineNoticeInk,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kTwOfflineNoticeTitle,
                  style: TwText.tileTitle.copyWith(
                    color: TwColors.offlineNoticeInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kTwOfflineNoticeSubtitle,
                  style: TwText.tileSubtitle.copyWith(
                    color: TwColors.offlineNoticeMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
