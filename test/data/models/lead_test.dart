import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/data/models/lead.dart';

void main() {
  test('capturador_nombre tiene prioridad sobre el embed legacy', () {
    final lead = Lead.fromMap({
      'id': 'lead-1',
      'evento_id': 'evento-1',
      'nombre_completo': 'María González',
      'capturador_nombre': 'Ana Pérez',
      'perfiles': {'nombre_completo': 'Nombre legacy'},
    });

    expect(lead.vendedorNombre, 'Ana Pérez');
    expect(lead.toCacheMap()['capturador_nombre'], 'Ana Pérez');
  });

  final lead = Lead(
    id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    eventoId: 'evento-1',
    nombreCompleto: 'María González',
    empresa: 'Transworld',
    cargo: 'Gerente comercial',
    telefono: '+56 9 1234 5678',
    email: 'maria@transworld.cl',
    descripcion: 'Interesada en el plan anual.',
    fotosUrls: const ['https://cdn/1.jpg', 'https://cdn/2.jpg'],
    perfilId: 'perfil-9',
    createdAt: DateTime.utc(2026, 3, 14, 9, 30),
    vendedorNombre: 'Pedro Soto',
  );

  group('Lead.toCacheMap', () {
    // La caché offline guarda el lead con toCacheMap y lo relee con fromMap:
    // si un campo nuevo no viaja en toCacheMap, se pierde en silencio al
    // quedarse sin conexión.
    test('sobrevive el viaje de ida y vuelta por la caché', () {
      final revivido = Lead.fromMap(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(lead.toCacheMap())) as Map,
        ),
      );

      expect(revivido.id, lead.id);
      expect(revivido.eventoId, lead.eventoId);
      expect(revivido.nombreCompleto, lead.nombreCompleto);
      expect(revivido.empresa, lead.empresa);
      expect(revivido.cargo, lead.cargo);
      expect(revivido.telefono, lead.telefono);
      expect(revivido.email, lead.email);
      expect(revivido.descripcion, lead.descripcion);
      expect(revivido.fotosUrls, lead.fotosUrls);
      expect(revivido.perfilId, lead.perfilId);
      expect(revivido.createdAt, lead.createdAt);
      expect(revivido.vendedorNombre, lead.vendedorNombre);
    });

    test('conserva los campos opcionales vacíos', () {
      const minimo = Lead(
        id: 'id-1',
        eventoId: 'evento-1',
        nombreCompleto: 'Sin datos',
      );

      final revivido = Lead.fromMap(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(minimo.toCacheMap())) as Map,
        ),
      );

      expect(revivido.nombreCompleto, 'Sin datos');
      expect(revivido.empresa, isNull);
      expect(revivido.descripcion, isNull);
      expect(revivido.vendedorNombre, isNull);
      expect(revivido.createdAt, isNull);
      expect(revivido.fotosUrls, isEmpty);
    });

    test('un lead cacheado no se marca como pendiente de sincronizar', () {
      final revivido = Lead.fromMap(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(lead.toCacheMap())) as Map,
        ),
      );

      expect(revivido.pendienteDeSincronizar, isFalse);
    });
  });

  group('Lead.conCambiosPendientes', () {
    test('aplica los campos editados', () {
      final editado = lead.conCambiosPendientes({
        'nombre_completo': 'María González Pérez',
        'empresa': 'Otra Empresa',
      });

      expect(editado.nombreCompleto, 'María González Pérez');
      expect(editado.empresa, 'Otra Empresa');
    });

    test('vaciar un campo lo deja en null', () {
      final editado = lead.conCambiosPendientes({'empresa': null});

      expect(editado.empresa, isNull);
    });

    test('una columna ausente conserva el valor actual', () {
      final editado = lead.conCambiosPendientes({'empresa': 'Otra'});

      expect(editado.cargo, lead.cargo);
      expect(editado.email, lead.email);
      expect(editado.descripcion, lead.descripcion);
    });

    test('no pierde lo que no viaja en los cambios', () {
      final editado = lead.conCambiosPendientes({'empresa': 'Otra'});

      expect(editado.id, lead.id);
      expect(editado.fotosUrls, lead.fotosUrls);
      expect(editado.createdAt, lead.createdAt);
      expect(editado.vendedorNombre, lead.vendedorNombre);
    });

    // `fotos_urls` es una lista, no un `String?`: si se tratara como los demás
    // campos, una foto adjuntada sin conexión no se vería hasta sincronizar.
    test('aplica una foto adjuntada sin conexión', () {
      final editado = lead.conCambiosPendientes({
        'fotos_urls': ['local_foto:///datos/leads_pendientes/a.jpg'],
      });

      expect(editado.fotosUrls, ['local_foto:///datos/leads_pendientes/a.jpg']);
    });

    test('quitar la foto deja la lista vacía', () {
      final editado = lead.conCambiosPendientes({'fotos_urls': <String>[]});

      expect(editado.fotosUrls, isEmpty);
    });

    test('el insert offline lleva foto local y los campos', () {
      final pendiente = Lead(
        id: '',
        eventoId: 'evento-1',
        nombreCompleto: 'María González',
        empresa: 'Transworld',
        email: 'maria@transworld.cl',
        fotosUrls: const ['local_foto:///datos/leads_pendientes/a.jpg'],
        perfilId: 'perfil-9',
      );

      expect(pendiente.toInsertMap()['fotos_urls'], [
        'local_foto:///datos/leads_pendientes/a.jpg',
      ]);
      expect(pendiente.toInsertMap()['nombre_completo'], 'María González');
      expect(pendiente.toInsertMap()['empresa'], 'Transworld');
      expect(pendiente.toInsertMap()['email'], 'maria@transworld.cl');
    });

    test('queda marcado como pendiente de sincronizar', () {
      expect(lead.pendienteDeSincronizar, isFalse);
      expect(
        lead.conCambiosPendientes({'empresa': 'Otra'}).pendienteDeSincronizar,
        isTrue,
      );
    });
  });
}
