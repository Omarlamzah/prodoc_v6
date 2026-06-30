// lib/providers/specialty_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/specialty_service.dart';
import '../data/models/specialty_model.dart';
import '../core/utils/result.dart';
import 'api_providers.dart';

// Service Provider
final specialtyServiceProvider = Provider<SpecialtyService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SpecialtyService(apiClient: apiClient);
});

// Specialties List Provider
final specialtiesProvider =
    FutureProvider.autoDispose<Result<List<SpecialtyModel>>>((ref) async {
  final service = ref.watch(specialtyServiceProvider);
  return await service.fetchSpecialties();
});

// Single Specialty Provider
final specialtyProvider = FutureProvider.autoDispose
    .family<Result<SpecialtyModel>, int>((ref, id) async {
  final service = ref.watch(specialtyServiceProvider);
  return await service.fetchSpecialty(id);
});

// Specialty Fields Provider
final specialtyFieldsProvider = FutureProvider.autoDispose
    .family<Result<List<SpecialtyFieldModel>>, int>((ref, specialtyId) async {
  final service = ref.watch(specialtyServiceProvider);
  return await service.fetchSpecialtyFields(specialtyId);
});

// State Notifier for managing specialty operations
class SpecialtyNotifier extends Notifier<AsyncValue<Result<String>>> {
  late SpecialtyService _service;

  @override
  AsyncValue<Result<String>> build() {
    _service = ref.watch(specialtyServiceProvider);
    return const AsyncValue.data(Success(''));
  }

  Future<void> createSpecialty({
    required String name,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.createSpecialty(
        name: name,
        description: description,
      );
      if (result is Success<SpecialtyModel>) {
        state = AsyncValue.data(Success('Specialty created successfully'));
      } else {
        state = AsyncValue.data(
            Failure((result as Failure<SpecialtyModel>).message));
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateSpecialty({
    required int id,
    required String name,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateSpecialty(
        id: id,
        name: name,
        description: description,
      );
      state = AsyncValue.data(Success('Specialty updated successfully'));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteSpecialty(int id) async {
    debugPrint('[SpecialtyNotifier] deleteSpecialty called with ID: $id');
    state = const AsyncValue.loading();
    try {
      debugPrint('[SpecialtyNotifier] Calling service.deleteSpecialty...');
      final result = await _service.deleteSpecialty(id);
      debugPrint('[SpecialtyNotifier] Service returned: $result');
      debugPrint('[SpecialtyNotifier] Result type: ${result.runtimeType}');

      if (result is Success<String>) {
        debugPrint('[SpecialtyNotifier] Success - Message: ${result.data}');
      } else if (result is Failure<String>) {
        debugPrint('[SpecialtyNotifier] Failure - Message: ${result.message}');
      }

      state = AsyncValue.data(result);
      debugPrint('[SpecialtyNotifier] State updated to: $state');
    } catch (e, stack) {
      debugPrint('[SpecialtyNotifier] Exception caught: $e');
      debugPrint('[SpecialtyNotifier] Stack trace: $stack');
      state = AsyncValue.error(e, stack);
    }
  }

  void reset() {
    state = const AsyncValue.data(Success(''));
  }
}

final specialtyNotifierProvider = NotifierProvider.autoDispose<
    SpecialtyNotifier, AsyncValue<Result<String>>>(SpecialtyNotifier.new);

// State Notifier for managing specialty field operations
class SpecialtyFieldNotifier extends Notifier<AsyncValue<Result<String>>> {
  late SpecialtyService _service;

  @override
  AsyncValue<Result<String>> build() {
    _service = ref.watch(specialtyServiceProvider);
    return const AsyncValue.data(Success(''));
  }

  Future<void> createField({
    required int specialtyId,
    required String fieldName,
    required String fieldLabel,
    required String fieldType,
    List<String>? options,
    bool required = false,
    int fieldOrder = 0,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.createSpecialtyField(
        specialtyId: specialtyId,
        fieldName: fieldName,
        fieldLabel: fieldLabel,
        fieldType: fieldType,
        options: options,
        required: required,
        fieldOrder: fieldOrder,
      );
      if (result is Success<SpecialtyFieldModel>) {
        state = AsyncValue.data(Success('Field created successfully'));
      } else {
        state = AsyncValue.data(
            Failure((result as Failure<SpecialtyFieldModel>).message));
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateField({
    required int specialtyId,
    required int fieldId,
    required String fieldName,
    required String fieldLabel,
    required String fieldType,
    List<String>? options,
    bool? required,
    int? fieldOrder,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateSpecialtyField(
        specialtyId: specialtyId,
        fieldId: fieldId,
        fieldName: fieldName,
        fieldLabel: fieldLabel,
        fieldType: fieldType,
        options: options,
        required: required,
        fieldOrder: fieldOrder,
      );
      state = AsyncValue.data(Success('Field updated successfully'));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteField({
    required int specialtyId,
    required int fieldId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.deleteSpecialtyField(
        specialtyId: specialtyId,
        fieldId: fieldId,
      );
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> cleanupFieldData({
    required int specialtyId,
    required String fieldName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.cleanupFieldData(
        specialtyId: specialtyId,
        fieldName: fieldName,
      );
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void reset() {
    state = const AsyncValue.data(Success(''));
  }
}

final specialtyFieldNotifierProvider = NotifierProvider.autoDispose<
    SpecialtyFieldNotifier, AsyncValue<Result<String>>>(SpecialtyFieldNotifier.new);
