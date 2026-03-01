import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/notification_preferences.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            onPressed: () => _openPreferences(context, ref),
            tooltip: 'Preferencias',
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            onPressed: () => _markAllAsRead(context, ref),
            tooltip: 'Marcar todas como leidas',
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsListProvider);
          ref.invalidate(unreadNotificationsCountProvider);
          await ref.read(notificationsListProvider.future);
        },
        child: notificationsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 60),
                        SizedBox(height: 12),
                        Text('No tienes notificaciones todavia'),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final item = items[index];
                return _NotificationTile(
                  item: item,
                  onTap: () => _handleNotificationTap(context, ref, item),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: items.length,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  Future<void> _markAllAsRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationsControllerProvider.notifier).markAllAsRead();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificaciones marcadas como leidas')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    if (!notification.isRead) {
      await ref.read(notificationsControllerProvider.notifier).markAsRead(
            notification.id,
          );
    }

    final route = notification.payload['route']?.toString().trim();
    if (route == '/notifications') return;
    if (route != null &&
        route.isNotEmpty &&
        route != '/product-detail' &&
        context.mounted) {
      context.push(route);
      return;
    }

    final productId = notification.productId;
    if (productId == null || productId.isEmpty) return;

    try {
      final product = await ref.read(productRepositoryProvider).getProductById(
            productId,
          );
      if (product == null || !context.mounted) return;
      context.push('/product-detail', extra: product);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el producto')),
      );
    }
  }

  Future<void> _openPreferences(BuildContext context, WidgetRef ref) async {
    final rootContext = context;
    final basePrefs =
        await ref.read(notificationPreferencesProvider.future).catchError(
              (_) => NotificationPreferences.defaults(),
            );
    if (!rootContext.mounted) return;

    var working = basePrefs;
    final quietStartController = TextEditingController(
      text: _toHourText(working.quietHoursStart),
    );
    final quietEndController = TextEditingController(
      text: _toHourText(working.quietHoursEnd),
    );

    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      builder: (bottomContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preferencias de notificaciones',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        value: working.enabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activar notificaciones'),
                        onChanged: (value) => setModalState(
                          () => working = working.copyWith(enabled: value),
                        ),
                      ),
                      SwitchListTile(
                        value: working.favoriteDiscountEnabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Avisos de favoritos en descuento'),
                        onChanged: working.enabled
                            ? (value) => setModalState(
                                  () => working = working.copyWith(
                                    favoriteDiscountEnabled: value,
                                  ),
                                )
                            : null,
                      ),
                      SwitchListTile(
                        value: working.recommendationsEnabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Recomendaciones personalizadas'),
                        onChanged: working.enabled
                            ? (value) => setModalState(
                                  () => working = working.copyWith(
                                    recommendationsEnabled: value,
                                  ),
                                )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Horario silencioso (HH:MM, opcional)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quietStartController,
                              enabled: working.enabled,
                              decoration: const InputDecoration(
                                labelText: 'Desde',
                                hintText: '22:00',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: quietEndController,
                              enabled: working.enabled,
                              decoration: const InputDecoration(
                                labelText: 'Hasta',
                                hintText: '08:00',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Zona horaria: ${working.timezone}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final start = _normalizeHour(quietStartController.text);
                            final end = _normalizeHour(quietEndController.text);
                            if ((quietStartController.text.trim().isNotEmpty &&
                                    start == null) ||
                                (quietEndController.text.trim().isNotEmpty &&
                                    end == null)) {
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Formato invalido. Usa HH:MM (ej 22:30)'),
                                ),
                              );
                              return;
                            }

                            final next = working.copyWith(
                              quietHoursStart: start,
                              quietHoursEnd: end,
                            );
                            try {
                              await ref
                                  .read(notificationsControllerProvider.notifier)
                                  .savePreferences(next);
                              if (!rootContext.mounted) return;
                              Navigator.of(bottomContext).pop();
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                const SnackBar(content: Text('Preferencias guardadas')),
                              );
                            } catch (e) {
                              if (!rootContext.mounted) return;
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                SnackBar(
                                  content: Text('No se pudo guardar: $e'),
                                ),
                              );
                            }
                          },
                          child: const Text('Guardar preferencias'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    quietStartController.dispose();
    quietEndController.dispose();
  }

  String? _normalizeHour(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    final parts = v.split(':');
    if (parts.length != 2) return null;
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null) return null;
    if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return null;
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  String _toHourText(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final parts = value.trim().split(':');
    if (parts.length < 2) return '';
    final hh = parts[0].padLeft(2, '0');
    final mm = parts[1].padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDiscount = item.type == 'favorite_discount';
    final isBroadcast = item.type == 'admin_broadcast';
    final icon = isDiscount
        ? Icons.local_offer_rounded
        : isBroadcast
            ? Icons.campaign_outlined
            : Icons.auto_awesome_rounded;
    final iconColor = isDiscount
        ? const Color(0xFFB5483F)
        : isBroadcast
            ? const Color(0xFF3B5CC4)
            : AppTheme.navyBlue;

    return Material(
      color: item.isRead ? Colors.white : const Color(0xFFFFF9E9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navyBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          Formatters.date(item.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
