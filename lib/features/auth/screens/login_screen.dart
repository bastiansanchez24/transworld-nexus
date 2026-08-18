import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/browser_theme_color.dart';
import '../../../core/theme/tw_tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/tw_components.dart';
import '../../../core/widgets/tw_toast.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../login_error_message.dart';
import '../providers/auth_providers.dart';

const _rememberedEmailKey = 'login_remembered_email';
const _soporteEmail = 'soporte@transworld.cl';

/// Pantalla de login — rediseño §7 de la guía de componentes.
///
/// Columna única sobre [TwColors.bg]: marca, título, tarjeta de formulario,
/// tarjeta de soporte y pie de versión. Los errores de validación se muestran
/// en línea ([TwErrorLine]) dentro de la tarjeta; los de red o credenciales,
/// como [TwToast] de error.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _showPass = false;
  bool _remember = false;
  bool _loading = false;
  String? _error;
  String _version = '';

  @override
  void initState() {
    super.initState();
    final remembered = ref
        .read(sharedPreferencesProvider)
        .getString(_rememberedEmailKey);
    if (remembered != null && remembered.isNotEmpty) {
      _email.text = remembered;
      _remember = true;
    }
    _cargarVersion();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _cargarVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = info.version);
    } catch (_) {
      // El pie es decorativo: si la plataforma no informa versión, se omite.
    }
  }

  void _limpiarError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (_loading) return;

    final email = _email.text.trim();
    if (!RegExp(r'.+@.+\..+').hasMatch(email)) {
      setState(() => _error = 'Ingresa un correo electrónico válido');
      return;
    }
    if (_pass.text.isEmpty) {
      setState(() => _error = 'Ingresa tu contraseña para continuar');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .iniciarSesion(email: email, password: _pass.text);
      // Evita que el router lea un AsyncData(null) stale (pre-login) y
      // cierre la sesión antes de que el perfil se recargue.
      ref.invalidate(currentPerfilProvider);
      final prefs = ref.read(sharedPreferencesProvider);
      if (_remember) {
        await prefs.setString(_rememberedEmailKey, email);
      } else {
        await prefs.remove(_rememberedEmailKey);
      }
      // La navegación post-login la resuelve el redirect del router.
      // Se deja `_loading` en true para no re-mostrar el formulario.
    } catch (e, st) {
      debugPrint('Login falló: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
      TwToast.error(context, mensajeErrorInicioSesion(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session =
        ref.watch(authStateChangesProvider).valueOrNull?.session ??
        ref.read(authRepositoryProvider).currentSession;
    if (session != null && !_loading) {
      return const Scaffold(
        backgroundColor: TwColors.bg,
        body: LoadingView(),
      );
    }

    return BrowserThemeColor(
      color: TwColors.bg,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: TwColors.bg,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: IntrinsicHeight(
                    child: Center(
                      child: ConstrainedBox(
                        // El mock está trazado sobre 412 dp; en escritorio y
                        // web la columna se centra en vez de estirarse.
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _LoginBrand(),
                              const SizedBox(height: 48),
                              const Text('Inicia sesión', style: TwText.display),
                              const SizedBox(height: 7),
                              const SizedBox(
                                width: 280,
                                child: Text(
                                  'Captura leads en eventos y sincroniza con '
                                  'tu pipeline.',
                                  style: TwText.bodyText,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _formCard(),
                              const SizedBox(height: 12),
                              _supportTile(),
                              const Spacer(),
                              const SizedBox(height: 26),
                              Center(
                                child: Text(
                                  _version.isEmpty
                                      ? 'TRANSWORLD P&T'
                                      : 'v$_version · TRANSWORLD P&T',
                                  style: TwText.footer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formCard() {
    return TwCard(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TwFieldLabel('Correo electrónico'),
            TwTextField(
              controller: _email,
              icon: Symbols.mail_rounded,
              hint: 'tu@empresa.cl',
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => _limpiarError(),
            ),
            const TwFieldLabel('Contraseña', top: 16),
            TwTextField(
              controller: _pass,
              icon: Symbols.lock_rounded,
              hint: '••••••••',
              obscure: !_showPass,
              enabled: !_loading,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
              onChanged: (_) => _limpiarError(),
              trailing: TwPasswordEye(
                visible: _showPass,
                onTap: () => setState(() => _showPass = !_showPass),
              ),
            ),
            if (_error != null) TwErrorLine(_error!),
            TwCheckRow(
              checked: _remember,
              label: 'Recordarme',
              onToggle: () => setState(() => _remember = !_remember),
              linkText: 'Olvidé mi contraseña',
              onLink: () => context.push(RoutePaths.recuperarPassword),
            ),
            Semantics(
              label: _loading ? 'Iniciando sesión…' : null,
              child: TwPrimaryButton(
                label: _loading ? 'Ingresando…' : 'Iniciar sesión',
                loading: _loading,
                onTap: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supportTile() {
    return TwPressable(
      onTap: _escribirASoporte,
      child: const TwCard(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            TwIconBox(
              Symbols.support_agent_rounded,
              variant: TwIconBoxStyle.support,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('¿Problemas para ingresar?', style: TwText.supportTitle),
                  SizedBox(height: 3),
                  Text(_soporteEmail, style: TwText.supportSub),
                ],
              ),
            ),
            Icon(
              Symbols.chevron_right_rounded,
              size: 20,
              color: TwColors.chevronSoft,
            ),
          ],
        ),
      ),
    );
  }

  /// Abre el cliente de correo con un mensaje nuevo a soporte. El toast solo
  /// aparece si el dispositivo no tiene con qué abrirlo.
  Future<void> _escribirASoporte() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _soporteEmail,
      query: 'subject=${Uri.encodeComponent('Soporte Transworld RegisPro')}',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok || !mounted) return;
      TwToast.error(context, 'No se pudo abrir tu correo · $_soporteEmail');
    } catch (_) {
      if (!mounted) return;
      TwToast.error(context, 'No se pudo abrir tu correo · $_soporteEmail');
    }
  }
}

/// Logo 52×52 r14 + nombre y bajada de marca.
class _LoginBrand extends StatelessWidget {
  const _LoginBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: TwColors.surface,
            borderRadius: TwRadii.button,
            border: Border.fromBorderSide(
              BorderSide(color: TwColors.border08),
            ),
            boxShadow: TwShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              'assets/images/icon-app/logo-blanco-256.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('TRANSWORLD REGISPRO', style: TwText.brandName),
              SizedBox(height: 5),
              Text('EVENTOS & LEADS', style: TwText.brandSub),
            ],
          ),
        ),
      ],
    );
  }
}
