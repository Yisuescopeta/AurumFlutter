import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/app_notification.dart';
import '../../domain/models/notification_preferences.dart';

class NotificationsRepository {
  NotificationsRepository(this._supabase);

  final SupabaseClient _supabase;

  bool _isMissingTableError(Object error) {
    if (error is! PostgrestException) return false;
    final code = error.code ?? '';
    if (code == '42P01') return true;
    final message = error.message.toLowerCase();
    return message.contains('does not exist') ||
        message.contains('relation') ||
        message.contains('not found');
  }

  String _requireUserId() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesion para usar notificaciones');
    }
    return user.id;
  }

  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    try {
      final userId = _requireUserId();
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response
          .map((e) => AppNotification.fromJson(e))
          .toList();
    } catch (e) {
      if (_isMissingTableError(e)) return const [];
      rethrow;
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final userId = _requireUserId();
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      if (_isMissingTableError(e)) return 0;
      rethrow;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final userId = _requireUserId();
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId)
          .eq('user_id', userId);
    } catch (e) {
      if (_isMissingTableError(e)) return;
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final userId = _requireUserId();
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      if (_isMissingTableError(e)) return;
      rethrow;
    }
  }

  Future<NotificationPreferences> getPreferences() async {
    try {
      final userId = _requireUserId();
      final response = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return NotificationPreferences.defaults();
      }
      return NotificationPreferences.fromJson(response);
    } catch (e) {
      if (_isMissingTableError(e)) return NotificationPreferences.defaults();
      rethrow;
    }
  }

  Future<void> savePreferences(NotificationPreferences preferences) async {
    try {
      final userId = _requireUserId();
      final payload = {
        'user_id': userId,
        ...preferences.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _supabase
          .from('notification_preferences')
          .upsert(payload, onConflict: 'user_id');
    } catch (e) {
      if (_isMissingTableError(e)) return;
      rethrow;
    }
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    String? deviceLabel,
    String? appVersion,
  }) async {
    _requireUserId();
    await _supabase.functions.invoke(
      'notifications-register-device',
      body: {
        'fcm_token': token,
        'platform': platform,
        'device_label': deviceLabel,
        'app_version': appVersion,
      },
    );
  }
}
