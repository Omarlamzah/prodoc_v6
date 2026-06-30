// lib/services/tenant_website_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/tenant_website_model.dart';

class TenantWebsiteService {
  final ApiClient apiClient;

  TenantWebsiteService({required this.apiClient});

  Future<Result<TenantWebsiteModel>> getTenantWebsiteConfig() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.tenantWebsiteConfig,
        requireAuth: true,
      );

      final website = TenantWebsiteModel.fromJson(responseData);
      return Success(website);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch tenant website config: $e');
    }
  }

  // Public method to get default tenant website (no auth required)
  Future<Result<TenantWebsiteModel>> getDefaultTenantWebsite() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.publicTenantWebsiteGetDefault,
        requireAuth: false,
      );

      final website = TenantWebsiteModel.fromJson(responseData);
      return Success(website);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch default tenant website: $e');
    }
  }

  // Update tenant website config (requires auth, admin or doctor only)
  // Uses POST /tenant-website/buildmysite as per Laravel API
  Future<Result<TenantWebsiteModel>> updateTenantWebsiteConfig(
      Map<String, dynamic> data) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.updateTenantWebsiteConfig,
        body: data,
        requireAuth: true,
      );

      final website = TenantWebsiteModel.fromJson(responseData);
      return Success(website);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to update tenant website config: $e');
    }
  }

  // Upload file for tenant website (logo, favicon, hero_image, seo_image)
  // Uses POST /uploadfile as per Laravel API
  Future<Result<Map<String, dynamic>>> uploadFile({
    required String fieldName, // 'logo', 'favicon', 'hero_image', or 'seo_image'
    File? file,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    try {
      if (file == null && fileBytes == null) {
        return const Failure('Either file or fileBytes must be provided');
      }
      if (kIsWeb && (fileBytes == null || fileName == null)) {
        return const Failure(
            'fileBytes and fileName are required on web platform');
      }
      if (!kIsWeb && file == null) {
        return const Failure('file is required on mobile/desktop platform');
      }

      dynamic responseData;
      if (kIsWeb) {
        // Use bytes for web
        responseData = await apiClient.postMultipart(
          ApiConstants.uploadTenantWebsiteFile,
          fields: {},
          fileBytes: {
            fieldName: {
              'bytes': fileBytes!,
              'filename': fileName!,
            },
          },
          requireAuth: true,
        );
      } else {
        // Use File for mobile/desktop
        Map<String, String>? fileNamesMap;
        if (fileName != null && fileName.isNotEmpty) {
          fileNamesMap = {fieldName: fileName};
        }
        responseData = await apiClient.postMultipart(
          ApiConstants.uploadTenantWebsiteFile,
          fields: {},
          files: {
            fieldName: file!,
          },
          fileNames: fileNamesMap,
          requireAuth: true,
        );
      }

      if (responseData is Map<String, dynamic>) {
        return Success(responseData);
      } else {
        return Failure('Invalid response format');
      }
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to upload file: $e');
    }
  }
}
