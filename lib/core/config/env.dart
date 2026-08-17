import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Acceso centralizado a la configuración de entorno.
///
/// Corrige un problema de higiene detectado en la auditoría del proyecto
/// legado (documentacion_zips_registro_pro.md, Sección 17.11): allí un
/// `.env` real quedó embebido dentro del ZIP entregado pese a estar en
/// `.gitignore`. Acá el `.env` real NUNCA se versiona (ver `.gitignore` y
/// `.env.example`); esta clase solo sabe leerlo y falla de forma explícita
/// y temprana si falta, en vez de dejar que Supabase falle más adelante
/// con errores confusos.
class Env {
  Env._();

  static Future<void> load() => dotenv.load(fileName: '.env');

  static String get supabaseUrl => _require('SUPABASE_URL');

  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  static String get bucketImagenes =>
      dotenv.env['SUPABASE_BUCKET_IMAGENES'] ?? 'imagenes';

  static String get bucketFotosLeads =>
      dotenv.env['SUPABASE_BUCKET_FOTOS_LEADS'] ?? 'leads-privados';

  static String get bucketPlantillas =>
      dotenv.env['SUPABASE_BUCKET_PLANTILLAS'] ?? 'plantillas';

  /// Base URL del subdominio de eventos, usada para armar el enlace de
  /// autoregistro público (ver
  /// features/registro/screens/registro_por_cliente_screen.dart).
  /// La app de administración vive en https://regispro.transworld.cl/.
  static String get appPublicBaseUrl =>
      dotenv.env['APP_PUBLIC_BASE_URL'] ?? 'https://eventos.transworld.cl/';

  /// Owner del repo GitHub usado como fuente OTA (`/releases/latest`).
  static String get githubOwner =>
      dotenv.env['GITHUB_OWNER'] ?? 'bastiansanchez24';

  /// Nombre del repo GitHub usado como fuente OTA.
  static String get githubRepo =>
      dotenv.env['GITHUB_REPO'] ?? 'transworld-nexus';

  /// Canal de actualizaciones (reservado; v1 solo usa `stable`).
  static String get updateChannel => dotenv.env['UPDATE_CHANNEL'] ?? 'stable';

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty || value.startsWith('TU_')) {
      throw StateError(
        'Falta configurar "$key" en el archivo .env (copia .env.example a '
        '.env y completa los valores reales de tu proyecto Supabase).',
      );
    }
    return value;
  }
}
