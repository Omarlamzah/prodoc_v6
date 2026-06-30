// lib/core/network/api_client.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../config/api_constants.dart';
import '../exceptions/api_exception.dart';

/// Set to true to log all API requests/responses in the terminal (only in debug builds).
const bool _kLogApi = true;

/// Max length of body to log (avoids huge payloads in console).
const int _kLogMaxBodyLength = 800;

void _apiLog(String tag, String message, [String? detail]) {
  if (kDebugMode && _kLogApi) {
    final buffer = StringBuffer('[$tag] $message');
    if (detail != null && detail.isNotEmpty) {
      final truncated = detail.length > _kLogMaxBodyLength
          ? '${detail.substring(0, _kLogMaxBodyLength)}...'
          : detail;
      buffer.write('\n  $truncated');
    }
    debugPrint(buffer.toString());
  }
}

class ApiClient {
  final String? baseUrl;
  final http.Client? client;
  String? _authToken;
  
  // Timeout duration for HTTP requests
  static const Duration _timeoutDuration = Duration(seconds: 30);

  ApiClient({
    this.baseUrl,
    this.client,
  });

  // Helper to get the actual base URL
  String get _baseUrl => baseUrl ?? ApiConstants.baseUrl;

  // Set auth token
  void setAuthToken(String? token) {
    _authToken = token;
  }

  // Get headers with optional auth
  Map<String, String> _getHeaders({
    Map<String, String>? headers,
    bool requireAuth = true,
  }) {
    final defaultHeaders = requireAuth && _authToken != null
        ? ApiConstants.headersWithAuth(_authToken!)
        : ApiConstants.headers;

    return headers != null ? {...defaultHeaders, ...headers} : defaultHeaders;
  }

  // Build URI with query parameters
  Uri _buildUri(String endpoint, {Map<String, dynamic>? queryParameters}) {
    final url = '$_baseUrl$endpoint';
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return Uri.parse(url).replace(
          queryParameters: queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      ));
    }
    return Uri.parse(url);
  }

  // Handle response - can return Map or List
  dynamic _handleResponse(http.Response response, {String? requestMethod}) {
    final status = response.statusCode;
    final isSuccess = status >= 200 && status < 300;

    if (isSuccess) {
      _apiLog('API', 'Response $status${requestMethod != null ? ' $requestMethod' : ''}', response.body.isEmpty ? '(empty)' : response.body);
      if (response.body.isEmpty) {
        return {'success': true};
      }
      try {
        return jsonDecode(response.body);
      } catch (e) {
        _apiLog('API', 'Parse error: $e', response.body);
        throw ApiException(
          message: 'Failed to parse response',
          statusCode: response.statusCode,
        );
      }
    } else {
      String errorMessage = 'Request failed';
      dynamic errorData;
      try {
        errorData = jsonDecode(response.body);
        errorMessage =
            errorData['message'] ?? errorData['error'] ?? errorMessage;
        // Use first validation error if present (consistent with Next.js / API format)
        final errors = errorData is Map ? errorData['errors'] : null;
        if (errors is Map && errors.isNotEmpty) {
          final firstValues = errors.values.whereType<List>().expand((e) => e);
          if (firstValues.isNotEmpty) {
            final first = firstValues.first;
            if (first is String) errorMessage = first;
          }
        }
      } catch (_) {
        errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
      }
      // User-friendly defaults for common status codes
      if (errorMessage == 'Request failed' || errorMessage.isEmpty) {
        if (status == 403) errorMessage = 'Vous n\'avez pas les droits pour cette action.';
        else if (status == 422) errorMessage = 'Données invalides. Vérifiez les champs.';
        else if (status >= 500) errorMessage = 'Erreur serveur. Réessayez plus tard.';
      }
      _apiLog('API', 'Error $status: $errorMessage', response.body);
      throw ApiException(
        message: errorMessage,
        statusCode: response.statusCode,
        data: errorData,
      );
    }
  }

  /// GET request that returns raw bytes (e.g. for file download). Throws ApiException on non-2xx.
  Future<Uint8List> getBytes(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParameters: queryParameters);
      _apiLog('API', 'GET (bytes) $endpoint', queryParameters?.toString());
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(
        uri,
        headers: _getHeaders(headers: headers, requireAuth: requireAuth),
      ).timeout(
        _timeoutDuration,
        onTimeout: () {
          throw ApiException(
            message: 'Request timeout: The server took too long to respond',
            statusCode: 408,
          );
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      // Parse error body for message
      String errorMessage = 'Download failed';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
      } catch (_) {}
      throw ApiException(
        message: errorMessage,
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      _apiLog('API', 'Exception GET (bytes) $endpoint: $e');
      throw ApiException(message: 'Network error: $e');
    }
  }

  /// Fetch raw bytes from an absolute URL with auth headers.
  /// Used by AuthenticatedImage to load protected patient photos.
  Future<Uint8List?> getRaw(String absoluteUrl) async {
    try {
      final uri = Uri.parse(absoluteUrl);
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(
        uri,
        headers: _getHeaders(requireAuth: true),
      ).timeout(_timeoutDuration);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParameters: queryParameters);
      _apiLog('API', 'GET $endpoint', queryParameters?.toString());
      final httpClient = client ?? http.Client();

      final response = await httpClient.get(
        uri,
        headers: _getHeaders(headers: headers, requireAuth: requireAuth),
      ).timeout(
        _timeoutDuration,
        onTimeout: () {
          throw ApiException(
            message: 'Request timeout: The server took too long to respond',
            statusCode: 408,
          );
        },
      );

      return _handleResponse(response, requestMethod: 'GET $endpoint');
    } on ApiException catch (e) {
      _apiLog('API', 'Exception GET $endpoint: $e');
      rethrow;
    } on SocketException catch (e) {
      _apiLog('API', 'SocketException GET $endpoint: $e');
      throw ApiException(
        message: 'Network error: Unable to connect to the server. Please check your internet connection.',
        statusCode: 0,
      );
    } on HttpException catch (e) {
      _apiLog('API', 'HttpException GET $endpoint: $e');
      throw ApiException(
        message: 'HTTP error: ${e.message}',
        statusCode: 0,
      );
    } catch (e) {
      _apiLog('API', 'Exception GET $endpoint: $e');
      // Check for connection closed errors
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('connection closed') || 
          errorStr.contains('connection reset') ||
          errorStr.contains('connection terminated')) {
        throw ApiException(
          message: 'Connection error: The server closed the connection unexpectedly. Please try again.',
          statusCode: 0,
        );
      }
      throw ApiException(message: 'Network error: $e');
    }
  }

  // POST request
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final bodyStr = body != null ? jsonEncode(body) : null;
      _apiLog('API', 'POST $endpoint', bodyStr);
      final httpClient = client ?? http.Client();

      final response = await httpClient.post(
        uri,
        headers: _getHeaders(headers: headers, requireAuth: requireAuth),
        body: bodyStr,
      );

      return _handleResponse(response, requestMethod: 'POST $endpoint');
    } catch (e) {
      _apiLog('API', 'Exception POST $endpoint: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }

  // PUT request
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final bodyStr = body != null ? jsonEncode(body) : null;
      _apiLog('API', 'PUT $endpoint', bodyStr);
      final httpClient = client ?? http.Client();

      final response = await httpClient.put(
        uri,
        headers: _getHeaders(headers: headers, requireAuth: requireAuth),
        body: bodyStr,
      );

      return _handleResponse(response, requestMethod: 'PUT $endpoint');
    } catch (e) {
      _apiLog('API', 'Exception PUT $endpoint: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }

  // PATCH request
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final bodyStr = body != null ? jsonEncode(body) : null;
      _apiLog('API', 'PATCH $endpoint', bodyStr);
      final httpClient = client ?? http.Client();

      final response = await httpClient.patch(
        uri,
        headers: _getHeaders(headers: headers, requireAuth: requireAuth),
        body: bodyStr,
      );

      return _handleResponse(response, requestMethod: 'PATCH $endpoint');
    } catch (e) {
      _apiLog('API', 'Exception PATCH $endpoint: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }

  // DELETE request
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final bodyStr = body != null ? jsonEncode(body) : null;
      _apiLog('API', 'DELETE $endpoint', bodyStr);
      final httpClient = client ?? http.Client();

      final request = http.Request('DELETE', uri);
      request.headers.addAll(_getHeaders(headers: headers, requireAuth: requireAuth));
      if (bodyStr != null) {
        request.body = bodyStr;
      }

      final streamedResponse = await httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response, requestMethod: 'DELETE $endpoint');
    } catch (e) {
      _apiLog('API', 'Exception DELETE $endpoint: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }

  // POST multipart request for file uploads
  Future<dynamic> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    Map<String, File>? files,
    Map<String, String>? fileNames,
    Map<String, Map<String, dynamic>>? fileBytes,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final httpClient = client ?? http.Client();

      final request = http.MultipartRequest('POST', uri);

      // Add headers (excluding Content-Type for multipart)
      final headers = _getHeaders(requireAuth: requireAuth);
      headers.remove('Content-Type'); // Let multipart set it
      request.headers.addAll(headers);

      // Add fields
      request.fields.addAll(fields);

      // Add files (for mobile/desktop)
      if (files != null && !kIsWeb) {
        for (final entry in files.entries) {
          final file = entry.value;

          // Check if file exists
          if (!await file.exists()) {
            throw ApiException(
              message: 'File does not exist: ${file.path}',
            );
          }

          // Get file length
          final fileLength = await file.length();
          if (fileLength == 0) {
            throw ApiException(
              message: 'File is empty: ${file.path}',
            );
          }

          // Use provided filename if available, otherwise extract from path
          String fileName;
          if (fileNames != null && fileNames.containsKey(entry.key)) {
            fileName = fileNames[entry.key]!;
          } else {
            fileName = file.path.split('/').last;
            // If filename doesn't have extension, try to detect from path
            if (!fileName.contains('.')) {
              final pathParts = file.path.split('.');
              if (pathParts.length > 1) {
                fileName =
                    '${pathParts[pathParts.length - 2]}.${pathParts.last}';
              } else {
                // Default to jpg for images
                fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
              }
            }
          }

          // Ensure filename is not empty
          if (fileName.isEmpty) {
            fileName = 'file_${DateTime.now().millisecondsSinceEpoch}';
          }

          // Determine content type from file extension (same as web)
          String? contentType;
          final lowerFileName = fileName.toLowerCase();
          if (lowerFileName.endsWith('.pdf')) {
            contentType = 'application/pdf';
          } else if (lowerFileName.endsWith('.jpg') ||
              lowerFileName.endsWith('.jpeg')) {
            contentType = 'image/jpeg';
          } else if (lowerFileName.endsWith('.png')) {
            contentType = 'image/png';
          } else if (lowerFileName.endsWith('.gif')) {
            contentType = 'image/gif';
          } else if (lowerFileName.endsWith('.doc')) {
            contentType = 'application/msword';
          } else if (lowerFileName.endsWith('.docx')) {
            contentType =
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          } else if (lowerFileName.endsWith('.xls')) {
            contentType = 'application/vnd.ms-excel';
          } else if (lowerFileName.endsWith('.xlsx')) {
            contentType =
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          } else if (lowerFileName.endsWith('.txt')) {
            contentType = 'text/plain';
          } else if (lowerFileName.endsWith('.wav')) {
            contentType = 'audio/wav';
          } else if (lowerFileName.endsWith('.mp3')) {
            contentType = 'audio/mpeg';
          } else if (lowerFileName.endsWith('.webm')) {
            contentType = 'audio/webm';
          } else if (lowerFileName.endsWith('.ogg')) {
            contentType = 'audio/ogg';
          } else if (lowerFileName.endsWith('.m4a')) {
            // M4A files use audio/mp4 MIME type (MPEG-4 Audio)
            // This is the standard MIME type that Laravel's mimes validation recognizes
            contentType = 'audio/mp4';
          }

          // Read file as bytes to ensure it's fully loaded
          final fileDataBytes = await file.readAsBytes();
          final fileStream = http.ByteStream.fromBytes(fileDataBytes);

          final multipartFile = http.MultipartFile(
            entry.key,
            fileStream,
            fileDataBytes.length,
            filename: fileName,
            contentType:
                contentType != null ? http.MediaType.parse(contentType) : null,
          );

          print('[ApiClient] 📤 Uploading file: $fileName');
          print('[ApiClient] 📤 Content-Type: ${contentType ?? "auto-detect"}');
          final fileSizeMB =
              (fileDataBytes.length / 1024 / 1024).toStringAsFixed(2);
          print(
              '[ApiClient] 📤 File size: $fileSizeMB MB (${fileDataBytes.length} bytes)');
          request.files.add(multipartFile);
        }
      }

      // Add file bytes (for web)
      if (fileBytes != null && kIsWeb) {
        for (final entry in fileBytes.entries) {
          final fileData = entry.value;

          final bytes = fileData['bytes'];
          final fileName = fileData['filename'];

          if (bytes == null || fileName == null) {
            continue;
          }

          if (bytes is! Uint8List || bytes.isEmpty) {
            continue;
          }

          // Determine content type from file extension
          String? contentType;
          final lowerFileName = fileName.toString().toLowerCase();
          if (lowerFileName.endsWith('.pdf')) {
            contentType = 'application/pdf';
          } else if (lowerFileName.endsWith('.jpg') ||
              lowerFileName.endsWith('.jpeg')) {
            contentType = 'image/jpeg';
          } else if (lowerFileName.endsWith('.png')) {
            contentType = 'image/png';
          } else if (lowerFileName.endsWith('.doc')) {
            contentType = 'application/msword';
          } else if (lowerFileName.endsWith('.docx')) {
            contentType =
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          } else if (lowerFileName.endsWith('.xls')) {
            contentType = 'application/vnd.ms-excel';
          } else if (lowerFileName.endsWith('.xlsx')) {
            contentType =
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          } else if (lowerFileName.endsWith('.wav')) {
            contentType = 'audio/wav';
          } else if (lowerFileName.endsWith('.mp3')) {
            contentType = 'audio/mpeg';
          } else if (lowerFileName.endsWith('.webm')) {
            contentType = 'audio/webm';
          } else if (lowerFileName.endsWith('.ogg')) {
            contentType = 'audio/ogg';
          } else if (lowerFileName.endsWith('.m4a')) {
            // M4A files use audio/mp4 MIME type (MPEG-4 Audio)
            contentType = 'audio/mp4';
          }

          print('[ApiClient] 📤 Uploading file (web): $fileName');
          print('[ApiClient] 📤 Content-Type: ${contentType ?? "auto-detect"}');
          final webFileSizeMB = (bytes.length / 1024 / 1024).toStringAsFixed(2);
          print(
              '[ApiClient] 📤 File size: $webFileSizeMB MB (${bytes.length} bytes)');

          final multipartFile = http.MultipartFile.fromBytes(
            entry.key,
            bytes,
            filename: fileName.toString(),
            contentType:
                contentType != null ? http.MediaType.parse(contentType) : null,
          );
          request.files.add(multipartFile);
        }
      }

      _apiLog('API', 'POST (multipart) $endpoint');
      final streamedResponse = await httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response, requestMethod: 'POST $endpoint');
    } catch (e) {
      _apiLog('API', 'Exception POST (multipart) $endpoint: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Network error: $e');
    }
  }
}
