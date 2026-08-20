import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_role.dart';
import '../../../core/network/offline_guard.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/require_admin.dart';
import '../../../core/widgets/selector_imagen.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/storage_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../eventos/providers/eventos_providers.dart';
import '../providers/usuarios_providers.dart';
import '../widgets/selector_eventos_multiples.dart';

/// Edición de usuario: nombre, rol, activo, regenerar contraseña y eliminar.
class EditarUsuarioScreen extends StatelessWidget {
  const EditarUsuarioScreen({super.key, required this.usuarioId});

  final String usuarioId;

  @override
  Widget build(BuildContext context) {
    return RequireAdmin(
      builder: (context) => _EditarUsuarioBody(usuarioId: usuarioId),
    );
  }
}

class _EditarUsuarioBody extends ConsumerStatefulWidget {
  const _EditarUsuarioBody({required this.usuarioId});

  final String usuarioId;

  @override
  ConsumerState<_EditarUsuarioBody> createState() => _EditarUsuarioBodyState();
}

class _EditarUsuarioBodyState extends ConsumerState<_EditarUsuarioBody> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _activo = true;
  AppRole _rol = AppRole.user;
  AppRole? _rolOriginal;
  bool _cargado = false;
  bool _eventosCargados = false;
  bool _eventosCargaError = false;
  bool _guardando = false;
  bool _eliminando = false;
  bool _regenerando = false;
  bool _intentoGuardar = false;
  String? _passwordGenerada;
  Uint8List? _fotoBytes;
  bool _quitarFoto = false;
  final Set<String> _eventoIds = {};
  Set<String> _eventoIds0 = {};
  bool _eventoIdsListos = false;

  String _nombre0 = '';
  bool _activo0 = true;
  AppRole _rol0 = AppRole.user;

  bool get _asignaEventos => _rol.requiresEventAssignment;

  /// Roles editables vía RPC (no incluye externo: solo al crear).
  List<AppRole> get _rolesDisponibles {
    if (_rolOriginal == AppRole.externo) {
      return [AppRole.externo, ...AppRole.assignableRoles];
    }
    return AppRole.assignableRoles;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _cargarEmail() async {
    try {
      final email = await ref
          .read(authRepositoryProvider)
          .obtenerEmailUsuario(widget.usuarioId);
      if (mounted && email != null) {
        _emailController.text = email;
      }
    } catch (_) {
      // El form sigue usable; el email puede quedar vacío si falla el RPC.
    }
  }

  Future<void> _cargarEventosAutorizados() async {
    if (_eventosCargados && !_eventosCargaError) return;
    try {
      final ids = await ref
          .read(authRepositoryProvider)
          .listarEventosAutorizadosUsuario(widget.usuarioId);
      if (!mounted) return;
      setState(() {
        _eventoIds
          ..clear()
          ..addAll(ids);
        _eventoIds0 = Set<String>.from(ids);
        _eventoIdsListos = true;
        _eventosCargados = true;
        _eventosCargaError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _eventosCargados = true;
        _eventosCargaError = true;
      });
    }
  }

  Future<void> _elegirFoto() async {
    final bytes = await elegirImagenComprimida(
      context,
      recorteProporcion: kProporcionFotoLead,
      tituloRecorte: 'Recortar foto de perfil',
    );
    if (bytes == null || !mounted) return;
    setState(() {
      _fotoBytes = bytes;
      _quitarFoto = false;
    });
  }

  String _textoCompartir({required String nombre}) {
    final buffer = StringBuffer()
      ..writeln('Acceso Transworld RegisPro')
      ..writeln('Nombre: $nombre')
      ..writeln('Email: ${_emailController.text.trim()}');
    final pass = _passwordGenerada ?? _passwordController.text;
    if (pass.isNotEmpty && pass != '••••••••••••') {
      buffer.writeln('Contraseña: $pass');
    }
    return buffer.toString().trimRight();
  }

  Future<void> _compartir(String nombre) async {
    if (_emailController.text.trim().isEmpty) {
      showAppSnackBar(context, 'No hay correo para compartir.');
      return;
    }
    if (_passwordGenerada == null) {
      showAppSnackBar(
        context,
        'Genera una nueva contraseña para poder compartirla.',
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(text: _textoCompartir(nombre: nombre)),
    );
  }

  Future<void> _regenerarPassword() async {
    final esCuentaPropia =
        ref.read(currentPerfilProvider).valueOrNull?.id == widget.usuarioId ||
        ref.read(authRepositoryProvider).currentUserId == widget.usuarioId;
    if (esCuentaPropia) {
      showAppSnackBar(
        context,
        'No puedes regenerar tu propia contraseña. Usa el menú de cambio de contraseña en tu perfil.',
      );
      return;
    }

    setState(() => _regenerando = true);
    try {
      final resultado = await ref
          .read(authRepositoryProvider)
          .regenerarPasswordUsuario(widget.usuarioId);
      if (!mounted) return;
      setState(() {
        _passwordGenerada = resultado.password;
        _passwordController.text = resultado.password;
        if (_emailController.text.isEmpty) {
          _emailController.text = resultado.email;
        }
      });
      showAppSnackBar(context, 'Nueva contraseña enviada por correo.');
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _regenerando = false);
    }
  }

  Future<void> _guardar() async {
    if (!requireOnline(context, ref)) return;
    setState(() => _intentoGuardar = true);
    if (!_formKey.currentState!.validate()) return;
    if (_rol == AppRole.externo && _rolOriginal != AppRole.externo) {
      showAppSnackBar(
        context,
        'El rol externo solo se asigna al crear el usuario.',
      );
      return;
    }
    if (_rol == AppRole.externo && _eventoIds.isEmpty) {
      showAppSnackBar(context, 'Selecciona al menos un evento.');
      return;
    }
    if (_asignaEventos && (!_eventosCargados || _eventosCargaError)) {
      showAppSnackBar(
        context,
        'No se pudieron verificar los eventos autorizados. Intenta nuevamente.',
      );
      return;
    }

    final esCuentaPropia =
        ref.read(currentPerfilProvider).valueOrNull?.id == widget.usuarioId;

    if (esCuentaPropia && !_activo) {
      showAppSnackBar(context, 'No puedes desactivar tu propia cuenta.');
      setState(() => _activo = true);
      return;
    }

    final router = GoRouter.of(context);
    setState(() => _guardando = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.actualizarNombre(
        widget.usuarioId,
        _nombreController.text.trim(),
      );
      if (!esCuentaPropia) {
        await repo.configurarAccesoUsuario(
          usuarioId: widget.usuarioId,
          nuevoRol: _rol.value,
          eventoIds: _asignaEventos ? _eventoIds.toList() : const [],
        );
        await repo.establecerActivo(widget.usuarioId, _activo);
      }
      if (_fotoBytes != null) {
        final fotoUrl = await ref
            .read(storageRepositoryProvider)
            .subirFotoPerfil(_fotoBytes!, widget.usuarioId);
        await repo.actualizarFotoUsuario(widget.usuarioId, fotoUrl);
      } else if (_quitarFoto) {
        await repo.actualizarFotoUsuario(widget.usuarioId, null);
      }

      if (mounted) {
        ref.invalidate(usuariosListProvider);
        ref.invalidate(usuarioPorIdProvider(widget.usuarioId));
        if (esCuentaPropia) {
          ref.invalidate(currentPerfilProvider);
        }
        showAppSnackBar(context, 'Usuario actualizado.');
      }
      router.go(RoutePaths.usuarios);
    } on PostgrestException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
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

  Future<void> _eliminar(String nombre) async {
    if (!requireOnline(context, ref)) return;
    final esCuentaPropia =
        ref.read(currentPerfilProvider).valueOrNull?.id == widget.usuarioId;
    if (esCuentaPropia) {
      showAppSnackBar(context, 'No puedes eliminar tu propia cuenta.');
      return;
    }

    final confirmado = await confirmDialog(
      context,
      title: 'Eliminar usuario',
      message:
          'Se eliminará la cuenta de "$nombre" y su acceso a la app. '
          'Todos sus registros quedarán como "Usuario eliminado". '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmado || !mounted) return;

    final router = GoRouter.of(context);
    setState(() => _eliminando = true);
    try {
      final eliminado = await ref
          .read(authRepositoryProvider)
          .eliminarUsuario(widget.usuarioId);
      if (mounted) {
        ref.invalidate(usuariosListProvider);
        showAppSnackBar(
          context,
          eliminado
              ? 'Usuario eliminado.'
              : 'La cuenta quedó desactivada: otra aplicación de la base '
                    'compartida aún referencia sus datos, pero perdió el acceso.',
        );
      }
      router.go(RoutePaths.usuarios);
    } on PostgrestException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No se pudo eliminar el usuario.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  bool get _hayCambios {
    if (!_cargado) return false;
    if (_nombreController.text != _nombre0) return true;
    if (_activo != _activo0) return true;
    if (_rol != _rol0) return true;
    if (_fotoBytes != null || _quitarFoto) return true;
    if (_asignaEventos && _eventoIdsListos) {
      if (_eventoIds.length != _eventoIds0.length ||
          !_eventoIds.containsAll(_eventoIds0)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAsync = ref.watch(usuarioPorIdProvider(widget.usuarioId));
    final sesionId = ref.watch(authRepositoryProvider).currentUserId;
    final esCuentaPropia =
        ref.watch(currentPerfilProvider).valueOrNull?.id == widget.usuarioId ||
        sesionId == widget.usuarioId;
    // Regenerar solo bloquea el campo de contraseña; el resto del form sigue usable.
    final ocupado = _guardando || _eliminando;
    final bloquearActivoPropio = esCuentaPropia;

    return AppScaffold(
      title: 'Editar usuario',
      onWillPop: () => handleFormExit(
        context: context,
        isCreate: false,
        isDirty: _hayCambios,
        save: _guardar,
      ),
      actions: [
        if (!esCuentaPropia)
          NexusHeaderAction(
            icon: Symbols.delete_outline_rounded,
            tooltip: 'Eliminar usuario',
            danger: true,
            loading: _eliminando,
            onTap: ocupado
                ? null
                : () {
                    final nombre = _nombreController.text.trim().isEmpty
                        ? 'este usuario'
                        : _nombreController.text.trim();
                    _eliminar(nombre);
                  },
          ),
      ],
      body: usuarioAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) =>
            const ErrorView(message: 'No se pudo cargar el usuario.'),
        data: (usuario) {
          if (!_cargado) {
            _nombreController.text = usuario.nombreCompleto;
            _passwordController.text = '••••••••••••';
            _activo = usuario.activo;
            _rol = usuario.rol;
            _rolOriginal = usuario.rol;
            _nombre0 = usuario.nombreCompleto;
            _activo0 = usuario.activo;
            _rol0 = usuario.rol;
            _cargado = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _cargarEmail();
              _cargarEventosAutorizados();
            });
          }

          final esExterno = _rol == AppRole.externo;
          final asignaEventos = _asignaEventos;
          final eventosAsync = asignaEventos
              ? ref.watch(eventosListProvider)
              : null;

          return SingleChildScrollView(
            padding: AppSpacing.form,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FieldLabel('Foto'),
                  const SizedBox(height: 6),
                  SelectorImagen(
                    bytes: _fotoBytes,
                    urlExistente: _quitarFoto ? null : usuario.fotoUrl,
                    enabled: !ocupado,
                    aspectRatio: kProporcionFotoLead,
                    anchoMaximo: kAnchoSelectorFotoLead,
                    circular: true,
                    etiquetaVacio: 'Agregar foto del usuario',
                    onElegir: _elegirFoto,
                    onQuitar:
                        (_fotoBytes != null ||
                            (!_quitarFoto &&
                                (usuario.fotoUrl?.isNotEmpty ?? false)))
                        ? () => setState(() {
                            _fotoBytes = null;
                            _quitarFoto = true;
                          })
                        : null,
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Nombre completo'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nombreController,
                    enabled: !ocupado,
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
                    readOnly: true,
                    enableInteractiveSelection: true,
                    decoration: twReadOnlyDecoration(hintText: 'Cargando…'),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Contraseña'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    readOnly: true,
                    obscureText: _passwordGenerada == null,
                    decoration: twReadOnlyDecoration(
                      hintText: 'No visible',
                      helperText: esCuentaPropia
                          ? 'Para cambiar tu contraseña usa Mi perfil.'
                          : null,
                      helperMaxLines: 2,
                      suffixIcon: esCuentaPropia
                          ? null
                          : IconButton(
                              tooltip: 'Generar nueva y enviar por correo',
                              onPressed: (ocupado || _regenerando)
                                  ? null
                                  : _regenerarPassword,
                              icon: _regenerando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Symbols.refresh_rounded),
                            ),
                    ),
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
                    items: _rolesDisponibles
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.label)),
                        )
                        .toList(),
                    onChanged: (ocupado || esCuentaPropia)
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              _rol = v;
                              if (v != AppRole.user && v != AppRole.externo) {
                                _eventoIds.clear();
                              }
                            });
                          },
                    validator: (v) =>
                        v == null ? 'Selecciona el tipo de usuario' : null,
                  ),
                  if (asignaEventos) ...[
                    const SizedBox(height: 14),
                    const _FieldLabel('Eventos autorizados'),
                    const SizedBox(height: 6),
                    if (!_eventosCargados)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      )
                    else if (_eventosCargaError)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No se pudieron cargar las asignaciones actuales.',
                            style: TextStyle(color: AppColors.danger),
                          ),
                          TextButton.icon(
                            onPressed: ocupado
                                ? null
                                : () {
                                    setState(() {
                                      _eventosCargados = false;
                                      _eventosCargaError = false;
                                    });
                                    _cargarEventosAutorizados();
                                  },
                            icon: const Icon(Symbols.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      )
                    else
                      eventosAsync!.when(
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
                            enabled: !ocupado,
                            soloActivosDisponibles: esExterno,
                            emptyHelperText: esExterno
                                ? 'Selecciona al menos un evento.'
                                : 'Sin eventos asignados: el usuario no podrá operar eventos.',
                            errorText:
                                esExterno &&
                                    _intentoGuardar &&
                                    _eventoIds.isEmpty
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
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cuenta activa',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Desactivar bloquea el acceso a la app',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IgnorePointer(
                        ignoring: ocupado || bloquearActivoPropio,
                        child: Opacity(
                          opacity: (ocupado || bloquearActivoPropio) ? 0.5 : 1,
                          child: NexusToggle(
                            value: _activo,
                            onChanged: bloquearActivoPropio
                                ? (_) {}
                                : (v) => setState(() => _activo = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: ocupado
                              ? null
                              : () => _compartir(_nombreController.text.trim()),
                          icon: const Icon(Symbols.share_rounded),
                          label: const Text('Compartir'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryGradientButton(
                          label: _guardando ? 'Guardando…' : 'Guardar',
                          loading: _guardando,
                          onPressed: ocupado ? null : _guardar,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
