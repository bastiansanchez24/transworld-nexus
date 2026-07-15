import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../data/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';

/// Pantalla de cambio de contraseña obligatorio (`perfiles.cambiar_pass`)
/// o de cambio voluntario desde la sesión activa.
class RecrearPassScreen extends ConsumerStatefulWidget {
  const RecrearPassScreen({super.key});

  @override
  ConsumerState<RecrearPassScreen> createState() => _RecrearPassScreenState();
}

class _RecrearPassScreenState extends ConsumerState<RecrearPassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .forzarNuevaContrasena(_passwordController.text);
      // Refresca el perfil (cambiar_pass ahora es false) para que el
      // redirect del router deje de forzar esta pantalla, y vuelve al home.
      ref.invalidate(currentPerfilProvider);
      if (mounted) {
        showAppSnackBar(context, 'Contraseña actualizada.');
        context.go(RoutePaths.home);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo actualizar la contraseña.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Nueva contraseña',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Por seguridad, define una nueva contraseña.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Nueva contraseña'),
                    validator: (value) => (value == null || value.length < 6)
                        ? 'Mínimo 6 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña'),
                    validator: (value) => value != _passwordController.text
                        ? 'Las contraseñas no coinciden'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  PrimaryGradientButton(
                    label: 'Guardar',
                    loading: _loading,
                    onPressed: _loading ? null : _guardar,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
