import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/password_generator.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/nexus_toast.dart';
import '../../../core/widgets/require_admin.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../providers/usuarios_providers.dart';
import '../widgets/selector_eventos_multiples.dart';

/// Crea un usuario (cualquier rol) desde gestión de administradores.
class NuevoUsuarioScreen extends StatelessWidget {
  const NuevoUsuarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RequireAdmin(
      builder: (context) => const _NuevoUsuarioForm(),
    );
  }
}

class _NuevoUsuarioForm extends ConsumerStatefulWidget {
  const _NuevoUsuarioForm();

  @override
  ConsumerState<_NuevoUsuarioForm> createState() => _NuevoUsuarioFormState();
}

class _NuevoUsuarioFormState extends ConsumerState<_NuevoUsuarioForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  late final TextEditingController _passwordController;

  AppRole? _rol;
  final Set<String> _eventoIds = {};
  bool _intentoGuardar = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController(
      text: generarContrasenaInvitacion(),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _esExterno => _rol == AppRole.externo;

  String _textoCompartir({List<String> eventoNombres = const []}) {
    final buffer = StringBuffer()
      ..writeln('Acceso Transworld RegisPro')
      ..writeln('Nombre: ${_nombreController.text.trim()}')
      ..writeln('Email: ${_emailController.text.trim()}')
      ..writeln('Contraseña: ${_passwordController.text}');
    if (eventoNombres.isNotEmpty) {
      buffer.writeln(
        eventoNombres.length == 1
            ? 'Evento: ${eventoNombres.first}'
            : 'Eventos: ${eventoNombres.join(', ')}',
      );
    }
    return buffer.toString().trimRight();
  }

  Future<void> _compartir({List<String> eventoNombres = const []}) async {
    if (_emailController.text.trim().isEmpty) {
      NexusToast.show(context, 'Ingresa un email para compartir.');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(text: _textoCompartir(eventoNombres: eventoNombres)),
    );
  }

  Future<void> _guardar() async {
    setState(() => _intentoGuardar = true);
    if (!_formKey.currentState!.validate()) return;
    if (_rol == null) {
      NexusToast.show(context, 'Selecciona el tipo de usuario.');
      return;
    }
    if (_esExterno && _eventoIds.isEmpty) {
      NexusToast.show(context, 'Selecciona al menos un evento.');
      return;
    }

    setState(() => _guardando = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final email = _emailController.text.trim();
      if (await repo.verificarEmailRegistrado(email)) {
        if (mounted) {
          showAppSnackBar(
            context,
            'El email ya está registrado.',
            isError: true,
          );
        }
        return;
      }

      await repo.crearUsuario(
        nombreCompleto: _nombreController.text.trim(),
        email: email,
        password: _passwordController.text,
        rol: _rol!.value,
        eventoIds: _esExterno ? _eventoIds.toList() : null,
      );

      ref.invalidate(usuariosListProvider);
      if (mounted) {
        NexusToast.show(
          context,
          'Usuario creado. Credenciales enviadas por correo.',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventosAsync = ref.watch(eventosListProvider);

    return AppScaffold(
      title: 'Nuevo usuario',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Crea una cuenta y envía las credenciales al correo del usuario.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Nombre completo'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  hintText: 'Ej. Juan Pérez',
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),
              const _FieldLabel('Correo'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'usuario@empresa.com',
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Requerido';
                  if (!value.contains('@')) return 'Email inválido';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const _FieldLabel('Contraseña'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: 'Autogenerada',
                  suffixIcon: IconButton(
                    tooltip: 'Regenerar',
                    onPressed: _guardando
                        ? null
                        : () {
                            setState(() {
                              _passwordController.text =
                                  generarContrasenaInvitacion();
                            });
                          },
                    icon: const Icon(Symbols.refresh_rounded),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
              ),
              const SizedBox(height: 14),
              const _FieldLabel('Tipo de usuario'),
              const SizedBox(height: 6),
              DropdownButtonFormField<AppRole>(
                initialValue: _rol,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Selecciona un tipo',
                ),
                items: AppRole.creatableRoles
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.label),
                      ),
                    )
                    .toList(),
                onChanged: _guardando
                    ? null
                    : (v) => setState(() {
                          _rol = v;
                          if (v != AppRole.externo) {
                            _eventoIds.clear();
                          }
                        }),
                validator: (v) =>
                    v == null ? 'Selecciona el tipo de usuario' : null,
              ),
              if (_esExterno) ...[
                const SizedBox(height: 14),
                const _FieldLabel('Eventos autorizados'),
                const SizedBox(height: 6),
                eventosAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => const Text(
                    'No se pudieron cargar los eventos.',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  data: (eventos) {
                    return SelectorEventosMultiples(
                      eventos: eventos,
                      seleccionados: _eventoIds,
                      enabled: !_guardando,
                      soloActivosDisponibles: true,
                      errorText: _intentoGuardar && _eventoIds.isEmpty
                          ? 'Selecciona al menos un evento'
                          : null,
                      onChanged: (ids) => setState(() {
                        _eventoIds
                          ..clear()
                          ..addAll(ids);
                      }),
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _guardando
                          ? null
                          : () {
                              final eventos = eventosAsync.valueOrNull ?? [];
                              final nombres = eventos
                                  .where((e) => _eventoIds.contains(e.id))
                                  .map((e) => e.nombre)
                                  .toList();
                              _compartir(eventoNombres: nombres);
                            },
                      icon: const Icon(Symbols.share_rounded),
                      label: const Text('Compartir'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryGradientButton(
                      label: _guardando ? 'Guardando…' : 'Guardar',
                      loading: _guardando,
                      onPressed: _guardando ? null : _guardar,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}
