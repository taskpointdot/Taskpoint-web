import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/admin_models.dart';
import '../../models/category_icons.dart';
import '../../services/categories_admin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_widgets.dart';

/// Manage the service taxonomy shown on the seeker home grid.
///
/// The mobile app seeds this collection once on first launch and then only
/// reads it, so this is the intended way to add, rename, reorder or remove a
/// service afterwards.
class CategoriesSection extends StatefulWidget {
  const CategoriesSection({super.key});

  @override
  State<CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<CategoriesSection> {
  final _service = CategoriesAdminService();

  Future<void> _edit({AdminCategory? existing, required int nextOrder}) async {
    final result = await showDialog<_CategoryDraft>(
      context: context,
      builder: (_) => _CategoryDialog(existing: existing, nextOrder: nextOrder),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await _service.create(
          name: result.name,
          localName: result.localName,
          iconKey: result.iconKey,
          order: result.order,
        );
      } else {
        await _service.update(
          existing.id,
          name: result.name,
          localName: result.localName,
          iconKey: result.iconKey,
          order: result.order,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Category added' : 'Category updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _delete(AdminCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text(
          'Seekers will no longer see this service on the home grid. Jobs already '
          'posted under it keep their category name and are unaffected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(category.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminCategory>>(
      stream: _service.watchAll(),
      builder: (context, snap) {
        final categories = snap.data ?? const <AdminCategory>[];
        final nextOrder = categories.isEmpty ? 0 : categories.map((c) => c.order).reduce((a, b) => a > b ? a : b) + 1;
        return AdminSectionScaffold(
          title: 'Categories',
          subtitle: 'The services seekers can request. Order controls the home grid layout.',
          toolbar: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _edit(nextOrder: nextOrder),
              icon: const Icon(Symbols.add_rounded, size: 18),
              label: const Text('Add category'),
            ),
          ),
          child: Builder(
            builder: (context) {
              if (snap.hasError) return AdminErrorState(error: snap.error!);
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (categories.isEmpty) {
                return const AdminEmptyState(
                  icon: Symbols.category_rounded,
                  message: 'No categories yet. The mobile app seeds these on first launch.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final c = categories[i];
                  return AdminCard(
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle),
                          child: Icon(categoryIconFor(c.iconKey), color: AppColors.onSecondaryContainer),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: AppTextStyles.labelLg),
                              Text(c.localName, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text('Icon: ${c.iconKey}',
                              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text('Order ${c.order}',
                              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                        ),
                        IconButton(
                          icon: const Icon(Symbols.edit_rounded, size: 20),
                          tooltip: 'Edit',
                          onPressed: () => _edit(existing: c, nextOrder: nextOrder),
                        ),
                        IconButton(
                          icon: const Icon(Symbols.delete_rounded, size: 20, color: AppColors.error),
                          tooltip: 'Delete',
                          onPressed: () => _delete(c),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _CategoryDraft {
  final String name;
  final String localName;
  final String iconKey;
  final int order;
  const _CategoryDraft({required this.name, required this.localName, required this.iconKey, required this.order});
}

class _CategoryDialog extends StatefulWidget {
  final AdminCategory? existing;
  final int nextOrder;
  const _CategoryDialog({required this.existing, required this.nextOrder});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _localNameController = TextEditingController(text: widget.existing?.localName ?? '');
  late final _orderController =
      TextEditingController(text: '${widget.existing?.order ?? widget.nextOrder}');
  late String _iconKey = widget.existing?.iconKey ?? CategoriesAdminService.supportedIconKeys.last;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _localNameController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add category' : 'Edit category'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name (English)', hintText: 'Plumber'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _localNameController,
                decoration: const InputDecoration(labelText: 'Local name (Roman Urdu)', hintText: 'Mistri'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _iconKey,
                decoration: const InputDecoration(labelText: 'Icon'),
                items: [
                  for (final key in CategoriesAdminService.supportedIconKeys)
                    DropdownMenuItem(
                      value: key,
                      child: Row(
                        children: [
                          Icon(categoryIconFor(key), size: 20, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(key),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _iconKey = v ?? _iconKey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Order',
                  helperText: 'Lower numbers appear first on the seeker home grid.',
                ),
                validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Enter a whole number' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(_CategoryDraft(
              name: _nameController.text.trim(),
              localName: _localNameController.text.trim(),
              iconKey: _iconKey,
              order: int.parse(_orderController.text.trim()),
            ));
          },
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
