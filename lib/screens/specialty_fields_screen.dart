// lib/screens/specialty_fields_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/specialty_model.dart';
import '../providers/specialty_providers.dart';
import '../core/utils/result.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../providers/auth_providers.dart';

class SpecialtyFieldsScreen extends ConsumerStatefulWidget {
  final int specialtyId;
  final String specialtyName;

  const SpecialtyFieldsScreen({
    super.key,
    required this.specialtyId,
    required this.specialtyName,
  });

  @override
  ConsumerState<SpecialtyFieldsScreen> createState() =>
      _SpecialtyFieldsScreenState();
}

class _SpecialtyFieldsScreenState extends ConsumerState<SpecialtyFieldsScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.user?.isAdmin == 1;
    final fieldsAsync = ref.watch(specialtyFieldsProvider(widget.specialtyId));

    // Listen to field operations
    ref.listen<AsyncValue<Result<String>>>(
      specialtyFieldNotifierProvider,
      (previous, next) {
        next.whenData((result) {
          if (result is Success<String>) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.data),
                backgroundColor: Colors.green,
              ),
            );
            ref.refresh(specialtyFieldsProvider(widget.specialtyId));
            ref.read(specialtyFieldNotifierProvider.notifier).reset();
          } else if (result is Failure<String>) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.red,
              ),
            );
            ref.read(specialtyFieldNotifierProvider.notifier).reset();
          }
        });
        next.when(
          data: (_) {},
          loading: () {},
          error: (error, stack) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${error.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
            ref.read(specialtyFieldNotifierProvider.notifier).reset();
          },
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Specialty Fields'),
            Text(
              widget.specialtyName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _showCreateFieldDialog(context),
              tooltip: 'Create Field',
            ),
        ],
      ),
      body: fieldsAsync.when(
        data: (result) {
          if (result is Failure<List<SpecialtyFieldModel>>) {
            return Center(
              child: CustomErrorWidget(
                message: result.message,
                onRetry: () =>
                    ref.refresh(specialtyFieldsProvider(widget.specialtyId)),
              ),
            );
          }

          final fields = (result as Success<List<SpecialtyFieldModel>>).data;

          if (fields.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.list_alt_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No fields found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isAdmin)
                    ElevatedButton.icon(
                      onPressed: () => _showCreateFieldDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create First Field'),
                    ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .refresh(specialtyFieldsProvider(widget.specialtyId).future);
            },
            child: isAdmin
                ? ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: fields.length,
                    onReorder: (oldIndex, newIndex) {
                      // Handle reordering (update field_order)
                      if (newIndex > oldIndex) newIndex--;
                      final field = fields[oldIndex];
                      ref
                          .read(specialtyFieldNotifierProvider.notifier)
                          .updateField(
                            specialtyId: widget.specialtyId,
                            fieldId: field.id!,
                            fieldName: field.fieldName!,
                            fieldLabel: field.fieldLabel!,
                            fieldType: field.fieldType!,
                            options: field.options,
                            required: field.required,
                            fieldOrder: newIndex,
                          );
                      ref.refresh(specialtyFieldsProvider(widget.specialtyId));
                    },
                    itemBuilder: (context, index) {
                      final field = fields[index];
                      return _buildFieldCard(context, field, isAdmin, index);
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: fields.length,
                    itemBuilder: (context, index) {
                      final field = fields[index];
                      return _buildFieldCard(context, field, isAdmin, index);
                    },
                  ),
          );
        },
        loading: () => const Center(child: LoadingWidget()),
        error: (error, _) => Center(
          child: CustomErrorWidget(
            message: error.toString(),
            onRetry: () =>
                ref.refresh(specialtyFieldsProvider(widget.specialtyId)),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard(
    BuildContext context,
    SpecialtyFieldModel field,
    bool isAdmin,
    int index,
  ) {
    return Card(
      key: ValueKey(field.id),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              field.fieldLabel ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (field.required == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Required',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildFieldTypeChip(field.fieldType ?? 'text'),
                          const SizedBox(width: 8),
                          Text(
                            'Field: ${field.fieldName ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (field.options != null && field.options!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: field.options!.map((option) {
                              return Chip(
                                label: Text(option),
                                labelStyle: const TextStyle(fontSize: 11),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditFieldDialog(context, field);
                      } else if (value == 'delete') {
                        _showDeleteFieldDialog(context, field);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded,
                                size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldTypeChip(String fieldType) {
    Color color;
    IconData icon;

    switch (fieldType) {
      case 'text':
        color = Colors.blue;
        icon = Icons.text_fields_rounded;
        break;
      case 'textarea':
        color = Colors.green;
        icon = Icons.article_rounded;
        break;
      case 'number':
        color = Colors.orange;
        icon = Icons.numbers_rounded;
        break;
      case 'select':
        color = Colors.purple;
        icon = Icons.list_rounded;
        break;
      case 'checkbox':
        color = Colors.teal;
        icon = Icons.check_box_rounded;
        break;
      case 'date':
        color = Colors.red;
        icon = Icons.calendar_today_rounded;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            fieldType.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateFieldDialog(BuildContext context) {
    final nameController = TextEditingController();
    final labelController = TextEditingController();
    final optionsController = TextEditingController();
    String selectedType = 'text';
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Field Name *',
                    hintText: 'e.g., ecg_result',
                    border: OutlineInputBorder(),
                    helperText: 'Internal field name (no spaces)',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Field Label *',
                    hintText: 'e.g., ECG Result',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Field Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Text('Text')),
                    DropdownMenuItem(
                        value: 'textarea', child: Text('Textarea')),
                    DropdownMenuItem(value: 'number', child: Text('Number')),
                    DropdownMenuItem(value: 'select', child: Text('Select')),
                    DropdownMenuItem(
                        value: 'checkbox', child: Text('Checkbox')),
                    DropdownMenuItem(value: 'date', child: Text('Date')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
                if (selectedType == 'select') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: optionsController,
                    decoration: const InputDecoration(
                      labelText: 'Options *',
                      hintText: 'Option1, Option2, Option3',
                      border: OutlineInputBorder(),
                      helperText: 'Comma-separated values',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Required'),
                  value: isRequired,
                  onChanged: (value) {
                    setState(() {
                      isRequired = value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    labelController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Name and Label are required')),
                  );
                  return;
                }

                if (selectedType == 'select' &&
                    optionsController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Options are required for select type')),
                  );
                  return;
                }

                final options = selectedType == 'select'
                    ? optionsController.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList()
                    : null;

                Navigator.pop(context);

                // Call create field - the listener in build() will handle the result
                ref.read(specialtyFieldNotifierProvider.notifier).createField(
                      specialtyId: widget.specialtyId,
                      fieldName: nameController.text.trim(),
                      fieldLabel: labelController.text.trim(),
                      fieldType: selectedType,
                      options: options,
                      required: isRequired,
                    );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditFieldDialog(BuildContext context, SpecialtyFieldModel field) {
    final nameController = TextEditingController(text: field.fieldName);
    final labelController = TextEditingController(text: field.fieldLabel);
    final optionsController = TextEditingController(
      text: field.options?.join(', ') ?? '',
    );
    String selectedType = field.fieldType ?? 'text';
    bool isRequired = field.required ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Field Name *',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Field Label *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Field Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Text('Text')),
                    DropdownMenuItem(
                        value: 'textarea', child: Text('Textarea')),
                    DropdownMenuItem(value: 'number', child: Text('Number')),
                    DropdownMenuItem(value: 'select', child: Text('Select')),
                    DropdownMenuItem(
                        value: 'checkbox', child: Text('Checkbox')),
                    DropdownMenuItem(value: 'date', child: Text('Date')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
                if (selectedType == 'select') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: optionsController,
                    decoration: const InputDecoration(
                      labelText: 'Options *',
                      hintText: 'Option1, Option2, Option3',
                      border: OutlineInputBorder(),
                      helperText: 'Comma-separated values',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Required'),
                  value: isRequired,
                  onChanged: (value) {
                    setState(() {
                      isRequired = value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    labelController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Name and Label are required')),
                  );
                  return;
                }

                if (selectedType == 'select' &&
                    optionsController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Options are required for select type')),
                  );
                  return;
                }

                final options = selectedType == 'select'
                    ? optionsController.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList()
                    : null;

                ref.read(specialtyFieldNotifierProvider.notifier).updateField(
                      specialtyId: widget.specialtyId,
                      fieldId: field.id!,
                      fieldName: nameController.text.trim(),
                      fieldLabel: labelController.text.trim(),
                      fieldType: selectedType,
                      options: options,
                      required: isRequired,
                    );

                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteFieldDialog(BuildContext context, SpecialtyFieldModel field) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Field'),
        content: Text(
          'Are you sure you want to delete "${field.fieldLabel}"?\n\n'
          'If this field has data in medical records, it will remain but won\'t be displayed. '
          'You can use the cleanup function to remove orphaned data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(specialtyFieldNotifierProvider.notifier).deleteField(
                    specialtyId: widget.specialtyId,
                    fieldId: field.id!,
                  );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
