import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/notification_preferences.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(Supabase.instance.client);
});

final notificationsListProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(notificationsRepositoryProvider).getNotifications();
});

final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  return ref.watch(notificationsRepositoryProvider).getUnreadCount();
});

final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return NotificationPreferences.defaults();
  return ref.watch(notificationsRepositoryProvider).getPreferences();
});

class NotificationsController extends StateNotifier<AsyncValue<void>> {
  NotificationsController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> markAsRead(String notificationId) async {
    state = const AsyncLoading();
    try {
      await _ref.read(notificationsRepositoryProvider).markAsRead(notificationId);
      _ref.invalidate(notificationsListProvider);
      _ref.invalidate(unreadNotificationsCountProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    state = const AsyncLoading();
    try {
      await _ref.read(notificationsRepositoryProvider).markAllAsRead();
      _ref.invalidate(notificationsListProvider);
      _ref.invalidate(unreadNotificationsCountProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> savePreferences(NotificationPreferences preferences) async {
    state = const AsyncLoading();
    try {
      await _ref
          .read(notificationsRepositoryProvider)
          .savePreferences(preferences);
      _ref.invalidate(notificationPreferencesProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, AsyncValue<void>>((ref) {
  return NotificationsController(ref);
});
