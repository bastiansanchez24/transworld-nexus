import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../data/repositories/auth_repository.dart';

class RecuperarPasswordScreen extends ConsumerStatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  ConsumerState<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState
    extends ConsumerState<RecuperarPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _enviado = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .recuperarContrasena(_emailController.text.trim());
      if (mounted) setState(() => _enviado = true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No se pudo enviar la nueva contraseña.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Recuperar contraseña',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _enviado
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_email_read_outlined,
                          size: 56, color: AppColors.success),
                      const SizedBox(height: 16),
                      const Text(
                        'Si el correo existe, te enviamos una nueva '
                        'contraseña de acceso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Ingresa tu correo y te enviaremos una nueva '
                          'contraseña autogenerada.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) =>
                              (value == null || !value.contains('@'))
                                  ? 'Correo inválido'
                                  : null,
                        ),
                        const SizedBox(height: 24),
                        PrimaryGradientButton(
                          label: 'Enviar nueva contraseña',
                          loading: _loading,
                          onPressed: _loading ? null : _enviar,
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
