import 'lead_prefill.dart';

/// Parámetros opcionales al abrir [CrearLeadScreen] vía go_router `extra`.
class CapturarLeadRouteExtra {
  const CapturarLeadRouteExtra({this.prefill, this.eventoRegistroId});

  final LeadPrefill? prefill;

  /// Si viene del flujo QR de un evento de registro, al guardar se vuelve
  /// al menú operativo de ese evento (`/eventos/:id/usar`).
  final String? eventoRegistroId;

  static CapturarLeadRouteExtra from(Object? extra) {
    if (extra is CapturarLeadRouteExtra) return extra;
    if (extra is LeadPrefill) {
      return CapturarLeadRouteExtra(prefill: extra);
    }
    return const CapturarLeadRouteExtra();
  }
}
