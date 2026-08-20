import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Índices de [StatefulNavigationShell] en [MainShellScaffold].
abstract final class ShellTabBranch {
  static const inicio = 0;
  static const eventos = 1;
  static const leads = 2;
  static const usuarios = 3;
}

/// Sube en cada tap de la navbar para que la lista de esa rama vuelva al tope.
final shellTabEpochProvider = StateProvider.family<int, int>((ref, branch) => 0);
