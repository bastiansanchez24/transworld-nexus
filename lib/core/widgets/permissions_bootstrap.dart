import 'package:flutter/material.dart';

import '../permissions/app_permissions.dart';

/// Dispara la solicitud de permisos runtime al montarse (post-login /
/// sesión restaurada). Envuelve pantallas autenticadas.
class PermissionsBootstrap extends StatefulWidget {
  const PermissionsBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<PermissionsBootstrap> createState() => _PermissionsBootstrapState();
}

class _PermissionsBootstrapState extends State<PermissionsBootstrap> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) return;
      _started = true;
      AppPermissions.requestAll();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
