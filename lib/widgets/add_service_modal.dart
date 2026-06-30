// lib/widgets/add_service_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/service_model.dart';
import '../providers/api_providers.dart';
import 'ngap_code_selector.dart';
import 'package:google_fonts/google_fonts.dart';

class AddServiceModal {
  /// Show the add service modal and return the created service
  static Future<ServiceModel?> show(BuildContext context, WidgetRef ref) async {
    return await showDialog<ServiceModel>(
      context: context,
      builder: (dialogContext) => _AddServiceModalContent(ref: ref),
    );
  }
}

class _AddServiceModalContent extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _AddServiceModalContent({required this.ref});

  @override
  ConsumerState<_AddServiceModalContent> createState() =>
      _AddServiceModalContentState();
}

class _AddServiceModalContentState
    extends ConsumerState<_AddServiceModalContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedNgapCode;
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _createService() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final serviceService = widget.ref.read(serviceServiceProvider);
      final price = _priceController.text.trim().isEmpty
          ? null
          : double.tryParse(_priceController.text.trim());

      final result = await serviceService.createService(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: price,
        ngapCode: _selectedNgapCode,
      );

      result.when(
        success: (service) {
          Navigator.of(context).pop(service);
        },
        failure: (message) {
          setState(() {
            _isCreating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    } catch (e) {
      setState(() {
        _isCreating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark ? const Color(0xFF1F1F25) : Colors.white,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Add New Service',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Service Title *',
                    hintText: 'Enter service name',
                    prefixIcon: const Icon(Icons.medical_services_rounded),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Service title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Enter service description',
                    prefixIcon: const Icon(Icons.description_rounded),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // NGAP Code Selector
                NgapCodeSelector(
                  value: _selectedNgapCode,
                  onSelect: (code) {
                    setState(() {
                      _selectedNgapCode = code;
                    });
                  },
                  placeholder: 'Sélectionner un code NGAP (optionnel)',
                ),
                const SizedBox(height: 16),

                // Price Field
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: 'Price (Optional)',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    suffixText: 'MAD',
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value != null &&
                        value.trim().isNotEmpty &&
                        double.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isCreating
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isCreating ? null : _createService,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        child: _isCreating
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Create Service',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
