import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/connectivity_service.dart';
import '../../core/network/offline_policy.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/capturador/providers/capturador_providers.dart';
import '../../features/eventos/providers/eventos_providers.dart';
import '../../features/fijados/providers/fijados_providers.dart';
import '../../features/home/providers/home_dashboard_providers.dart';
import '../../features/home/providers/home_featured_providers.dart';
import '../../features/registrados/providers/registrados_providers.dart';
import '../../features/usuarios/providers/usuarios_providers.dart';
import '../images/offline_image_store.dart';
import '../models/evento.dart';
import '../models/evento_lead.dart';
import 'offline_cache_tables.dart';
import 'offline_read_cache.dart';

/// Etapas del snapshot, en el orden en que se ejecutan.
enum SnapshotEtapa {
  perfil,
  catalogo,
  actividades,
  usuarios,
  home,
  listas,
  fotos;

  String get titulo => switch (this) {
    SnapshotEtapa.perfil => 'Perfil',
    SnapshotEtapa.catalogo => 'Eventos',
    SnapshotEtapa.actividades => 'Actividades de captura',
    SnapshotEtapa.usuarios => 'Usuarios',
    SnapshotEtapa.home => 'Inicio',
    SnapshotEtapa.listas => 'Asistentes y leads',
    SnapshotEtapa.fotos => 'Imágenes',
  };
}

class SnapshotProgreso {
  const SnapshotProgreso({
    required this.etapa,
    this.completados = 0,
    this.total = 0,
  });

  final SnapshotEtapa etapa;
  final int completados;
  final int total;

  double get fraccion {
    final indice = SnapshotEtapa.values.indexOf(etapa);
    final base = indice / SnapshotEtapa.values.length;
    if (total <= 0) return base;
    return base + (completados / total) / SnapshotEtapa.values.length;
  }
}

class SnapshotEstado {
  const SnapshotEstado({
    this.enCurso = false,
    this.esPrimeraPasada = false,
    this.progreso,
    this.ultimoExito,
    this.errores = const [],
  });

  final bool enCurso;

  /// La pasada en curso arrancó sin ninguna copia en disco. Solo entonces el
  /// splash espera: con caché se entra de inmediato y se refresca por detrás.
  final bool esPrimeraPasada;
  final SnapshotProgreso? progreso;
  final DateTime? ultimoExito;

  /// Etapas que fallaron en la última pasada. Un fallo parcial no invalida el
  /// resto: lo que sí se bajó queda guardado.
  final List<String> errores;

  SnapshotEstado copyWith({
    bool? enCurso,
    bool? esPrimeraPasada,
    SnapshotProgreso? progreso,
    DateTime? ultimoExito,
    List<String>? errores,
    bool limpiarProgreso = false,
  }) {
    return SnapshotEstado(
      enCurso: enCurso ?? this.enCurso,
      esPrimeraPasada: esPrimeraPasada ?? this.esPrimeraPasada,
      progreso: limpiarProgreso ? null : (progreso ?? this.progreso),
      ultimoExito: ultimoExito ?? this.ultimoExito,
      errores: errores ?? this.errores,
    );
  }
}

/// Baja de una pasada todo lo que la app necesita para operar sin red.
///
/// No inventa consultas propias: dispara los mismos providers que usa la UI,
/// que ya saben respaldarse en [OfflineReadCache]. Así no hay dos caminos que
/// puedan divergir —uno para pintar y otro para sincronizar— que es
/// exactamente el error que tenía el proyecto legado con sus dos colas.
class SnapshotService extends StateNotifier<SnapshotEstado> {
  SnapshotService(this._ref) : super(const SnapshotEstado());

  final Ref _ref;

  bool _metadatosRestaurados = false;

  /// Recupera del disco la marca de la última bajada.
  ///
  /// Es perezoso a propósito: leer la caché arrastra `appBootstrapProvider`, y
  /// hacerlo en el constructor obligaría a que cualquiera que solo quiera
  /// *consultar* el estado —el splash, por ejemplo— tenga el bootstrap ya
  /// resuelto. Idempotente: se puede llamar desde un `build`.
  void restaurarMetadatosSiHaceFalta() {
    if (_metadatosRestaurados) return;
    _metadatosRestaurados = true;
    final filas = _ref
        .read(offlineReadCacheProvider)
        .leerGlobal(
          tabla: OfflineCacheTables.syncMeta,
          desdeFila: (fila) => fila['ultimo_exito_at']?.toString(),
        );
    final marca = filas?.firstOrNull;
    if (marca == null) return;
    state = state.copyWith(ultimoExito: DateTime.tryParse(marca));
  }

  /// `true` si ya hay una copia utilizable en disco.
  ///
  /// El splash solo debe bloquearse la primera vez: con caché se entra de
  /// inmediato y el refresco va por detrás.
  bool get hayCacheUtilizable {
    final eventos = _ref
        .read(offlineReadCacheProvider)
        .leerGlobal(
          tabla: OfflineCacheTables.eventos,
          desdeFila: Evento.fromMap,
        );
    return eventos != null;
  }

  /// Eventos que se bajan enteros (listas y fotos).
  ///
  /// Mismo criterio que `eventoExternoOperable`: activo y no finalizado. Un
  /// evento pausado por el admin no ocupa disco en el teléfono.
  static List<Evento> eventosDelSnapshot(List<Evento> catalogo) {
    return catalogo.where((e) => e.activo && !e.yaOcurrio).toList();
  }

  /// Actividades de captura que se bajan enteras. Las finalizadas dejan de
  /// refrescarse, pero su copia **no** se borra: si el evento termina a
  /// medianoche mientras alguien sigue capturando, vaciarle la lista en plena
  /// feria es peor que conservar un dato viejo.
  static List<EventoLead> actividadesDelSnapshot(List<EventoLead> catalogo) {
    return catalogo.where((e) => !e.yaOcurrio).toList();
  }

  /// Campañas que el snapshot pide al servidor.
  ///
  /// El externo solo opera las ligadas a sus eventos de registro. Pedir el
  /// resumen de las demás dispara `42501` ("Sin acceso al resumen de la
  /// campaña") y ensuciaba la etapa de listas aunque los leads sí se
  /// hubieran bajado.
  static List<EventoLead> campanasDelSnapshot({
    required List<EventoLead> actividades,
    required List<Evento> eventosVisibles,
    required bool esExterno,
  }) {
    final vigentes = actividadesDelSnapshot(actividades);
    if (!esExterno) return vigentes;

    final ids = eventosVisibles.map((e) => e.id).toSet();
    final nombres = {
      for (final evento in eventosVisibles) evento.nombre.trim().toLowerCase(),
    };
    return vigentes.where((campana) {
      final origen = campana.eventoOrigenId?.trim();
      if (origen != null && origen.isNotEmpty) return ids.contains(origen);
      return nombres.contains(campana.nombre.trim().toLowerCase());
    }).toList();
  }

  /// El RPC de conteos rechazó la campaña. Los leads de esa actividad ya
  /// pueden estar en disco; no vale marcar toda la etapa como fallida.
  static bool esErrorSinAccesoResumen(Object error) {
    return error.toString().toLowerCase().contains(
      'sin acceso al resumen de la campaña',
    );
  }

  Future<void> ejecutar() async {
    restaurarMetadatosSiHaceFalta();
    if (state.enCurso) return;
    if (!supportsOfflineCacheAqui) return;
    if (!_ref.read(isOnlineProvider)) return;

    state = state.copyWith(
      enCurso: true,
      esPrimeraPasada: !hayCacheUtilizable,
      errores: const [],
    );
    final errores = <String>[];

    Future<T?> etapa<T>(
      SnapshotEtapa etapa,
      Future<T> Function() accion, {
      int completados = 0,
      int total = 0,
    }) async {
      state = state.copyWith(
        progreso: SnapshotProgreso(
          etapa: etapa,
          completados: completados,
          total: total,
        ),
      );
      try {
        return await accion();
      } catch (e) {
        // Un fallo parcial no aborta la pasada: lo ya guardado sigue siendo
        // útil y la etapa se reintenta en la próxima sincronización.
        developer.log('Etapa ${etapa.name} falló: $e', name: 'SnapshotService');
        errores.add('${etapa.titulo}: ${_mensaje(e)}');
        return null;
      }
    }

    try {
      await etapa(SnapshotEtapa.perfil, () async {
        _ref.invalidate(currentPerfilProvider);
        return _ref.read(currentPerfilProvider.future);
      });

      final catalogo =
          await etapa(SnapshotEtapa.catalogo, () async {
            _ref.invalidate(eventosListProvider);
            return _ref.read(eventosListProvider.future);
          }) ??
          const <Evento>[];

      final actividades =
          await etapa(SnapshotEtapa.actividades, () async {
            _ref.invalidate(eventosLeadsListProvider);
            return _ref.read(eventosLeadsListProvider.future);
          }) ??
          const <EventoLead>[];

      await etapa(SnapshotEtapa.usuarios, () async {
        _ref.invalidate(usuariosListProvider);
        return _ref.read(usuariosListProvider.future);
      });

      await etapa(SnapshotEtapa.home, () async {
        _ref.invalidate(eventosFijadosProvider);
        _ref.invalidate(campanasFijadasProvider);
        _ref.invalidate(homeDashboardProvider);
        _ref.invalidate(homeFeaturedItemsProvider);
        await _ref.read(homeDashboardProvider.future);
        return _ref.read(homeFeaturedItemsProvider.future);
      });

      // Los registrados cuelgan de un evento y los leads de una actividad de
      // captura: son tablas distintas y hay que recorrer ambas listas.
      final perfil = _ref.read(currentPerfilProvider).valueOrNull;
      final eventos = eventosDelSnapshot(catalogo);
      final campanas = campanasDelSnapshot(
        actividades: actividades,
        eventosVisibles: catalogo,
        esExterno: perfil?.isExterno ?? false,
      );
      final total = eventos.length + campanas.length;
      var hechos = 0;

      for (final evento in eventos) {
        await etapa(
          SnapshotEtapa.listas,
          () async {
            _ref.invalidate(registradosPorEventoProvider(evento.id));
            await _ref.read(registradosPorEventoProvider(evento.id).future);
          },
          completados: hechos,
          total: total,
        );
        hechos++;
      }

      for (final campana in campanas) {
        await etapa(
          SnapshotEtapa.listas,
          () async {
            _ref.invalidate(leadsPorEventoProvider(campana.id));
            await _ref.read(leadsPorEventoProvider(campana.id).future);
            try {
              _ref.invalidate(leadsResumenRemotoProvider(campana.id));
              await _ref.read(leadsResumenRemotoProvider(campana.id).future);
            } catch (e) {
              if (!esErrorSinAccesoResumen(e)) rethrow;
            }
          },
          completados: hechos,
          total: total,
        );
        hechos++;
      }

      // Las fotos van al final a propósito: si fallan, las listas ya están
      // guardadas y la app opera igual, solo con placeholders.
      await etapa(SnapshotEtapa.fotos, () async {
        final store = _ref.read(offlineImageStoreProvider);
        if (!store.disponible) return;

        final urls = <String>{
          ...eventos.map((e) => e.imagenUrl ?? ''),
          ...campanas.map((c) => c.imagenUrl ?? ''),
          ...(_ref.read(usuariosListProvider).valueOrNull ?? const []).map(
            (p) => p.fotoUrl ?? '',
          ),
        }..removeWhere((url) => url.isEmpty);

        var descargadas = 0;
        for (final url in urls) {
          await store.prefetch(url);
          descargadas++;
          state = state.copyWith(
            progreso: SnapshotProgreso(
              etapa: SnapshotEtapa.fotos,
              completados: descargadas,
              total: urls.length,
            ),
          );
        }
      });

      await _guardarMarca();
    } finally {
      state = state.copyWith(
        enCurso: false,
        esPrimeraPasada: false,
        errores: errores,
        limpiarProgreso: true,
      );
    }
  }

  Future<void> _guardarMarca() async {
    final ahora = DateTime.now();
    await _ref.read(offlineReadCacheProvider).guardarGlobal(
      OfflineCacheTables.syncMeta,
      [
        {'ultimo_exito_at': ahora.toIso8601String()},
      ],
    );
    state = state.copyWith(ultimoExito: ahora);
  }

  static String _mensaje(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}

final snapshotServiceProvider =
    StateNotifierProvider<SnapshotService, SnapshotEstado>((ref) {
      return SnapshotService(ref);
    });

/// `true` mientras la **primera** bajada completa sigue en curso.
///
/// Es lo único que justifica retener el splash: sin copia previa la app no
/// tiene nada que mostrar. En aperturas siguientes se entra con disco y el
/// refresco va por detrás.
final esperandoPrimerSnapshotProvider = Provider<bool>((ref) {
  final estado = ref.watch(snapshotServiceProvider);
  return estado.enCurso && estado.esPrimeraPasada;
});

/// Mantiene vivo el disparo automático del snapshot. Se lee una vez cerca de
/// la raíz (ver `app.dart`).
final snapshotAutoStartProvider = Provider<void>((ref) {
  void lanzar() {
    if (ref.read(currentPerfilProvider).valueOrNull == null) return;
    ref.read(snapshotServiceProvider.notifier).ejecutar();
  }

  // Perfil resuelto: primera bajada (o refresco) de la sesión.
  ref.listen(currentPerfilProvider, (_, next) {
    if (next.valueOrNull != null) lanzar();
  });

  // Al recuperar la red se vuelve a bajar el set activo.
  ref.listen(connectivityStreamProvider, (previous, next) {
    if (previous?.valueOrNull == false && next.valueOrNull == true) lanzar();
  });

  if (ref.read(currentPerfilProvider).valueOrNull != null) lanzar();
});
