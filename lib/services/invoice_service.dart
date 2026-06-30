import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/invoice.dart';
import '../data/models/patient_model.dart';
import '../data/models/appointment_model.dart';
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';

class InvoiceService {
  final ApiClient apiClient;

  InvoiceService({required this.apiClient});

  // Get all invoices with filters and pagination
  // Handles API response as Map (data/pagination/statistics) or bare List
  Future<Result<Map<String, dynamic>>> getInvoices({
    int page = 1,
    String? search,
    String? status,
    String? timeRange,
    int? userId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }
      if (timeRange != null) {
        queryParams['timeRange'] = timeRange;
      }
      if (userId != null) {
        queryParams['user_id'] = userId.toString();
      }

      final responseData = await apiClient.get(
        ApiConstants.invoices,
        queryParameters: queryParams,
        requireAuth: true,
      );

      // API returns { data: [...], pagination: {...}, statistics: {...} }
      // Handle both envelope format and bare list (defensive)
      List<dynamic> rawList;
      dynamic paginationRaw;
      dynamic statisticsRaw;

      if (responseData is Map) {
        final data = responseData['data'];
        rawList = data is List ? data : [];
        paginationRaw = responseData['pagination'];
        statisticsRaw = responseData['statistics'];
      } else if (responseData is List) {
        rawList = responseData;
        paginationRaw = null;
        statisticsRaw = null;
      } else {
        rawList = [];
        paginationRaw = null;
        statisticsRaw = null;
      }

      // Only pass Map elements to Invoice.fromJson to avoid List vs Map type error
      final invoices = <Invoice>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          try {
            invoices.add(Invoice.fromJson(item));
          } catch (_) {
            // Skip malformed invoice item
          }
        } else if (item is Map) {
          try {
            invoices.add(Invoice.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {
            // Skip malformed invoice item
          }
        }
      }

      InvoiceStatistics? statistics;
      if (statisticsRaw is Map<String, dynamic>) {
        try {
          statistics = InvoiceStatistics.fromJson(statisticsRaw);
        } catch (_) {}
      } else if (statisticsRaw is Map) {
        try {
          statistics = InvoiceStatistics.fromJson(
              Map<String, dynamic>.from(statisticsRaw));
        } catch (_) {}
      }

      return Success({
        'invoices': invoices,
        'pagination': paginationRaw,
        'statistics': statistics,
      });
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Error fetching invoices: $e');
    }
  }

  // Get single invoice by ID
  Future<Result<Invoice>> getInvoice(int id) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.invoice(id),
        requireAuth: true,
      );

      return Success(Invoice.fromJson(responseData['invoice']));
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Error fetching invoice: $e');
    }
  }

  // Create new invoice
  Future<Result<Invoice>> createInvoice({
    required int patientId,
    int? appointmentId,
    required List<Map<String, dynamic>> items,
    String? dueDate,
    double? initialPayment,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'patient_id': patientId,
        'items': items,
        'payment_method': paymentMethod,
      };

      if (appointmentId != null) {
        body['appointment_id'] = appointmentId;
      }
      if (dueDate != null) {
        body['due_date'] = dueDate;
      }
      if (initialPayment != null && initialPayment > 0) {
        body['initial_payment'] = initialPayment;
      }
      if (notes != null && notes.isNotEmpty) {
        body['notes'] = notes;
      }

      final responseData = await apiClient.post(
        ApiConstants.invoices,
        body: body,
        requireAuth: true,
      );

      return Success(Invoice.fromJson(responseData['invoice']));
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Error creating invoice: $e');
    }
  }

  // Record payment for invoice
  Future<Result<Payment>> recordPayment({
    required int invoiceId,
    required double amount,
    required String paymentDate,
    required String paymentMethod,
  }) async {
    try {
      final body = {
        'amount': amount,
        'payment_date': paymentDate,
        'payment_method': paymentMethod,
      };

      final responseData = await apiClient.post(
        ApiConstants.invoicePayments(invoiceId),
        body: body,
        requireAuth: true,
      );

      return Success(Payment.fromJson(responseData['payment']));
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Error recording payment: $e');
    }
  }

  // Get payments for invoice
  Future<Result<List<Payment>>> getInvoicePayments(int invoiceId) async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.invoicePayments(invoiceId),
        requireAuth: true,
      );

      return Success((responseData['payments'] as List)
          .map((payment) => Payment.fromJson(payment))
          .toList());
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Error fetching payments: $e');
    }
  }

  /// Download invoice PDF via API (authenticated), save to temp file, return path for sharing.
  Future<Result<String>> downloadInvoicePdf(int invoiceId) async {
    try {
      final bytes = await apiClient.getBytes(
        ApiConstants.invoicePdf(invoiceId),
        requireAuth: true,
        headers: {'Accept': 'application/pdf'},
      );
      if (bytes.isEmpty) {
        return const Failure('PDF is empty');
      }
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/invoice_$invoiceId.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return Success(filePath);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Error downloading PDF: $e');
    }
  }

  // Send due reminder
  Future<Result<String>> sendDueReminder(int invoiceId) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.invoiceReminder(invoiceId),
        requireAuth: true,
      );

      return Success(responseData['message'] ?? 'Reminder sent successfully');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Error sending reminder: $e');
    }
  }

  // Search appointments for patient
  Future<Result<List<AppointmentModel>>> searchAppointments({
    required int patientId,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'patient_id': patientId.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final responseData = await apiClient.get(
        ApiConstants.invoiceSearch,
        queryParameters: queryParams,
        requireAuth: true,
      );

      return Success((responseData['data'] as List)
          .map((appointment) => AppointmentModel.fromJson(appointment))
          .toList());
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Error searching appointments: $e');
    }
  }

  // Update invoice
  Future<Result<Invoice>> updateInvoice({
    required int invoiceId,
    String? dueDate,
    String? status,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final body = <String, dynamic>{};

      if (dueDate != null) {
        body['due_date'] = dueDate;
      }
      if (status != null) {
        body['status'] = status;
      }
      if (items != null) {
        body['items'] = items;
      }

      final responseData = await apiClient.put(
        ApiConstants.invoice(invoiceId),
        body: body,
        requireAuth: true,
      );

      return Success(Invoice.fromJson(responseData['invoice']));
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Error updating invoice: $e');
    }
  }

  // Delete invoice
  Future<Result<String>> deleteInvoice(int invoiceId) async {
    try {
      await apiClient.delete(
        ApiConstants.invoice(invoiceId),
        requireAuth: true,
      );

      return const Success('Invoice deleted successfully');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Error deleting invoice: $e');
    }
  }
}
