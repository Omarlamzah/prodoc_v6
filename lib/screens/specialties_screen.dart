// lib/screens/specialties_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/specialty_model.dart';
import '../providers/specialty_providers.dart';
import '../core/utils/result.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/app_drawer.dart';
import '../providers/auth_providers.dart';
import 'specialty_fields_screen.dart';

class SpecialtiesScreen extends ConsumerStatefulWidget {
  const SpecialtiesScreen({super.key});

  @override
  ConsumerState<SpecialtiesScreen> createState() => _SpecialtiesScreenState();
}

class _SpecialtiesScreenState extends ConsumerState<SpecialtiesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.user?.isAdmin == 1;
    final specialtiesAsync = ref.watch(specialtiesProvider);

    // Listen to specialty operations
    ref.listen<AsyncValue<Result<String>>>(
      specialtyNotifierProvider,
      (previous, next) {
        debugPrint('[SpecialtiesScreen] Specialty operation state changed');
        debugPrint('[SpecialtiesScreen] Previous: $previous');
        debugPrint('[SpecialtiesScreen] Next: $next');

        next.whenData((result) {
          debugPrint('[SpecialtiesScreen] Result data: $result');
          if (result is Success<String>) {
            debugPrint('[SpecialtiesScreen] Success: ${result.data}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.data),
                backgroundColor: Colors.green,
              ),
            );
            ref.refresh(specialtiesProvider);
            ref.read(specialtyNotifierProvider.notifier).reset();
          } else if (result is Failure<String>) {
            debugPrint('[SpecialtiesScreen] Failure: ${result.message}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.red,
              ),
            );
            ref.read(specialtyNotifierProvider.notifier).reset();
          }
        });

        next.when(
          data: (_) {},
          loading: () {
            debugPrint('[SpecialtiesScreen] Operation loading...');
          },
          error: (error, stack) {
            debugPrint('[SpecialtiesScreen] Error: $error');
            debugPrint('[SpecialtiesScreen] Stack: $stack');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${error.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
            ref.read(specialtyNotifierProvider.notifier).reset();
          },
        );
      },
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.medical_services_rounded),
            SizedBox(width: 12),
            Text('Specialties'),
          ],
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _showCreateSpecialtyDialog(context),
              tooltip: 'Create Specialty',
            ),
        ],
      ),
      body: specialtiesAsync.when(
        data: (result) {
          if (result is Failure<List<SpecialtyModel>>) {
            return Center(
              child: CustomErrorWidget(
                message: result.message,
                onRetry: () => ref.refresh(specialtiesProvider),
              ),
            );
          }

          final specialties = (result as Success<List<SpecialtyModel>>).data;

          if (specialties.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No specialties found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isAdmin)
                    ElevatedButton.icon(
                      onPressed: () => _showCreateSpecialtyDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create First Specialty'),
                    ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.refresh(specialtiesProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: specialties.length,
              itemBuilder: (context, index) {
                final specialty = specialties[index];
                return _buildSpecialtyCard(context, specialty, isAdmin);
              },
            ),
          );
        },
        loading: () => const Center(child: LoadingWidget()),
        error: (error, _) => Center(
          child: CustomErrorWidget(
            message: error.toString(),
            onRetry: () => ref.refresh(specialtiesProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialtyCard(
    BuildContext context,
    SpecialtyModel specialty,
    bool isAdmin,
  ) {
    final fieldCount = specialty.fields?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpecialtyFieldsScreen(
                specialtyId: specialty.id!,
                specialtyName: specialty.name ?? 'Unknown',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.medical_services_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          specialty.name ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (specialty.description != null &&
                            specialty.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              specialty.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditSpecialtyDialog(context, specialty);
                        } else if (value == 'delete') {
                          _showDeleteSpecialtyDialog(context, specialty);
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
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.list_rounded,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$fieldCount field${fieldCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to manage fields',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSpecialtyDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Specialty'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'e.g., Cardiology',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Specialty description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }

              ref.read(specialtyNotifierProvider.notifier).createSpecialty(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  );

              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    // Listen to the result
    ref.listen<AsyncValue<Result<String>>>(
      specialtyNotifierProvider,
      (previous, next) {
        next.whenData((result) {
          if (result is Success<String>) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.data),
                backgroundColor: Colors.green,
              ),
            );
            ref.refresh(specialtiesProvider);
            ref.read(specialtyNotifierProvider.notifier).reset();
          } else if (result is Failure<String>) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.red,
              ),
            );
            ref.read(specialtyNotifierProvider.notifier).reset();
          }
        });
      },
    );
  }

  void _showEditSpecialtyDialog(
      BuildContext context, SpecialtyModel specialty) {
    final nameController = TextEditingController(text: specialty.name);
    final descriptionController =
        TextEditingController(text: specialty.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Specialty'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }

              ref.read(specialtyNotifierProvider.notifier).updateSpecialty(
                    id: specialty.id!,
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  );

              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    // Listen to the result
    ref.listen<AsyncValue<Result<String>>>(
      specialtyNotifierProvider,
      (previous, next) {
        next.whenData((result) {
          if (result is Success<String>) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.data),
                backgroundColor: Colors.green,
              ),
            );
            ref.refresh(specialtiesProvider);
            ref.read(specialtyNotifierProvider.notifier).reset();
          } else if (result is Failure<String>) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.red,
              ),
            );
            ref.read(specialtyNotifierProvider.notifier).reset();
          }
        });
      },
    );
  }

  void _showDeleteSpecialtyDialog(
      BuildContext context, SpecialtyModel specialty) {
    debugPrint(
        '[SpecialtiesScreen] Showing delete dialog for specialty: ${specialty.id} - ${specialty.name}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Specialty'),
        content: Text(
          'Are you sure you want to delete "${specialty.name}"?\n\n'
          'This action cannot be undone. If this specialty is used in medical records, deletion will be prevented.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('[SpecialtiesScreen] Delete cancelled');
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('[SpecialtiesScreen] Delete button pressed');
              debugPrint('[SpecialtiesScreen] Specialty ID: ${specialty.id}');
              debugPrint(
                  '[SpecialtiesScreen] Specialty Name: ${specialty.name}');

              if (specialty.id == null) {
                debugPrint('[SpecialtiesScreen] ERROR: Specialty ID is null!');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error: Specialty ID is missing'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.pop(context);
                return;
              }

              Navigator.pop(context);

              debugPrint(
                  '[SpecialtiesScreen] Calling deleteSpecialty with ID: ${specialty.id}');
              ref
                  .read(specialtyNotifierProvider.notifier)
                  .deleteSpecialty(specialty.id!);
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
