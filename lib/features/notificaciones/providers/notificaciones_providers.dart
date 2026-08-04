import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_tables.dart';
import '../../../data/models/notificacion.dart';
import '../../../data/repositories/notificaciones_repository.dart';
import '../../../data/supabase/supabase_client_provider.dart';
import '../../auth/providers/auth_providers.dart';

final notificacionesInboxProvider =
    FutureProvider<List<NotificacionInbox>>((ref) async {
  ref.watch(authStateChangesProvider);
  ref.watch(notificacionesRealtimeTickProvider);
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

  ref.listen(authStateChangesProvider, (_, next) {
    if (next.valueOrNull?.session != null) {
      subscribe();
    } else {
      unsubscribe();
    }
  });

  if (ref.read(authStateChangesProvider).valueOrNull?.session != null) {
    subscribe();
  }

  ref.onDispose(unsubscribe);
});
