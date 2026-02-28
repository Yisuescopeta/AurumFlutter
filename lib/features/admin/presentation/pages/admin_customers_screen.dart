import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/admin_provider.dart';

class AdminCustomersScreen extends ConsumerStatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  ConsumerState<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends ConsumerState<AdminCustomersScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _role = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    return FutureBuilder(
      future: repo.getClients(query: _query, roleFilter: _role),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text('Error cargando clientes: ${snapshot.error}'));
        }
        final clients = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Clientes', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 12),
            AurumCard(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'Buscar por nombre o email',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(labelText: 'Rol'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Todos')),
                        DropdownMenuItem(value: 'customer', child: Text('Cliente')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (v) => setState(() => _role = v ?? 'all'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...clients.map((c) {
              final createdAtRaw = c['created_at']?.toString();
              final createdAt = createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AurumCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.navyBlue,
                      child: Text(
                        (c['full_name']?.toString().isNotEmpty == true
                                ? c['full_name'].toString()
                                : c['email']?.toString() ?? 'U')[0]
                            .toUpperCase(),
                        style: const TextStyle(color: AppTheme.gold),
                      ),
                    ),
                    title: Text(c['full_name']?.toString().isNotEmpty == true ? c['full_name'].toString() : 'Sin nombre'),
                    subtitle: Text(
                      '${c['email'] ?? 'Sin email'}\n${c['city'] ?? '-'}  -  Alta: ${Formatters.date(createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (c['role'] == 'admin' ? Colors.purple : AppTheme.gold).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        c['role'] == 'admin' ? 'ADMIN' : 'CLIENTE',
                        style: TextStyle(
                          color: c['role'] == 'admin' ? Colors.purple : AppTheme.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

