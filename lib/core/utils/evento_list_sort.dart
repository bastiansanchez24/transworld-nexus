/// Orden de listado:
/// 1. Fijados antes que no fijados.
/// 2. Próximos antes que finalizados.
/// 3. Próximos: fecha ascendente (más cercano arriba).
/// 4. Finalizados: fecha descendente (más reciente arriba).
int compareEventoListItems<T>({
  required T a,
  required T b,
  required Set<String> fijados,
  required String Function(T) id,
  required DateTime Function(T) fecha,
  required bool Function(T) finalizado,
}) {
  final aFijado = fijados.contains(id(a));
  final bFijado = fijados.contains(id(b));
  if (aFijado != bFijado) return aFijado ? -1 : 1;

  final aFinalizado = finalizado(a);
  final bFinalizado = finalizado(b);
  if (aFinalizado != bFinalizado) return aFinalizado ? 1 : -1;

  if (!aFinalizado) {
    return fecha(a).compareTo(fecha(b));
  }
  return fecha(b).compareTo(fecha(a));
}

void ordenarEventoListItems<T>({
  required List<T> items,
  required Set<String> fijados,
  required String Function(T) id,
  required DateTime Function(T) fecha,
  required bool Function(T) finalizado,
}) {
  items.sort(
    (a, b) => compareEventoListItems(
      a: a,
      b: b,
      fijados: fijados,
      id: id,
      fecha: fecha,
      finalizado: finalizado,
    ),
  );
}
