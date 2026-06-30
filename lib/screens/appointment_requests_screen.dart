// lib/screens/appointment_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../data/models/appointment_request_model.dart';
import '../providers/appointment_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/error_widget.dart';
import '../widgets/loading_widget.dart';
import '../l10n/app_localizations.dart';

class AppointmentRequestsScreen extends ConsumerStatefulWidget {
  const AppointmentRequestsScreen({super.key});

  @override
  ConsumerState<AppointmentRequestsScreen> createState() =>
      _AppointmentRequestsScreenState();
}

class _AppointmentRequestsScreenState
    extends ConsumerState<AppointmentRequestsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  // Reject dialog state
  int? _selectedRequestIdForReject;
  String? _rejectReason;

  // Update modal state
  int? _updateRequestId;
  String _newDate = '';
  String _newTime = '';
  String? _doctorAvailableFrom;
  String? _doctorAvailableTo;

  // Loading states for individual requests
  final Map<int, Map<String, bool>> _requestLoading = {};

  static final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchTerm = _searchController.text;
    });
  }

  List<AppointmentRequestModel> _filterRequests(
      List<AppointmentRequestModel> requests) {
    if (_searchTerm.isEmpty) return requests;

    final searchLower = _searchTerm.toLowerCase();
    return requests.where((request) {
      return request.name?.toLowerCase().contains(searchLower) == true ||
          request.email?.toLowerCase().contains(searchLower) == true ||
          request.phone?.contains(_searchTerm) == true ||
          request.service?.toLowerCase().contains(searchLower) == true ||
          request.serviceName?.toLowerCase().contains(searchLower) == true ||
          request.notes?.toLowerCase().contains(searchLower) == true;
    }).toList();
  }

  Future<void> _handleConfirmRequest(int requestId) async {
    setState(() {
      _requestLoading[requestId] = {
        ...?_requestLoading[requestId],
        'confirm': true,
      };
    });

    try {
      final result =
          await ref.read(confirmAppointmentRequestProvider(requestId).future);

      result.when(
        success: (appointment) {
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            AwesomeDialog(
              context: context,
              dialogType: DialogType.success,
              animType: AnimType.scale,
              title: '${localizations?.successTitle ?? 'Succès'} ! ✅',
              desc: localizations?.appointmentConfirmed ??
                  'Rendez-vous confirmé ! Le patient peut le voir dans son tableau de bord ou son calendrier.',
              btnOkText: 'OK',
              btnOkOnPress: () {
                // Refresh the list
                ref.invalidate(appointmentRequestsProvider);
              },
              btnOkColor: Colors.green,
            ).show();
          }
        },
        failure: (error) {
          if (mounted) {
            final errorMessage = error.toLowerCase();
            if (errorMessage.contains('heure sélectionnée') ||
                errorMessage.contains('hors des heures') ||
                errorMessage.contains('déjà un rendez-vous')) {
              // Show update modal
              final request = ref.read(appointmentRequestsProvider).value?.when(
                    success: (requests) => requests.firstWhere(
                        (r) => r.id == requestId,
                        orElse: () => requests.first),
                    failure: (_) => null,
                  );

              if (request != null) {
                setState(() {
                  _updateRequestId = requestId;
                  _newDate = request.date ?? '';
                  _newTime = request.time?.substring(0, 5) ?? '';
                });
                _showUpdateModal();
              }

              final localizations = AppLocalizations.of(context);
              AwesomeDialog(
                context: context,
                dialogType: DialogType.warning,
                animType: AnimType.scale,
                title: '${localizations?.warningTitle ?? 'Attention'} ⚠️',
                desc: localizations?.pleaseSelectNewDateTime ??
                    'Veuillez sélectionner une nouvelle date ou heure pour ce rendez-vous.',
                btnOkText: 'OK',
                btnOkColor: Colors.orange,
              ).show();
            } else if (errorMessage.contains('médecin non trouvé')) {
              final localizations = AppLocalizations.of(context);
              AwesomeDialog(
                context: context,
                dialogType: DialogType.error,
                animType: AnimType.scale,
                title: '${localizations?.errorTitle ?? 'Erreur'} ❌',
                desc: localizations?.confirmationFailed ??
                    'Échec de la confirmation : Médecin non trouvé.',
                btnOkText: 'OK',
                btnOkColor: Colors.red,
              ).show();
            } else if (errorMessage.contains('invalid_time_format')) {
              final request = ref.read(appointmentRequestsProvider).value?.when(
                    success: (requests) => requests.firstWhere(
                        (r) => r.id == requestId,
                        orElse: () => requests.first),
                    failure: (_) => null,
                  );

              if (request != null) {
                setState(() {
                  _updateRequestId = requestId;
                  _newDate = request.date ?? '';
                  _newTime = request.time?.substring(0, 5) ?? '';
                });
                _showUpdateModal();
              }

              final localizations = AppLocalizations.of(context);
              AwesomeDialog(
                context: context,
                dialogType: DialogType.error,
                animType: AnimType.scale,
                title: '${localizations?.errorTitle ?? 'Erreur'} ❌',
                desc: localizations?.confirmationFailedInvalidTime ??
                    'Échec de la confirmation : L\'heure de la demande est invalide. Veuillez corriger l\'heure.',
                btnOkText: 'OK',
                btnOkColor: Colors.red,
              ).show();
            } else {
              final localizations = AppLocalizations.of(context);
              AwesomeDialog(
                context: context,
                dialogType: DialogType.error,
                animType: AnimType.scale,
                title: '${localizations?.errorTitle ?? 'Erreur'} ❌',
                desc:
                    '${localizations?.confirmationFailedError ?? 'Échec de la confirmation'} : $error',
                btnOkText: 'OK',
                btnOkColor: Colors.red,
              ).show();
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: 'Erreur ❌',
          desc: 'Erreur : ${e.toString()}',
          btnOkText: 'OK',
          btnOkColor: Colors.red,
        ).show();
      }
    } finally {
      if (mounted) {
        setState(() {
          _requestLoading[requestId] = {
            ...?_requestLoading[requestId],
            'confirm': false,
          };
        });
      }
    }
  }

  Future<void> _handleUpdateAndConfirm() async {
    if (_updateRequestId == null) return;

    if (_newDate.isEmpty || _newTime.isEmpty) {
      final localizations = AppLocalizations.of(context);
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.scale,
        title: '${localizations?.warningTitle ?? 'Attention'} ⚠️',
        desc: localizations?.selectDateAndTime ??
            'Veuillez sélectionner une date et une heure.',
        btnOkText: 'OK',
        btnOkColor: Colors.orange,
      ).show();
      return;
    }

    // Validate time format (HH:mm)
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(_newTime)) {
      final localizations = AppLocalizations.of(context);
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.scale,
        title: '${localizations?.warningTitle ?? 'Attention'} ⚠️',
        desc: localizations?.enterValidTime ??
            'Veuillez entrer une heure valide au format HH:mm (ex. 19:59).',
        btnOkText: 'OK',
        btnOkColor: Colors.orange,
      ).show();
      return;
    }

    setState(() {
      _requestLoading[_updateRequestId!] = {
        ...?_requestLoading[_updateRequestId!],
        'confirm': true,
      };
    });

    try {
      final result =
          await ref.read(updateAppointmentRequestProvider(UpdateRequestParams(
        requestId: _updateRequestId!,
        date: _newDate,
        time: _newTime,
        confirm: true,
      )).future);

      result.when(
        success: (appointment) {
          if (mounted) {
            Navigator.pop(context);
            final localizations = AppLocalizations.of(context);
            AwesomeDialog(
              context: context,
              dialogType: DialogType.success,
              animType: AnimType.scale,
              title: '${localizations?.successTitle ?? 'Succès'} ! ✅',
              desc: localizations?.appointmentUpdatedConfirmed ??
                  'Rendez-vous mis à jour et confirmé avec succès !',
              btnOkText: 'OK',
              btnOkOnPress: () {
                setState(() {
                  _updateRequestId = null;
                  _newDate = '';
                  _newTime = '';
                });
                // Refresh the list
                ref.invalidate(appointmentRequestsProvider);
              },
              btnOkColor: Colors.green,
            ).show();
          }
        },
        failure: (error) {
          if (mounted) {
            final errorMessage = error.toLowerCase();
            if (errorMessage.contains('hors des heures')) {
              final localizations = AppLocalizations.of(context);
              AwesomeDialog(
                context: context,
                dialogType: DialogType.error,
                animType: AnimType.scale,
                title: '${localizations?.errorTitle ?? 'Erreur'} ❌',
                desc: localizations?.newTimeOutsideAvailability ??
                    'La nouvelle heure sélectionnée est toujours en dehors des heures de disponibilité. Veuillez choisir une autre heure.',
                btnOkText: 'OK',
                btnOkColor: Colors.red,
              ).show();
            } else if (errorMessage.contains('déjà un rendez-vous')) {
              final localizations = AppLocalizations.of(context);
              AwesomeDialog(
                context: context,
                dialogType: DialogType.error,
                animType: AnimType.scale,
                title: '${localizations?.errorTitle ?? 'Erreur'} ❌',
                desc: localizations?.timeConflict ??
                    'Conflit horaire avec la nouvelle heure sélectionnée. Veuillez choisir un autre créneau.',
                btnOkText: 'OK',
                btnOkColor: Colors.red,
              ).show();
            } else {
              final localizations = AppLocalizations.of(context);
              AwesomeDialog(
                context: context,
                dialogType: DialogType.error,
                animType: AnimType.scale,
                title: '${localizations?.errorTitle ?? 'Erreur'} ❌',
                desc:
                    '${localizations?.updateConfirmationFailed ?? 'Échec de la mise à jour et confirmation'} : $error',
                btnOkText: 'OK',
                btnOkColor: Colors.red,
              ).show();
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: 'Erreur ❌',
          desc: 'Erreur : ${e.toString()}',
          btnOkText: 'OK',
          btnOkColor: Colors.red,
        ).show();
      }
    } finally {
      if (mounted) {
        setState(() {
          _requestLoading[_updateRequestId!] = {
            ...?_requestLoading[_updateRequestId!],
            'confirm': false,
          };
        });
      }
    }
  }

  void _handleRejectRequest(int requestId) {
    setState(() {
      _selectedRequestIdForReject = requestId;
      _rejectReason = null;
    });
  }

  Future<void> _submitRejectRequest() async {
    if (_selectedRequestIdForReject == null || _rejectReason == null) {
      final localizations = AppLocalizations.of(context);
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.scale,
        title: '${localizations?.warningTitle ?? 'Attention'} ⚠️',
        desc: localizations?.pleaseSelectRejectionReason ??
            'Veuillez sélectionner une raison de rejet',
        btnOkText: 'OK',
        btnOkColor: Colors.orange,
      ).show();
      return;
    }

    setState(() {
      _requestLoading[_selectedRequestIdForReject!] = {
        ...?_requestLoading[_selectedRequestIdForReject!],
        'reject': true,
      };
    });

    try {
      final result =
          await ref.read(rejectAppointmentRequestProvider(RejectRequestParams(
        requestId: _selectedRequestIdForReject!,
        reason: _rejectReason!,
      )).future);

      result.when(
        success: (_) {
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            AwesomeDialog(
              context: context,
              dialogType: DialogType.success,
              animType: AnimType.scale,
              title: '${localizations?.successTitle ?? 'Succès'} ! ✅',
              desc: localizations?.requestRejectedSuccessfully ??
                  'Demande de rendez-vous rejetée avec succès',
              btnOkText: 'OK',
              btnOkOnPress: () {
                setState(() {
                  _selectedRequestIdForReject = null;
                  _rejectReason = null;
                });
                // Refresh the list
                ref.invalidate(appointmentRequestsProvider);
              },
              btnOkColor: Colors.green,
            ).show();
          }
        },
        failure: (error) {
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              animType: AnimType.scale,
              title: '${localizations?.errorTitle ?? 'Erreur'} ❌',
              desc:
                  '${localizations?.rejectionFailed ?? 'Échec du rejet de la demande'} : $error',
              btnOkText: 'OK',
              btnOkColor: Colors.red,
            ).show();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: 'Erreur ❌',
          desc: 'Erreur : ${e.toString()}',
          btnOkText: 'OK',
          btnOkColor: Colors.red,
        ).show();
      }
    } finally {
      if (mounted) {
        setState(() {
          _requestLoading[_selectedRequestIdForReject!] = {
            ...?_requestLoading[_selectedRequestIdForReject!],
            'reject': false,
          };
        });
      }
    }
  }

  Widget _buildRequestCard(AppointmentRequestModel request) {
    final isLoadingConfirm = _requestLoading[request.id]?['confirm'] == true;
    final isLoadingReject = _requestLoading[request.id]?['reject'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with ID and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: ${request.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Chip(
                      label: Text(localizations?.pending ?? 'En attente'),
                      backgroundColor: Colors.yellow[100],
                      labelStyle: TextStyle(
                        color: Colors.yellow[900],
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient info
                    _buildInfoRow(
                        localizations?.patient ?? 'Nom', request.name ?? 'N/A'),
                    _buildInfoRow(localizations?.email ?? 'Email',
                        request.email ?? 'N/A'),
                    _buildInfoRow(localizations?.phone ?? 'Téléphone',
                        request.phone ?? 'N/A'),

                    const Divider(),

                    // Doctor info
                    _buildInfoRow(localizations?.doctor ?? 'Médecin',
                        request.doctor?.user?.name ?? 'N/A'),

                    // Service info
                    _buildInfoRow('Code du service', request.service ?? 'N/A'),
                    _buildInfoRow(localizations?.services ?? 'Nom du service',
                        request.serviceName ?? 'N/A'),

                    const Divider(),

                    // Date and time
                    if (request.date != null)
                      _buildInfoRow(
                        localizations?.date ?? 'Date',
                        _dateFormatter.format(DateTime.parse(request.date!)),
                      ),
                    if (request.time != null)
                      _buildInfoRow(localizations?.time ?? 'Heure',
                          request.time!.substring(0, 5)),

                    // Notes
                    if (request.notes != null && request.notes!.isNotEmpty) ...[
                      const Divider(),
                      _buildInfoRow(
                          localizations?.notes ?? 'Notes', request.notes!),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Confirm button
                ElevatedButton.icon(
                  onPressed: isLoadingConfirm || isLoadingReject
                      ? null
                      : () => _handleConfirmRequest(request.id!),
                  icon: isLoadingConfirm
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(localizations?.confirm ?? 'Confirmer');
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),

                // Reject button
                ElevatedButton.icon(
                  onPressed: isLoadingConfirm || isLoadingReject
                      ? null
                      : () => _handleRejectRequest(request.id!),
                  icon: isLoadingReject
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close, size: 18),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(localizations?.cancel ?? 'Rejeter');
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectReasonSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations?.rejectRequest ??
                        'Rejeter la Demande de Rendez-vous',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _rejectReason,
                    decoration: InputDecoration(
                      labelText: localizations?.selectReason ??
                          'Sélectionner une raison',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'Médecin Indisponible',
                        child: Text(localizations?.doctorUnavailable ??
                            'Médecin Indisponible'),
                      ),
                      DropdownMenuItem(
                        value: 'Créneau Horaire Pris',
                        child: Text(localizations?.timeSlotTaken ??
                            'Créneau Horaire Pris'),
                      ),
                      DropdownMenuItem(
                        value: 'Informations Incomplètes',
                        child: Text(localizations?.incompleteInformation ??
                            'Informations Incomplètes'),
                      ),
                      DropdownMenuItem(
                        value: 'Service Non Disponible',
                        child: Text(localizations?.serviceUnavailable ??
                            'Service Non Disponible'),
                      ),
                      DropdownMenuItem(
                        value: 'Autre',
                        child: Text(localizations?.other ?? 'Autre'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _rejectReason = value;
                      });
                    },
                  ),
                  if (_rejectReason == 'Autre') ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        labelText: localizations?.enterCustomReason ??
                            'Entrez une raison personnalisée',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _rejectReason = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedRequestIdForReject = null;
                            _rejectReason = null;
                          });
                        },
                        child: Text(localizations?.cancel ?? 'Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed:
                            _rejectReason == null || _rejectReason!.isEmpty
                                ? null
                                : _submitRejectRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: _requestLoading[_selectedRequestIdForReject]
                                    ?['reject'] ==
                                true
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(localizations?.submitRejection ??
                                'Soumettre le Rejet'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentRequestsAsync = ref.watch(appointmentRequestsProvider);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations?.appointmentRequests ??
                'Demandes de Rendez-vous');
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)?.searchRequests ??
                    'Rechercher des demandes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // Content
          Expanded(
            child: appointmentRequestsAsync.when(
              data: (result) => result.when(
                success: (requests) {
                  final filteredRequests = _filterRequests(requests);
                  if (filteredRequests.isEmpty) {
                    final localizations = AppLocalizations.of(context);
                    return Center(
                      child: Text(
                        _searchTerm.isEmpty
                            ? (localizations?.noRequestsPending ??
                                'Aucune demande de rendez-vous en attente.')
                            : (localizations?.noRequestsMatch ??
                                'Aucune demande de rendez-vous ne correspond à vos critères de recherche.'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Reject reason selector (if a request is selected)
                      if (_selectedRequestIdForReject != null)
                        _buildRejectReasonSelector(),

                      // Requests list
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredRequests.length,
                          itemBuilder: (context, index) {
                            final request = filteredRequests[index];
                            return _buildRequestCard(request);
                          },
                        ),
                      ),
                    ],
                  );
                },
                failure: (error) => CustomErrorWidget(
                  message: error,
                  onRetry: () {
                    ref.invalidate(appointmentRequestsProvider);
                  },
                ),
              ),
              loading: () => const LoadingWidget(),
              error: (error, stack) => CustomErrorWidget(
                message: error.toString(),
                onRetry: () {
                  ref.invalidate(appointmentRequestsProvider);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildUpdateModal(),
    );
  }

  Widget _buildUpdateModal() {
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations?.updateAppointmentDateTime ??
                        'Mettre à jour la date et l\'heure du rendez-vous',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations?.updateAppointmentDateTimeDesc ??
                        'L\'heure ou la date sélectionnée n\'est pas disponible ou invalide. Veuillez choisir une nouvelle date et heure au format HH:mm (ex. 19:59).',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (_doctorAvailableFrom != null &&
                      _doctorAvailableTo != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${localizations?.doctorAvailableFrom ?? 'Le médecin est disponible de'} $_doctorAvailableFrom ${localizations?.to ?? 'à'} $_doctorAvailableTo.',
                      style: TextStyle(
                          color: Colors.blue[700], fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return TextField(
                decoration: InputDecoration(
                  labelText: localizations?.date ?? 'Date',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                readOnly: true,
                controller: TextEditingController(text: _newDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        _newDate.isNotEmpty ? DateTime.parse(_newDate) : now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) {
                    setState(() {
                      _newDate = picked.toIso8601String().split('T')[0];
                    });
                  }
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return TextField(
                decoration: InputDecoration(
                  labelText: localizations?.hourFormat ?? 'Heure (HH:mm)',
                  hintText:
                      localizations?.hourFormatHint ?? 'HH:mm (ex. 19:59)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: const Icon(Icons.access_time),
                ),
                controller: TextEditingController(text: _newTime),
                onChanged: (value) {
                  setState(() {
                    _newTime = value;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _updateRequestId = null;
                    _newDate = '';
                    _newTime = '';
                  });
                },
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _requestLoading[_updateRequestId]?['confirm'] == true
                    ? null
                    : _handleUpdateAndConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _requestLoading[_updateRequestId]?['confirm'] == true
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Mettre à jour et Confirmer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
