import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/collapsing_nav.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/selector_imagen.dart';
import '../../../data/models/lead.dart';
import '../../../data/offline/pending_photo_store.dart';
import '../../../data/offline/sync_queue_service.dart';
import '../../../data/repositories/leads_repository.dart';
import '../../../data/repositories/storage_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/capturador_providers.dart';
import '../widgets/avatar_lead.dart';

enum _FiltroLead { todos, mios, deOtros }

class ListaLeadsScreen extends ConsumerStatefulWidget {
  const ListaLeadsScreen({super.key, required this.eventoId});

  final String eventoId;

  @override
  ConsumerState<ListaLeadsScreen> createState() => _ListaLeadsScreenState();
}

class _ListaLeadsScreenState extends ConsumerState<ListaLeadsScreen> {
  static const _filtroLabels = {
    _FiltroLead.todos: 'Todos',
    _FiltroLead.mios: 'Mis leads',
    _FiltroLead.deOtros: 'De otros',
  };

  final _busquedaController = TextEditingController();
  _FiltroLead _filtro = _FiltroLead.todos;
  String _busqueda = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  Widget _buildSearchField() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.input),
        boxShadow: AppColors.shadowRest,
      ),
      child: TextField(
        controller: _busquedaController,
        onChanged: (value) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() => _busqueda = value.trim().toLowerCase());
            }
          });
        },
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.ink,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar lead…',
          hintStyle: const TextStyle(color: AppColors.placeholder),
          prefixIcon: const Icon(
            Symbols.search_rounded,
            color: AppColors.placeholder,
            size: 20,
          ),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(
              color: AppColors.primaryLight,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedControls() {
    return Column(
      children: [
        SizedBox(height: 48, child: _buildSearchField()),
        const SizedBox(height: 4),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FilterChipBar(
                options: _filtroLabels.values.toList(),
                selected: _filtroLabels[_filtro]!,
                onSelected: (label) {
                  final filtro = _filtroLabels.entries
                      .firstWhere((entry) => entry.value == label)
                      .key;
                  setState(() => _filtro = filtro);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({int? total, int? mios}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Leads', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 2),
        Text(
          total == null
              ? 'Leads capturados del evento'
              : '$total ${total == 1 ? 'lead' : 'leads'} · $mios míos',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsPorEventoProvider(widget.eventoId));
    final perfilId = ref.watch(currentPerfilProvider).valueOrNull?.id;

    return CollapsingScrollScaffold(
      title: 'Leads',
      topBanner: const OfflineBanner(),
      alwaysShowActions: true,
      overlayLeading: CollapsingNavButton(
        icon: Symbols.arrow_back_ios_new_rounded,
        onTap: () => context.pop(),
      ),
      pinnedContent: _buildPinnedControls(),
      pinnedContentHeight: 112,
      scrollResetToken: '$_busqueda|$_filtro',
      onRefresh: () async =>
          ref.invalidate(leadsPorEventoProvider(widget.eventoId)),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: leadsAsync.when(
              loading: () => _buildHeader(),
              error: (_, _) => _buildHeader(),
              data: (leads) => _buildHeader(
                total: leads.length,
                mios: perfilId == null
                    ? 0
                    : leads.where((lead) => lead.perfilId == perfilId).length,
              ),
            ),
          ),
        ),
        ...leadsAsync.when(
          loading: () => [const SliverFillRemaining(child: LoadingView())],
          error: (_, _) => [
            SliverFillRemaining(
              child: ErrorView(
                message: 'No se pudieron cargar los leads.',
                onRetry: () =>
                    ref.invalidate(leadsPorEventoProvider(widget.eventoId)),
              ),
            ),
          ],
          data: (leads) {
            final filtrados = leads.where((lead) {
              if (_filtro == _FiltroLead.mios &&
                  (perfilId == null || lead.perfilId != perfilId)) {
                return false;
              }
              if (_filtro == _FiltroLead.deOtros &&
                  perfilId != null &&
                  lead.perfilId == perfilId) {
                return false;
              }
              if (_busqueda.isEmpty) return true;

              return lead.nombreCompleto.toLowerCase().contains(_busqueda) ||
                  (lead.empresa ?? '').toLowerCase().contains(_busqueda) ||
                  (lead.email ?? '').toLowerCase().contains(_busqueda);
            }).toList();

            if (leads.isEmpty) {
              return [
                const SliverFillRemaining(
                  child: EmptyStateView(
                    icon: Icons.person_off_outlined,
                    message: 'Aún no hay leads capturados en este evento.',
                  ),
                ),
              ];
            }
            if (filtrados.isEmpty) {
              return [
                const SliverFillRemaining(
                  child: EmptyStateView(
                    icon: Symbols.search_off_rounded,
                    message: 'No hay leads con estos filtros.',
                  ),
                ),
              ];
            }

            return [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverList.separated(
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.cardGap),
                  itemBuilder: (context, index) => StaggeredListItem(
                    index: index,
                    child: _LeadTile(
                      eventoId: widget.eventoId,
                      lead: filtrados[index],
                      index: index,
                    ),
                  ),
                ),
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({
    required this.eventoId,
    required this.lead,
    required this.index,
  });

  final String eventoId;
  final Lead lead;
  final int index;

  @override
  Widget build(BuildContext context) {
    final vendedor = lead.vendedorNombre;
    final pendiente = lead.pendienteDeSincronizar;
    final subtitulo = [
      lead.empresa,
      lead.email,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');

    return Pressable(
      onTap: () => context.push(RoutePaths.detalleLead(eventoId, lead.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.shadowRest,
        ),
        child: Row(
          children: [
            AvatarLead(lead: lead, size: 44, index: index),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.nombreCompleto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  if (subtitulo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (vendedor != null && vendedor.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      vendedor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                  if (pendiente) ...[
                    const SizedBox(height: 6),
                    const StatusChip(
                      label: 'Pendiente de sincronizar',
                      variant: StatusChipVariant.warning,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Symbols.chevron_right_rounded,
              color: AppColors.chevronMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class DetalleLeadScreen extends ConsumerStatefulWidget {
  const DetalleLeadScreen({
    super.key,
    required this.eventoId,
    required this.leadId,
  });

  final String eventoId;
  final String leadId;

  @override
  ConsumerState<DetalleLeadScreen> createState() => _DetalleLeadScreenState();
}

class _DetalleLeadScreenState extends ConsumerState<DetalleLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _empresaController = TextEditingController();
  final _cargoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _descripcionController = TextEditingController();
  bool _cargado = false;
  bool _guardando = false;

  /// Lo que hay guardado hoy en `fotos_urls`: una URL pública, o un marcador
  /// `local_foto://` si se capturó sin conexión y aún no se sube.
  List<String> _fotos = const [];

  /// Foto nueva ya comprimida y todavía sin subir. Tiene prioridad sobre
  /// [_fotos] al pintar y al guardar.
  Uint8List? _fotoNueva;

  @override
  void dispose() {
    _nombreController.dispose();
    _empresaController.dispose();
    _cargoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _precargar(Lead lead) {
    if (_cargado) return;
    _cargado = true;
    _nombreController.text = lead.nombreCompleto;
    _empresaController.text = lead.empresa ?? '';
    _cargoController.text = lead.cargo ?? '';
    _telefonoController.text = lead.telefono ?? '';
    _emailController.text = lead.email ?? '';
    _descripcionController.text = lead.descripcion ?? '';
    _fotos = lead.fotosUrls;
  }

  String? get _urlFotoGuardada =>
      _fotos.firstWhereOrNull((u) => !esFotoLocal(u));

  /// Marcador de la foto que todavía vive en disco, si la hay.
  String? get _marcadorPendiente => _fotos.firstWhereOrNull(esFotoLocal);

  Future<void> _elegirFoto() async {
    final bytes = await elegirImagenComprimida(
      context,
      recorteProporcion: kProporcionFotoLead,
    );
    if (bytes == null || !mounted) return;
    setState(() => _fotoNueva = bytes);
  }

  void _quitarFoto() {
    setState(() {
      _fotoNueva = null;
      _fotos = const [];
    });
  }

  /// Devuelve lo que debe quedar en `fotos_urls`. Si no se eligió una foto
  /// nueva se conserva lo que ya había: un marcador `local_foto://` que siga
  /// sin subir lo resuelve el repositorio antes de tocar Supabase.
  Future<List<String>> _resolverFotos({required bool isOnline}) async {
    final nueva = _fotoNueva;
    if (nueva == null) return _fotos;

    if (isOnline) {
      return [
        await ref.read(storageRepositoryProvider).subirFotoLead(nueva, 'jpg'),
      ];
    }

    final store = ref.read(pendingPhotoStoreProvider);
    if (!store.disponible) return const [];
    return [await store.guardar(nueva)];
  }

  /// Borra del disco las fotos pendientes que la edición dejó fuera, para no
  /// acumular archivos que ya nadie referencia.
  Future<void> _borrarFotosLocalesHuerfanas(List<String> finales) async {
    final store = ref.read(pendingPhotoStoreProvider);
    for (final marcador in _fotos.where(esFotoLocal)) {
      if (!finales.contains(marcador)) await store.borrar(marcador);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    String? valorOpcional(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    final email = valorOpcional(_emailController);
    final isOnline = ref.read(isOnlineProvider);

    try {
      final fotoDescartada = _fotoNueva != null &&
          !isOnline &&
          !ref.read(pendingPhotoStoreProvider).disponible;
      final fotos = await _resolverFotos(isOnline: isOnline);

      final cambios = <String, dynamic>{
        'nombre_completo': _nombreController.text.trim(),
        'empresa': valorOpcional(_empresaController),
        'cargo': valorOpcional(_cargoController),
        'telefono': valorOpcional(_telefonoController),
        'email': email?.toLowerCase(),
        'descripcion': valorOpcional(_descripcionController),
        'fotos_urls': fotos,
      };

      // Un lead que solo existe en la cola todavía no tiene fila en el
      // servidor: su edición se fusiona en el insert pendiente (lo resuelve
      // `enqueueUpdate`) en vez de intentar un UPDATE que fallaría.
      if (isOnline && !esIdSoloLocal(widget.leadId)) {
        await ref
            .read(leadsRepositoryProvider)
            .actualizar(widget.leadId, cambios);
      } else {
        await ref.read(syncQueueServiceProvider.notifier).enqueueUpdate(
              table: SupabaseTables.leads,
              entityId: widget.leadId,
              changes: cambios,
            );
      }
      await _borrarFotosLocalesHuerfanas(fotos);
      ref.invalidate(leadsPorEventoProvider(widget.eventoId));
      if (mounted) {
        showAppSnackBar(
          context,
          fotoDescartada
              ? 'Cambios guardados, pero sin la foto: se necesita conexión '
                  'para adjuntarla.'
              : 'Cambios guardados.',
          isError: fotoDescartada,
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

  Future<void> _eliminar() async {
    final ok = await confirmDialog(
      context,
      title: 'Eliminar lead',
      message: '¿Eliminar este lead de forma permanente?',
      confirmLabel: 'Eliminar',
    );
    if (!ok) return;

    try {
      await ref.read(leadsRepositoryProvider).eliminar(widget.leadId);
      ref.invalidate(leadsPorEventoProvider(widget.eventoId));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'No se pudo eliminar el lead.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se lee de la lista (que ya trae caché offline y los cambios encolados)
    // en vez de pedir el lead al servidor: así el detalle se abre sin
    // conexión y también sirve para leads que aún no se han sincronizado.
    final leadsAsync = ref.watch(leadsPorEventoProvider(widget.eventoId));
    final esAdmin = ref.watch(isAdminProvider);
    final esPendiente = esIdSoloLocal(widget.leadId);

    return AppScaffold(
      title: 'Editar lead',
      actions: [
        // Un insert encolado no existe en el servidor: borrarlo desde acá lo
        // dejaría en la cola y reaparecería al sincronizar.
        if (esAdmin && !esPendiente)
          NexusHeaderAction(
            icon: Symbols.delete_outline_rounded,
            tooltip: 'Eliminar lead',
            danger: true,
            onTap: _guardando ? null : _eliminar,
          ),
      ],
      body: leadsAsync.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          message: 'No se pudo cargar el lead.',
          onRetry: () =>
              ref.invalidate(leadsPorEventoProvider(widget.eventoId)),
        ),
        data: (leads) {
          final lead = leads.firstWhereOrNull((l) => l.id == widget.leadId);
          if (lead == null) {
            return const EmptyStateView(
              icon: Symbols.person_off_rounded,
              message: 'No se encontró este lead.',
            );
          }
          _precargar(lead);

          // Una foto capturada sin conexión vive en disco, no en Storage: se
          // lee por provider para no golpear el archivo en cada rebuild.
          final marcadorPendiente = _marcadorPendiente;
          final bytesPendientes = marcadorPendiente == null
              ? null
              : ref.watch(fotoPendienteBytesProvider(marcadorPendiente))
                  .valueOrNull;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xl,
              AppSpacing.screenH,
              AppSpacing.xxxl,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      AvatarInitials(name: lead.nombreCompleto, size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lead.nombreCompleto,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            if ((lead.vendedorNombre ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Capturado por ${lead.vendedorNombre}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionLabel('Foto'),
                  const SizedBox(height: 10),
                  SelectorImagen(
                    bytes: _fotoNueva ?? bytesPendientes,
                    urlExistente: _urlFotoGuardada,
                    enabled: !_guardando,
                    aspectRatio: kProporcionFotoLead,
                    anchoMaximo: kAnchoSelectorFotoLead,
                    etiquetaVacio: 'Agregar foto del lead',
                    onElegir: _elegirFoto,
                    onQuitar: (_fotoNueva == null && _fotos.isEmpty)
                        ? null
                        : _quitarFoto,
                    pieDeFoto: _fotoNueva == null && marcadorPendiente != null
                        ? const StatusChip(
                            label: 'Foto pendiente de subir',
                            variant: StatusChipVariant.warning,
                          )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _nombreController,
                    enabled: !_guardando,
                    decoration:
                        const InputDecoration(labelText: 'Nombre completo'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                  ),
                  AppSpacing.field,
                  TextFormField(
                    controller: _empresaController,
                    enabled: !_guardando,
                    decoration: const InputDecoration(labelText: 'Empresa'),
                  ),
                  AppSpacing.field,
                  TextFormField(
                    controller: _cargoController,
                    enabled: !_guardando,
                    decoration: const InputDecoration(labelText: 'Cargo'),
                  ),
                  AppSpacing.field,
                  TextFormField(
                    controller: _telefonoController,
                    enabled: !_guardando,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                  ),
                  AppSpacing.field,
                  TextFormField(
                    controller: _emailController,
                    enabled: !_guardando,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  AppSpacing.field,
                  TextFormField(
                    controller: _descripcionController,
                    enabled: !_guardando,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryGradientButton(
                    label: 'Guardar cambios',
                    loading: _guardando,
                    onPressed: _guardando ? null : _guardar,
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
