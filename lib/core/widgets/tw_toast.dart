import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tw_tokens.dart';

/// Toasts del rediseño (§6). Reemplazan por completo a `SnackBar` en las
/// pantallas rediseñadas: se montan en el `Overlay` raíz, así que sobreviven a
/// cambios de pantalla y nunca empujan el layout.
///
/// Un solo toast a la vez: el nuevo reemplaza al anterior. Entra deslizando
/// desde abajo y sale con un fade en el sitio.
enum TwToastKind { info, success, error, progress, link }

class _TwToastData {
  const _TwToastData(this.message, this.kind, this.bottomOffset, this.seq);

  final String message;
  final TwToastKind kind;
  final double bottomOffset;
  final int seq;
}

class TwToast {
  TwToast._();

  static final ValueNotifier<_TwToastData?> _data = ValueNotifier(null);
  static OverlayEntry? _entry;
  static Timer? _timer;
  static int _seq = 0;

  /// Offset estándar cuando la pantalla NO tiene barra inferior.
  static const double kBottom = 24;

  /// Offset cuando la pantalla tiene la bottom nav flotante.
  static const double kBottomWithNav = 96;

  static void show(
    BuildContext context,
    String message, {
    TwToastKind kind = TwToastKind.info,
    Duration duration = const Duration(milliseconds: 2600),
    double bottomOffset = kBottom,
  }) {
    _timer?.cancel();
    _mount(context);
    _data.value = _TwToastData(message, kind, bottomOffset, ++_seq);
    if (kind != TwToastKind.progress) {
      _timer = Timer(duration, hide);
    }
  }

  static void info(BuildContext c, String m, {double bottomOffset = kBottom}) =>
      show(c, m, kind: TwToastKind.info, bottomOffset: bottomOffset);

  static void success(
    BuildContext c,
    String m, {
    double bottomOffset = kBottom,
  }) => show(c, m, kind: TwToastKind.success, bottomOffset: bottomOffset);

  static void error(
    BuildContext c,
    String m, {
    double bottomOffset = kBottom,
  }) => show(
    c,
    m,
    kind: TwToastKind.error,
    duration: const Duration(milliseconds: 3200),
    bottomOffset: bottomOffset,
  );

  static void link(BuildContext c, String m, {double bottomOffset = kBottom}) =>
      show(c, m, kind: TwToastKind.link, bottomOffset: bottomOffset);

  /// No se auto-oculta: ciérralo con [hide] o reemplázalo por otro toast.
  static void progress(
    BuildContext c,
    String m, {
    double bottomOffset = kBottom,
  }) => show(c, m, kind: TwToastKind.progress, bottomOffset: bottomOffset);

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _data.value = null;
  }

  /// El overlay que hospedaba el toast se fue (cambio de árbol, cierre de la
  /// app, fin de un test). Sin esto el temporizador de auto-cierre quedaba
  /// vivo apuntando a una entrada muerta.
  static void _onLayerDisposed() {
    _timer?.cancel();
    _timer = null;
    _entry = null;
  }

  static void _mount(BuildContext context) {
    // `mounted` en false = la entrada quedó huérfana de un árbol anterior.
    if (_entry != null && _entry!.mounted) return;
    _entry = null;
    _data.value = null;

    final entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<_TwToastData?>(
        valueListenable: _data,
        builder: (ctx, data, _) => _TwToastLayer(data: data),
      ),
    );
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }
}

class _TwToastLayer extends StatefulWidget {
  const _TwToastLayer({required this.data});

  final _TwToastData? data;

  @override
  State<_TwToastLayer> createState() => _TwToastLayerState();
}

class _TwToastLayerState extends State<_TwToastLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  _TwToastData? _shown;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _slide = _EnterOnlySlide(_ctrl);
    _ctrl.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.dismissed && widget.data == null) {
        setState(() => _shown = null);
      }
    });
    _sync(widget.data, fromInit: true);
  }

  @override
  void didUpdateWidget(covariant _TwToastLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _sync(widget.data);
    }
  }

  void _sync(_TwToastData? data, {bool fromInit = false}) {
    if (data != null) {
      _shown = data;
      _ctrl.forward(from: 0);
      if (!fromInit) setState(() {});
      return;
    }
    if (_shown != null) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    TwToast._onLayerDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _shown;
    final safe = MediaQuery.paddingOf(context).bottom;
    final bottom = (data?.bottomOffset ?? TwToast.kBottom) + safe;

    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom,
      child: IgnorePointer(
        child: data == null
            ? const SizedBox.shrink()
            : FadeTransition(
                key: const Key('tw-toast-fade'),
                opacity: _fade,
                child: SlideTransition(
                  key: const Key('tw-toast-slide'),
                  position: _slide,
                  child: _TwToastCard(key: ValueKey(data.seq), data: data),
                ),
              ),
      ),
    );
  }
}

/// El slide solo corre hacia adelante. En reverse el valor se queda en
/// [Offset.zero] para que la salida sea un fade en el sitio.
class _EnterOnlySlide extends Animation<Offset>
    with AnimationWithParentMixin<double> {
  _EnterOnlySlide(this.parent);

  @override
  final Animation<double> parent;

  @override
  Offset get value {
    if (parent.status == AnimationStatus.reverse) {
      return Offset.zero;
    }
    final t = Curves.easeOut.transform(parent.value.clamp(0.0, 1.0));
    return Offset(0, 0.28 * (1 - t));
  }
}

class _TwToastCard extends StatelessWidget {
  const _TwToastCard({super.key, required this.data});

  final _TwToastData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 15),
        decoration: const BoxDecoration(
          color: TwColors.toastBg,
          borderRadius: TwRadii.toast,
          boxShadow: TwShadows.toast,
        ),
        child: Row(
          children: [
            _leading(data.kind),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data.message,
                style: TwText.toastText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leading(TwToastKind kind) {
    if (kind == TwToastKind.progress) {
      return const SizedBox(
        width: 17,
        height: 17,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: TwColors.toastInfo,
          backgroundColor: Color(0x4DFFFFFF),
        ),
      );
    }

    final (icon, color) = switch (kind) {
      TwToastKind.success => (
        Symbols.check_circle_rounded,
        TwColors.toastSuccess,
      ),
      TwToastKind.error => (Symbols.error_rounded, TwColors.toastError),
      TwToastKind.link => (Symbols.link_rounded, TwColors.toastSuccess),
      TwToastKind.info ||
      TwToastKind.progress => (Symbols.info_rounded, TwColors.toastInfo),
    };
    return Icon(icon, size: 19, color: color, fill: 1);
  }
}
