import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import 'app_error.dart';

abstract interface class NotificationRepository {
  /// Notifications visibles (rappels arrivés à échéance compris), les plus récentes d'abord.
  Future<List<AppNotification>> list();

  Future<int> unreadCount();

  Future<void> markAllRead();
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  static const _pageSize = 50;

  @override
  Future<List<AppNotification>> list() => _guard(() async {
    final rows = await _client
        .from('notifications')
        .select()
        .order('scheduled_for', ascending: false)
        .limit(_pageSize);
    return rows.map(AppNotification.fromJson).toList();
  });

  @override
  Future<int> unreadCount() => _guard(() async {
    final response = await _client
        .from('notifications')
        .select('id')
        .isFilter('read_at', null)
        .count(CountOption.exact);
    return response.count;
  });

  @override
  Future<void> markAllRead() =>
      _guard(() => _client.rpc('mark_notifications_read'));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw AppError.from(e);
    }
  }
}
