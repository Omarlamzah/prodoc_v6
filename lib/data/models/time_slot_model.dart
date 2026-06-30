// lib/data/models/time_slot_model.dart
class TimeSlotModel {
  final String time;
  final bool available;

  TimeSlotModel({
    required this.time,
    required this.available,
  });

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    return TimeSlotModel(
      time: json['time'] as String,
      available: json['available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'available': available,
    };
  }
}

