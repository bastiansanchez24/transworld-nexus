/// Límite de fijados personales por tipo (eventos / campañas).
const int kMaxFijadosPorTipo = 3;

/// Se lanza al intentar fijar más de [kMaxFijadosPorTipo] ítems del mismo tipo.
class FijadosLimitException implements Exception {
  const FijadosLimitException(this.tipo);

  final String tipo;

  @override
  String toString() =>
      'Solo puedes fijar hasta $kMaxFijadosPorTipo $tipo a la vez.';
}
