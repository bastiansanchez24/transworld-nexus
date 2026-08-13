import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_tables.dart';
import '../models/registrado.dart';
import '../offline/sync_queue_service.dart';
import '../supabase/supabase_client_provider.dart';

/// Código de error de Postgres para violación de constraint UNIQUE.
const _uniqueViolation = '23505';

class RegistradosRepository implements SyncExecutor {
  RegistradosRepository(this._client);

  final SupabaseClient _client;

  @override
  String get table => SupabaseTables.registrados;

  /// Incluye el join a `evento_bloques` para resolver la etiqueta del bloque
  /// (el Excel y la UI no deben mostrar el UUID de `bloque_id`).
  static const _selectConBloque =
      '*, ${SupabaseTables.eventoBloques}(etiqueta)';

  Future<List<Registrado>> listarPorEvento(String eventoId) async {
    final rows = await _client
        .from(SupabaseTables.registrados)
        .select(_selectConBloque)
        .eq('evento_id', eventoId)
        .order('created_at', ascending: false);
    return rows.map(Registrado.fromMap).toList();
  }

  /// Busca un asistente por id dentro de un evento concreto. Lo usa el
  /// escáner QR como respaldo cuando la lista cacheada aún no está lista
  /// o quedó desactualizada.
  Future<Registrado?> obtenerPorIdEnEvento(String id, String eventoId) async {
    final row = await _client
        .from(SupabaseTables.registrados)
        .select(_selectConBloque)
        .eq('id', id)
        .eq('evento_id', eventoId)
        .maybeSingle();
    if (row == null) return null;
    return Registrado.fromMap(row);
  }

  /// Antes de insertar, revisa si ya existe alguien con ese correo en el
  /// evento. Esto refuerza (no reemplaza) el `UNIQUE(evento_id, email)` de
  /// la base de datos: la constraint es la última línea de defensa ante
  /// condiciones de carrera; este chequeo evita el viaje redondo con error
  /// en el caso común (ver documentacion_zips_registro_pro.md Sección 17.7).
  Future<bool> existeEmailEnEvento(String eventoId, String email) async {
    final rows = await _client
        .from(SupabaseTables.registrados)
        .select('id')
        .eq('evento_id', eventoId)
        .eq('email', email.trim().toLowerCase())
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<Registrado> crear(Registrado registrado) async {
    final row = await _client
        .from(SupabaseTables.registrados)
        .insert(registrado.toInsertMap())
        .select()
        .single();
    return Registrado.fromMap(row);
  }

  /// Inserción masiva (carga por Excel). Filtra localmente los correos que
  /// ya existen en el evento y los duplicados internos del propio archivo,
  /// y deja que el `UNIQUE(evento_id, email)` de la base de datos actúe
  /// como respaldo final.
  Future<({int insertados, int omitidos})> importarLote(
    String eventoId,
    List<Registrado> registros,
  ) async {
    final vistos = <String>{};
    final unicosDelArchivo = <Registrado>[];
    for (final r in registros) {
      final email = r.email.trim().toLowerCase();
      if (email.isEmpty || vistos.contains(email)) continue;
      vistos.add(email);
      unicosDelArchivo.add(r);
    }

    if (unicosDelArchivo.isEmpty) {
      return (insertados: 0, omitidos: registros.length);
    }

    final existentesRows = await _client
        .from(SupabaseTables.registrados)
        .select('email')
        .eq('evento_id', eventoId)
        .inFilter(
          'email',
          unicosDelArchivo.map((r) => r.email.trim().toLowerCase()).toList(),
        );

    final emailsExistentes = existentesRows
        .map((r) => r['email'] as String)
        .toSet();

    final aInsertar = unicosDelArchivo
        .where((r) => !emailsExistentes.contains(r.email.trim().toLowerCase()))
        .toList();

    if (aInsertar.isEmpty) {
      return (insertados: 0, omitidos: registros.length);
    }

    await _client
        .from(SupabaseTables.registrados)
        .insert(aInsertar.map((r) => r.toInsertMap()).toList());

    return (
      insertados: aInsertar.length,
      omitidos: registros.length - aInsertar.length,
    );
  }

  Future<void> actualizar(String id, Map<String, dynamic> changes) async {
    await _client.from(SupabaseTables.registrados).update(changes).eq('id', id);
  }

  Future<void> acreditar(String id, {required String acreditadoPorId}) async {
    await actualizar(id, {
      'acreditado': true,
      'acreditado_por': acreditadoPorId,
    });
  }

  /// Solo admin puede eliminar (política `rpe_registrados_delete`).
  Future<void> eliminar(String id) async {
    await _client.from(SupabaseTables.registrados).delete().eq('id', id);
  }

  /// Envía el QR de acreditación al correo del registrado a través de la
  /// Edge Function `enviar-qr` (la misma que usaba el proyecto legado, ver
  /// Secciones 3.11/4.11 de la auditoría) y deja constancia en
  /// `email_confirmacion_enviado`. El QR codifica `registrados.id`, que es
  /// lo que lee la pantalla de acreditación por cámara.
  ///
  /// El body debe ir envuelto en `{ record: {...} }` con las columnas de
  /// `public.registrados`, exactamente como lo invocaban `EditarRegistrado`
  /// (web/móvil legado). Un body plano (`registrado_id`/`email`/…) no es
  /// compatible con la función desplegada.
  Future<void> enviarQrPorEmail(
    Registrado registrado, {
    String? nombreEvento,
  }) async {
    final record = <String, dynamic>{
      'id': registrado.id,
      'evento_id': registrado.eventoId,
      'nombre_completo': registrado.nombreCompleto,
      'email': registrado.email,
      'acreditado': registrado.acreditado,
      'rut': registrado.rut,
      'patente': registrado.patente,
      'empresa': registrado.empresa,
      'cargo': registrado.cargo,
      'telefono': registrado.telefono,
      'ingresado_por': registrado.ingresadoPor,
      'email_confirmacion_enviado': registrado.emailConfirmacionEnviado,
      'evento': ?nombreEvento,
    };
    await _client.functions.invoke(
      SupabaseFunctions.enviarQr,
      body: {'record': record},
    );
    await actualizar(registrado.id, {'email_confirmacion_enviado': true});
  }

  // ---- SyncExecutor: puente entre la cola offline y esta tabla ----

  @override
  Future<void> onInsert(Map<String, dynamic> payload) async {
    final data = Map<String, dynamic>.from(payload)
      ..remove('id')
      ..remove('acreditado_en');
    try {
      await _client.from(SupabaseTables.registrados).insert(data);
    } on PostgrestException catch (e) {
      // Si mientras estuvo offline alguien más registró el mismo correo,
      // el UNIQUE(evento_id, email) rechaza el insert. Se descarta el
      // duplicado en vez de reintentarlo por siempre.
      if (e.code == _uniqueViolation) return;
      rethrow;
    }
  }

  @override
  Future<void> onUpdate(Map<String, dynamic> payload) async {
    final id = payload['id'] as String;
    final changes = Map<String, dynamic>.from(payload['changes'] as Map);
    await _client.from(SupabaseTables.registrados).update(changes).eq('id', id);
  }

  /// Totales visibles para el dashboard. RLS acota las filas a los eventos
  /// asignados cuando la sesión corresponde al rol `user`.
  Future<({int total, int acreditados})> obtenerResumenGlobal() async {
    final resultados = await Future.wait<int>([
      _client.from(SupabaseTables.registrados).count(CountOption.exact),
      _client
          .from(SupabaseTables.registrados)
          .count(CountOption.exact)
          .eq('acreditado', true),
    ]);
    return (total: resultados[0], acreditados: resultados[1]);
  }

  Future<int> contarPorIngresadoPor(String perfilId) async {
    return _client
        .from(SupabaseTables.registrados)
        .count(CountOption.exact)
        .eq('ingresado_por', perfilId);
  }

  Future<int> contarPorAcreditadoPor(String perfilId) async {
    return _client
        .from(SupabaseTables.registrados)
        .count(CountOption.exact)
        .eq('acreditado_por', perfilId);
  }
}

final registradosRepositoryProvider = Provider<RegistradosRepository>((ref) {
  return RegistradosRepository(ref.watch(supabaseClientProvider));
});
