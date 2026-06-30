// lib/widgets/ngap_code_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ngap_model.dart';
import '../providers/api_providers.dart';
import '../core/utils/result.dart';
import 'package:google_fonts/google_fonts.dart';

class NgapCodeSelector extends ConsumerStatefulWidget {
  final String? value;
  final Function(String?) onSelect;
  final String? placeholder;
  final bool enabled;

  const NgapCodeSelector({
    super.key,
    this.value,
    required this.onSelect,
    this.placeholder = 'Sélectionner un code NGAP...',
    this.enabled = true,
  });

  @override
  ConsumerState<NgapCodeSelector> createState() => _NgapCodeSelectorState();
}

class _NgapCodeSelectorState extends ConsumerState<NgapCodeSelector> {
  final TextEditingController _searchController = TextEditingController();
  NgapModel? _selectedNgap;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadSelectedNgap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedNgap() async {
    if (widget.value == null) return;

    final ngapService = ref.read(ngapServiceProvider);
    final result = await ngapService.getNgapCode(widget.value!);
    result.when(
      success: (ngap) {
        if (mounted) {
          setState(() {
            _selectedNgap = ngap;
          });
        }
      },
      failure: (_) {},
    );
  }


  void _selectNgap(NgapModel ngap) {
    widget.onSelect(ngap.code);
    Navigator.of(context).pop();
  }

  void _showCreateDialog() {
    _showNgapFormDialog();
  }

  void _showEditDialog(NgapModel ngap) {
    _showNgapFormDialog(ngap: ngap);
  }

  void _showDeleteDialog(NgapModel ngap) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le code NGAP'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le code NGAP "${ngap.code}" ?\n\n'
          'Cette action est irréversible. Le code ne pourra pas être supprimé s\'il est utilisé dans des services ou des factures.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _deleteNgap(ngap);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNgap(NgapModel ngap) async {
    final ngapService = ref.read(ngapServiceProvider);
    final result = await ngapService.deleteNgapCode(ngap.code);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code NGAP supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the dialog by closing and reopening
        Navigator.of(context).pop();
        _showSelectorDialog();
        if (widget.value == ngap.code) {
          widget.onSelect(null);
        }
      },
      failure: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  void _showNgapFormDialog({NgapModel? ngap}) {
    final isEdit = ngap != null;
    final codeController = TextEditingController(text: ngap?.code ?? '');
    final labelFrController = TextEditingController(text: ngap?.labelFr ?? '');
    final labelArController = TextEditingController(text: ngap?.labelAr ?? '');
    final categoryController = TextEditingController(text: ngap?.category ?? '');
    final basePriceController = TextEditingController(
      text: ngap?.basePrice?.toString() ?? '',
    );
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Modifier le code NGAP' : 'Créer un nouveau code NGAP'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code NGAP *',
                      hintText: 'Ex: C, A1, B2...',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    enabled: !isEdit,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: labelFrController,
                    decoration: const InputDecoration(
                      labelText: 'Libellé (Français) *',
                      hintText: 'Ex: Consultation générale',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: labelArController,
                    decoration: const InputDecoration(
                      labelText: 'Libellé (Arabe)',
                      hintText: 'Ex: استشارة عامة',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      hintText: 'Ex: Consultation, Acte...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: basePriceController,
                    decoration: const InputDecoration(
                      labelText: 'Prix de base (MAD)',
                      hintText: 'Ex: 150.00',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (codeController.text.trim().isEmpty ||
                            labelFrController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Le code et le libellé sont requis'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                        });

                        final ngapService = ref.read(ngapServiceProvider);
                        final basePrice = basePriceController.text.trim().isEmpty
                            ? null
                            : double.tryParse(basePriceController.text.trim());

                        final result = isEdit
                            ? await ngapService.updateNgapCode(
                                code: ngap.code,
                                newCode: codeController.text.trim(),
                                labelFr: labelFrController.text.trim(),
                                labelAr: labelArController.text.trim().isEmpty
                                    ? null
                                    : labelArController.text.trim(),
                                category: categoryController.text.trim().isEmpty
                                    ? null
                                    : categoryController.text.trim(),
                                basePrice: basePrice,
                              )
                            : await ngapService.createNgapCode(
                                code: codeController.text.trim(),
                                labelFr: labelFrController.text.trim(),
                                labelAr: labelArController.text.trim().isEmpty
                                    ? null
                                    : labelArController.text.trim(),
                                category: categoryController.text.trim().isEmpty
                                    ? null
                                    : categoryController.text.trim(),
                                basePrice: basePrice,
                              );

                        result.when(
                          success: (newNgap) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEdit
                                    ? 'Code NGAP mis à jour avec succès'
                                    : 'Code NGAP créé avec succès'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // Refresh the dialog by closing and reopening
                            Navigator.of(dialogContext).pop();
                            _showSelectorDialog();
                            if (!isEdit) {
                              _selectNgap(newNgap);
                            } else if (widget.value == ngap.code &&
                                newNgap.code != ngap.code) {
                              widget.onSelect(newNgap.code);
                            }
                          },
                          failure: (message) {
                            setDialogState(() {
                              isSaving = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                        );
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEdit ? 'Mettre à jour' : 'Créer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSelectorDialog() {
    // Reset state when opening dialog
    _searchController.clear();
    _searchTerm = '';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final ngapService = ref.read(ngapServiceProvider);
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Create future based on search term
            final loadFuture = _searchTerm.trim().length >= 2
                ? ngapService.searchNgapCodes(query: _searchTerm.trim(), limit: 100)
                : ngapService.fetchNgapCodes(perPage: 100, isActive: true);
            
            return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxHeight: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sélectionner un code NGAP',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Search
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un code NGAP...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setDialogState(() {
                                    _searchTerm = '';
                                  });
                                  // FutureBuilder will rebuild automatically
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          _searchTerm = value;
                        });
                        // FutureBuilder will rebuild automatically with the new key
                      },
                    ),
                  ),
                  // Create Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Créer un nouveau code NGAP'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  // List
                  Expanded(
                    child: FutureBuilder<Result<List<NgapModel>>>(
                      key: ValueKey(_searchTerm), // Rebuild when search changes
                      future: loadFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Erreur: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red[600]),
                              ),
                            ),
                          );
                        }

                        final result = snapshot.data;
                        if (result == null) {
                          return const Center(
                            child: Text('Aucune donnée disponible'),
                          );
                        }

                        return result.when(
                          success: (codes) {
                            if (codes.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _searchTerm.trim().length >= 2
                                        ? 'Aucun code NGAP trouvé pour "${_searchTerm}"'
                                        : 'Aucun code NGAP disponible',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              );
                            }
                            return ListView.builder(
                                shrinkWrap: true,
                                itemCount: codes.length,
                                itemBuilder: (context, index) {
                                  final ngap = codes[index];
                                  final isSelected = widget.value == ngap.code;
                                  return InkWell(
                                    onTap: () => _selectNgap(ngap),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue.withOpacity(0.1)
                                            : null,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.withOpacity(0.2),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle,
                                              color: Colors.blue,
                                              size: 20,
                                            )
                                          else
                                            const SizedBox(width: 20),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              ngap.code,
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (ngap.category != null)
                                                  Text(
                                                    ngap.category!,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                Text(
                                                  ngap.labelFr,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                if (ngap.basePrice != null)
                                                  Text(
                                                    'Prix: ${ngap.basePrice!.toStringAsFixed(2)} MAD',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                size: 18, color: Colors.blue),
                                            onPressed: () {
                                              _showEditDialog(ngap);
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                size: 18, color: Colors.red),
                                            onPressed: () {
                                              _showDeleteDialog(ngap);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                          },
                          failure: (message) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Erreur: $message',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.red[600]),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: widget.enabled ? _showSelectorDialog : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: widget.value != null && _selectedNgap != null
                  ? Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _selectedNgap!.code,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedNgap!.getFirstWords(4),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      widget.placeholder ?? 'Sélectionner un code NGAP...',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
            ),
            if (widget.value != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.enabled
                    ? () {
                        widget.onSelect(null);
                        setState(() {
                          _selectedNgap = null;
                        });
                      }
                    : null,
                color: Colors.grey[600],
              ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}
