import '../data/models/patient_model.dart';
import '../data/models/appointment_model.dart';

class Invoice {
  final int id;
  final int patientId;
  final int? appointmentId;
  final double amount;
  final double paid;
  final String status;
  final String? dueDate;
  final String? paymentMethod;
  final String? notes;
  final String? pdfPath;
  final String createdAt;
  final String updatedAt;
  final PatientModel? patient;
  final AppointmentModel? appointment;
  final List<InvoiceItem> items;
  final List<Payment> payments;

  Invoice({
    required this.id,
    required this.patientId,
    this.appointmentId,
    required this.amount,
    required this.paid,
    required this.status,
    this.dueDate,
    this.paymentMethod,
    this.notes,
    this.pdfPath,
    required this.createdAt,
    required this.updatedAt,
    this.patient,
    this.appointment,
    this.items = const [],
    this.payments = const [],
  });

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'],
      patientId: json['patient_id'],
      appointmentId: json['appointment_id'],
      amount: _parseDouble(json['amount']),
      paid: _parseDouble(json['paid']),
      status: json['status'],
      dueDate: json['due_date'],
      paymentMethod: json['payment_method'],
      notes: json['notes'],
      pdfPath: json['pdf_path'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      patient: json['patient'] != null
          ? PatientModel.fromJson(json['patient'])
          : null,
      appointment: json['appointment'] != null
          ? AppointmentModel.fromJson(json['appointment'])
          : null,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => InvoiceItem.fromJson(item))
              .toList()
          : [],
      payments: json['payments'] != null
          ? (json['payments'] as List)
              .map((payment) => Payment.fromJson(payment))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'appointment_id': appointmentId,
      'amount': amount,
      'paid': paid,
      'status': status,
      'due_date': dueDate,
      'payment_method': paymentMethod,
      'notes': notes,
      'pdf_path': pdfPath,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'patient': patient?.toJson(),
      'appointment': appointment?.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'payments': payments.map((payment) => payment.toJson()).toList(),
    };
  }

  double get remainingAmount => amount - paid;

  bool get isFullyPaid => remainingAmount <= 0;

  bool get isOverdue {
    if (dueDate == null || isFullyPaid) return false;
    return DateTime.parse(dueDate!).isBefore(DateTime.now());
  }

  String get statusLabel {
    switch (status) {
      case 'paid':
        return 'Payée';
      case 'partial':
        return 'Partielle';
      case 'unpaid':
        return 'Non payée';
      default:
        return status;
    }
  }
}

class InvoiceItem {
  final int id;
  final int invoiceId;
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'],
      invoiceId: json['invoice_id'],
      description: json['description'],
      quantity: json['quantity'],
      unitPrice: Invoice._parseDouble(json['unit_price']),
      total: Invoice._parseDouble(json['total']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total,
    };
  }
}

class Payment {
  final int id;
  final int invoiceId;
  final double amount;
  final String paymentDate;
  final String paymentMethod;
  final String createdAt;

  Payment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      invoiceId: json['invoice_id'],
      amount: Invoice._parseDouble(json['amount']),
      paymentDate: json['payment_date'],
      paymentMethod: json['payment_method'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'amount': amount,
      'payment_date': paymentDate,
      'payment_method': paymentMethod,
      'created_at': createdAt,
    };
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'cash':
        return 'Espèces';
      case 'credit_card':
        return 'Carte de crédit';
      case 'bank_transfer':
        return 'Virement bancaire';
      case 'insurance':
        return 'Assurance';
      case 'mobile_payment':
        return 'Paiement mobile';
      default:
        return paymentMethod;
    }
  }
}

class InvoiceStatistics {
  final int totalInvoices;
  final int totalPatients;
  final double totalAmount;
  final double totalPayments;
  final double totalDue;
  final Map<String, int> statusCounts;

  InvoiceStatistics({
    required this.totalInvoices,
    required this.totalPatients,
    required this.totalAmount,
    required this.totalPayments,
    required this.totalDue,
    required this.statusCounts,
  });

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  factory InvoiceStatistics.fromJson(Map<String, dynamic> json) {
    return InvoiceStatistics(
      totalInvoices: json['total_invoices'] ?? 0,
      totalPatients: json['total_patients'] ?? 0,
      totalAmount: _parseDouble(json['total_amount']),
      totalPayments: _parseDouble(json['total_payments']),
      totalDue: _parseDouble(json['total_due']),
      statusCounts: Map<String, int>.from(json['status_counts'] ?? {}),
    );
  }

  double get paymentPercentage {
    return totalAmount > 0 ? (totalPayments / totalAmount) * 100 : 0;
  }
}
