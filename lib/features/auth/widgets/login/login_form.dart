import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'forgot_password_button.dart';

/// Campos del login + fila de acciones secundarias (Recordarme / Olvidé mi
/// contraseña). No conoce Supabase ni navegación: recibe controladores y
/// callbacks, para poder testearse y reusarse aislado.
class LoginForm extends StatelessWidget {
  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.rememberMe,
    required this.onRememberChanged,
    required this.onSubmit,
    this.enabled = true,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool rememberMe;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onSubmit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: emailController,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu correo';
              }
              if (!value.contains('@')) return 'Correo inválido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            enabled: enabled,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: obscurePassword
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                icon: Icon(obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: enabled ? onToggleObscure : null,
              ),
            ),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Ingresa tu contraseña'
                : null,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  // El InkWell + Checkbox se anuncian como un solo control.
                  label: 'Recordarme',
                  checked: rememberMe,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    onTap: enabled ? () => onRememberChanged(!rememberMe) : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Checkbox(
                            value: rememberMe,
                            onChanged: enabled
                                ? (v) => onRememberChanged(v ?? false)
                                : null,
                          ),
                        ),
                        const ExcludeSemantics(child: Text('Recordarme')),
                      ],
                    ),
                  ),
                ),
              ),
              ForgotPasswordButton(enabled: enabled),
            ],
          ),
        ],
      ),
    );
  }
}
