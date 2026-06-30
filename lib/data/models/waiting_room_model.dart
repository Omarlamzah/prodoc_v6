// lib/data/models/waiting_room_model.dart
class WaitingRoomAppointment {
  final int? appointmentId;
  final int orderNumber;
  final String patientName;
  final String doctorName;
  final String service;
  final String appointmentTime;
  final String priority;
  final String? status;
  final int? waitingTimeMinutes;

  WaitingRoomAppointment({
    this.appointmentId,
    required this.orderNumber,
    required this.patientName,
    required this.doctorName,
    required this.service,
    required this.appointmentTime,
    required this.priority,
    this.status,
    this.waitingTimeMinutes,
  });

  factory WaitingRoomAppointment.fromJson(Map<String, dynamic> json) {
    return WaitingRoomAppointment(
      appointmentId: json['appointment_id'] as int? ?? json['id'] as int?,
      orderNumber: json['order_number'] as int? ?? 0,
      patientName: json['patient_name'] as String? ?? '',
      doctorName: json['doctor_name'] as String? ?? '',
      service: json['service'] as String? ?? '',
      appointmentTime: json['appointment_time'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String?,
      waitingTimeMinutes: json['waiting_time_minutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appointment_id': appointmentId,
      'order_number': orderNumber,
      'patient_name': patientName,
      'doctor_name': doctorName,
      'service': service,
      'appointment_time': appointmentTime,
      'priority': priority,
      'status': status,
      'waiting_time_minutes': waitingTimeMinutes,
    };
  }
}

class NextAppointment {
  final int? appointmentId;
  final String patientName;
  final String doctorName;
  final String service;
  final String time;

  NextAppointment({
    this.appointmentId,
    required this.patientName,
    required this.doctorName,
    required this.service,
    required this.time,
  });

  factory NextAppointment.fromJson(Map<String, dynamic> json) {
    return NextAppointment(
      appointmentId: json['appointment_id'] as int? ?? json['id'] as int?,
      patientName: json['patientName'] as String? ??
          json['patient_name'] as String? ??
          '',
      doctorName:
          json['doctorName'] as String? ?? json['doctor_name'] as String? ?? '',
      service: json['service'] as String? ?? '',
      time:
          json['time'] as String? ?? json['appointment_time'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appointment_id': appointmentId,
      'patientName': patientName,
      'doctorName': doctorName,
      'service': service,
      'time': time,
    };
  }
}

class WaitingRoomStats {
  final TodayStats today;
  final NextAppointment? nextAppointment;

  WaitingRoomStats({
    required this.today,
    this.nextAppointment,
  });

  factory WaitingRoomStats.fromJson(Map<String, dynamic> json) {
    return WaitingRoomStats(
      today: TodayStats.fromJson(json['today'] as Map<String, dynamic>? ?? {}),
      nextAppointment: json['nextAppointment'] != null
          ? NextAppointment.fromJson(
              json['nextAppointment'] as Map<String, dynamic>)
          : json['next_appointment'] != null
              ? NextAppointment.fromJson(
                  json['next_appointment'] as Map<String, dynamic>)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'today': today.toJson(),
      'nextAppointment': nextAppointment?.toJson(),
    };
  }
}

class TodayStats {
  final int total;
  final int completed;
  final int waiting;

  TodayStats({
    required this.total,
    required this.completed,
    required this.waiting,
  });

  factory TodayStats.fromJson(Map<String, dynamic> json) {
    return TodayStats(
      total: json['total'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      waiting: json['waiting'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'completed': completed,
      'waiting': waiting,
    };
  }
}

class WaitingRoomData {
  final List<WaitingRoomAppointment> waitingAppointments;
  final List<WaitingRoomAppointment> completedAppointments;
  final List<WaitingRoomAppointment> cancelledAppointments;
  final List<WaitingRoomAppointment> noShowAppointments;
  final WaitingRoomStats stats;

  WaitingRoomData({
    required this.waitingAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.noShowAppointments,
    required this.stats,
  });

  factory WaitingRoomData.fromJson(Map<String, dynamic> json) {
    // Parse all appointment lists
    final waitingAppointments =
        (json['waitingAppointments'] as List<dynamic>? ??
                json['waiting_appointments'] as List<dynamic>? ??
                [])
            .map((item) =>
                WaitingRoomAppointment.fromJson(item as Map<String, dynamic>))
            .toList();

    final completedAppointments =
        (json['completedAppointments'] as List<dynamic>? ??
                json['completed_appointments'] as List<dynamic>? ??
                [])
            .map((item) =>
                WaitingRoomAppointment.fromJson(item as Map<String, dynamic>))
            .toList();

    final cancelledAppointments =
        (json['cancelledAppointments'] as List<dynamic>? ??
                json['cancelled_appointments'] as List<dynamic>? ??
                [])
            .map((item) =>
                WaitingRoomAppointment.fromJson(item as Map<String, dynamic>))
            .toList();

    // Try to get no_show appointments from dedicated list
    var noShowAppointments = (json['noShowAppointments'] as List<dynamic>? ??
            json['no_show_appointments'] as List<dynamic>? ??
            [])
        .map((item) =>
            WaitingRoomAppointment.fromJson(item as Map<String, dynamic>))
        .toList();

    // Fallback: If no_show list is empty, try to filter from all appointments
    // Check if there's a general appointments list
    if (noShowAppointments.isEmpty) {
      final allAppointments = json['appointments'] as List<dynamic>? ??
          json['all_appointments'] as List<dynamic>?;

      if (allAppointments != null) {
        noShowAppointments = allAppointments
            .map((item) =>
                WaitingRoomAppointment.fromJson(item as Map<String, dynamic>))
            .where((apt) {
          final status = apt.status?.toLowerCase();
          return status == 'no_show' || status == 'no-show';
        }).toList();
      } else {
        // Last fallback: Check all other lists for no_show appointments
        final allLists = [
          ...waitingAppointments,
          ...completedAppointments,
          ...cancelledAppointments,
        ];
        noShowAppointments = allLists.where((apt) {
          final status = apt.status?.toLowerCase();
          return status == 'no_show' || status == 'no-show';
        }).toList();
      }
    }

    // Filter out no_show appointments from waiting list if they're mixed in
    final filteredWaitingAppointments = waitingAppointments.where((apt) {
      final status = apt.status?.toLowerCase();
      return status != 'no_show' && status != 'no-show';
    }).toList();

    return WaitingRoomData(
      waitingAppointments: filteredWaitingAppointments,
      completedAppointments: completedAppointments,
      cancelledAppointments: cancelledAppointments,
      noShowAppointments: noShowAppointments,
      stats: WaitingRoomStats.fromJson(
          json['stats'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'waitingAppointments':
          waitingAppointments.map((e) => e.toJson()).toList(),
      'completedAppointments':
          completedAppointments.map((e) => e.toJson()).toList(),
      'cancelledAppointments':
          cancelledAppointments.map((e) => e.toJson()).toList(),
      'noShowAppointments': noShowAppointments.map((e) => e.toJson()).toList(),
      'stats': stats.toJson(),
    };
  }
}
