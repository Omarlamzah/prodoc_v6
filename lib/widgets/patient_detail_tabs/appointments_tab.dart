import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/patient_model.dart';
import '../../data/models/appointment_model.dart';

class AppointmentsTab extends StatelessWidget {
  final PatientModel patient;

  const AppointmentsTab({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appointments = _parseAppointments();

    final upcomingAppointments = appointments
        .where((apt) => apt.status == 'scheduled')
        .toList()
      ..sort((a, b) {
        final dateA = _parseDate(a.appointmentDate);
        final dateB = _parseDate(b.appointmentDate);
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

    final pastAppointments = appointments
        .where((apt) => ['completed', 'cancelled', 'no_show'].contains(apt.status))
        .toList()
      ..sort((a, b) {
        final dateA = _parseDate(a.appointmentDate);
        final dateB = _parseDate(b.appointmentDate);
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upcoming Appointments
          _buildSection(
            context,
            'Rendez-vous à venir',
            Icons.calendar_today_rounded,
            Colors.blue,
            upcomingAppointments,
            isDark,
          ),
          const SizedBox(height: 24),
          // Past Appointments
          _buildSection(
            context,
            'Rendez-vous passés',
            Icons.history_rounded,
            Colors.grey,
            pastAppointments,
            isDark,
          ),
        ],
      ),
    );
  }

  List<AppointmentModel> _parseAppointments() {
    if (patient.appointments == null) return [];
    return patient.appointments!
        .map((apt) {
          if (apt is Map<String, dynamic>) {
            return AppointmentModel.fromJson(apt);
          }
          return null;
        })
        .whereType<AppointmentModel>()
        .toList();
  }

  DateTime? _parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<AppointmentModel> appointments,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15151C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (appointments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 48,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun rendez-vous',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...appointments.map((apt) => _buildAppointmentCard(context, apt, isDark)),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    AppointmentModel appointment,
    bool isDark,
  ) {
    final appointmentDate = _parseDate(appointment.appointmentDate);
    final dateLabel = appointmentDate != null
        ? DateFormat('dd MMM yyyy', 'fr_FR').format(appointmentDate)
        : 'Date inconnue';
    final timeLabel = appointment.appointmentTime?.substring(0, 5) ?? '—';

    Color statusColor;
    String statusLabel;
    switch (appointment.status) {
      case 'scheduled':
        statusColor = Colors.blue;
        statusLabel = 'Planifié';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'Terminé';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusLabel = 'Annulé';
        break;
      case 'no_show':
        statusColor = Colors.orange;
        statusLabel = 'Non présenté';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = appointment.status ?? 'Inconnu';
    }

    Color priorityColor;
    switch (appointment.priority) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'low':
        priorityColor = Colors.green;
        break;
      default:
        priorityColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F25) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rendez-vous #${appointment.id ?? '—'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (appointment.doctor != null)
            _buildInfoRow(
              context,
              Icons.local_hospital_rounded,
              'Médecin',
              appointment.doctor!.user?.name ?? 'Non assigné',
              isDark,
            ),
          if (appointment.service != null)
            _buildInfoRow(
              context,
              Icons.medical_services_rounded,
              'Service',
              appointment.service!.title ?? '—',
              isDark,
            ),
          if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note_rounded,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

