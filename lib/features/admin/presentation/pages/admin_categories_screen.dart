import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design_system/widgets/aurum_app_bar_title.dart';
import '../../../../core/design_system/widgets/aurum_card.dart';
import '../providers/admin_provider.dart';
import '../../../../core/design_system/widgets/aurum_loader.dart';

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  int _refreshTick = 0;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const AurumAppBarTitle('Categorias')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_refreshTick),
        future: repo.getCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AurumCenteredLoader();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudieron cargar las categorias: ${snapshot.error}',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _refreshTick++),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final categories = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gestion de categorias',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _createCategory,
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva categoria'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                const AurumCard(
                  child: Text('Todavia no hay categorias. Crea la primera.'),
                ),
              ...categories.map((c) {
                final name = c['name']?.toString() ?? '-';
                final active = c['is_active'] != false;
                final desc = c['description']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AurumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Chip(label: Text(active ? 'Activa' : 'Inactiva')),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(desc),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createCategory() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    var isActive = true;

    String slugify(String input) {
      final lowered = input.toLowerCase().trim();
      final dashed = lowered.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      final cleaned = dashed.replaceAll(RegExp(r'-+'), '-');
      return cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return AlertDialog(
              title: const Text('Nueva categoria'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (v) {
                          if (v == null || v.trim().length < 3) {
                            return 'Minimo 3 caracteres';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descripcion',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activa'),
                        value: isActive,
                        onChanged: (v) => setModalState(() => isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(modalContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      final slugBase = slugify(nameController.text);
                      if (slugBase.isEmpty) {
                        throw Exception('No se pudo generar un slug valido');
                      }

                      await ref
                          .read(adminRepositoryProvider)
                          .createCategory(
                            name: nameController.text,
                            description: descriptionController.text,
                            isActive: isActive,
                          );
                      if (!modalContext.mounted) return;
                      Navigator.of(modalContext).pop(true);
                    } on PostgrestException catch (e) {
                      if (!modalContext.mounted) return;
                      final msg = (e.code == '23505')
                          ? 'Ya existe una categoria con ese slug'
                          : 'No se pudo crear: ${e.message}';
                      ScaffoldMessenger.of(
                        modalContext,
                      ).showSnackBar(SnackBar(content: Text(msg)));
                    } catch (e) {
                      if (!modalContext.mounted) return;
                      ScaffoldMessenger.of(modalContext).showSnackBar(
                        SnackBar(content: Text('No se pudo crear: $e')),
                      );
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && mounted) {
      setState(() => _refreshTick++);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Categoria creada')));
    }
  }
}
