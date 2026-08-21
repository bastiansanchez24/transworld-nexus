import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'ios_back_swipe_committer.dart';

/// Navegación de regreso específica del menú de un evento.
///
/// iOS conserva el corrector del gesto desde el borde. Android escucha además
/// el dispatcher nativo: algunos dispositivos no entregan ese back al
/// `Navigator` raíz cuando debajo hay un `StatefulShellRoute` con `PopScope`.
class EventBackNavigationGuard extends StatelessWidget {
  const EventBackNavigationGuard({
    super.key,
    required this.child,
    required this.onAndroidBack,
  });

  final Widget child;
  final Future<bool> Function() onAndroidBack;

  @override
  Widget build(BuildContext context) {
    final router = Router.maybeOf(context);
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        router?.backButtonDispatcher != null) {
      return BackButtonListener(
        onBackButtonPressed: onAndroidBack,
        child: child,
      );
    }
    return iosBackSwipeGuard(child: child);
  }
}
