import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../widgets/login/login_button.dart';
import '../widgets/login/login_form.dart';
import '../widgets/login/login_header.dart';
import '../widgets/login/login_theme.dart';

const _rememberedEmailKey = 'login_remembered_email';

/// Pantalla de login (composición). La UI está separada en componentes
/// (`widgets/login/`): header hero, formulario, botón principal y acciones
/// secundarias — esta clase solo orquesta estado, animaciones y layout.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _loading = false;

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void initState() {
    super.initState();
    final remembered =
        ref.read(sharedPreferencesProvider).getString(_rememberedEmailKey);
    if (remembered != null && remembered.isNotEmpty) {
      _emailController.text = remembered;
      _rememberMe = true;
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      await ref.read(authRepositoryProvider).iniciarSesion(
            email: email,
            password: _passwordController.text,
          );
      final prefs = ref.read(sharedPreferencesProvider);
      if (_rememberMe) {
        await prefs.setString(_rememberedEmailKey, email);
      } else {
        await prefs.remove(_rememberedEmailKey);
      }
      // La navegación post-login la resuelve el redirect del router,
      // reaccionando a los cambios de sesión de Supabase.
    } on AuthException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo iniciar sesión.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Theme(
        data: LoginTheme.of(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final esAncho = constraints.maxWidth >= 900;
            return esAncho
                ? _buildWide(constraints)
                : _buildNarrow(constraints);
          },
        ),
      ),
    );
  }

  /// Teléfonos: hero arriba (~45%, colapsa suavemente al abrir el teclado)
  /// y formulario debajo.
  Widget _buildNarrow(BoxConstraints constraints) {
    final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;
    final alturaHero = tecladoAbierto
        ? 150.0
        : (constraints.maxHeight * 0.45).clamp(240.0, 420.0);

    return Column(
      children: [
        AnimatedContainer(
          duration: LoginTheme.keyboardDuration,
          curve: LoginTheme.curve,
          height: alturaHero,
          width: double.infinity,
          child: _Entrada(
            animation: _enter,
            intervalo: const Interval(0, 0.5, curve: LoginTheme.curve),
            deslizar: false,
            child: const LoginHeader(
              title: 'Bienvenido',
              subtitle: 'Inicia sesión para continuar.',
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _buildFormulario(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Tablets / escritorio / web ancho: hero como panel izquierdo a pantalla
  /// completa y formulario centrado a la derecha.
  Widget _buildWide(BoxConstraints constraints) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _Entrada(
            animation: _enter,
            intervalo: const Interval(0, 0.5, curve: LoginTheme.curve),
            deslizar: false,
            child: const LoginHeader(
              title: 'Bienvenido',
              subtitle: 'Inicia sesión para continuar.',
              borderRadius: BorderRadius.horizontal(
                right: Radius.circular(LoginTheme.heroRadius),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildFormulario(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Entrada(
            animation: _enter,
            intervalo: const Interval(0.15, 0.7, curve: LoginTheme.curve),
            child: LoginForm(
              emailController: _emailController,
              passwordController: _passwordController,
              obscurePassword: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              rememberMe: _rememberMe,
              onRememberChanged: (v) => setState(() => _rememberMe = v),
              onSubmit: _handleLogin,
              enabled: !_loading,
            ),
          ),
          const SizedBox(height: 16),
          _Entrada(
            animation: _enter,
            intervalo: const Interval(0.3, 0.85, curve: LoginTheme.curve),
            child: LoginButton(
              label: 'Iniciar sesión',
              loading: _loading,
              loadingSemanticsLabel: 'Iniciando sesión…',
              onPressed: _handleLogin,
            ),
          ),
          const SizedBox(height: 12),
          _Entrada(
            animation: _enter,
            intervalo: const Interval(0.45, 1, curve: LoginTheme.curve),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('¿No tienes cuenta?',
                    style: TextStyle(color: AppColors.textSecondary)),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed:
                      _loading ? null : () => context.push(RoutePaths.registro),
                  child: const Text('Crear cuenta',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade in + slide up escalonado para la animación de entrada (plan:
/// 250–350 ms por tramo, easeOutCubic).
class _Entrada extends StatelessWidget {
  const _Entrada({
    required this.animation,
    required this.intervalo,
    required this.child,
    this.deslizar = true,
  });

  final Animation<double> animation;
  final Interval intervalo;
  final Widget child;
  final bool deslizar;

  @override
  Widget build(BuildContext context) {
    final curva = CurvedAnimation(parent: animation, curve: intervalo);
    Widget resultado = FadeTransition(opacity: curva, child: child);
    if (deslizar) {
      resultado = SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curva),
        child: resultado,
      );
    }
    return resultado;
  }
}
