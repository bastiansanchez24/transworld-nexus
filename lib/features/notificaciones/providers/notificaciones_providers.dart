import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../data/models/notificacion.dart';
import '../../../data/repositories/notificaciones_repository.dart';
import '../../../data/supabase/supabase_client_provider.dart';
import '../../auth/providers/auth_providers.dart';

final notificacionesInboxProvider = FutureProvider<List<NotificacionInbox>>((
  ref,
) async {
  ref.watch(authStateChangesProvider);
  ref.watch(notificacionesRealtimeTickProvider);
  final perfil = await ref.watch(currentPerfilProvider.future);
  if (perfil?.canAccessNotifications != true) return const [];
  return ref.watch(notificacionesRepositoryProvider).listar();
});

final notificacionesNoLeidasProvider = Provider<int>((ref) {
  final async = ref.watch(notificacionesInboxProvider);
  return async.maybeWhen(
    data: (lista) => lista.where((n) => !n.leida).length,
    orElse: () => 0,
  );
});

/// Incrementa en cada INSERT realtime para invalidar el inbox.
final notificacionesRealtimeTickProvider = StateProvider<int>((ref) => 0);

final notificacionesRealtimeSubscriptionProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  RealtimeChannel? channel;

  void subscribe() {
    if (channel != null) return;
    channel = client
        .channel('notificaciones_inbox')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseTables.notificaciones,
          callback: (_) {
            ref.read(notificacionesRealtimeTickProvider.notifier).state++;
          },
        )
        .subscribe();
  }

  void unsubscribe() {
    channel?.unsubscribe();
    channel = null;
  }

  void syncSubscription() {
    final session = ref.read(authStateChangesProvider).valueOrNull?.session;
    final perfil = ref.read(currentPerfilProvider).valueOrNull;
    if (session != null && perfil?.canAccessNotifications == true) {
      subscribe();
    } else {
      unsubscribe();
    }
  }

  ref.listen(authStateChangesProvider, (_, _) => syncSubscription());
  ref.listen(currentPerfilProvider, (_, _) => syncSubscription());
  syncSubscription();

  ref.onDispose(unsubscribe);
});
