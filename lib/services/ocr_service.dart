// lib/services/ocr_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/utils/result.dart';
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';

class OcrService {
  final TextRecognizer _textRecognizer;
  final ApiClient? apiClient;

  OcrService({this.apiClient}) : _textRecognizer = TextRecognizer();

  /// Extract information from a Moroccan CNI card image using backend API
  /// This method calls the Laravel backend which includes face recognition
  ///
  /// [extractFace] - Whether to extract face ID for duplicate detection (default: true)
  ///
  /// Returns a Result containing the parsed data:
  /// {
  ///   "text": "...",
  ///   "parsed": {
  ///     "name": "Temsamani Mouhcine",
  ///     "cni_number": "K01234567",
  ///     "birthdate": "1978-11-29",
  ///     "expiry_date": "2029-09-09"
  ///   },
  ///   "face_recognition": {
  ///     "photo_path": "...",
  ///     "face_embedding": "[...]",
  ///     "similar_patients": [...],
  ///     "has_duplicate": true/false
  ///   }
  /// }
  Future<Result<Map<String, dynamic>>> extractMoroccanId(
    dynamic imageFile, {
    bool extractFace = true,
  }) async {
    // If API client is available, use backend API (includes face recognition)
    if (apiClient != null) {
      return _extractMoroccanIdBackend(imageFile, extractFace: extractFace);
    }

    // Fallback to client-side ML Kit (no face recognition)
    return _extractMoroccanIdClientSide(imageFile);
  }

  /// Extract using backend API with face recognition
  Future<Result<Map<String, dynamic>>> _extractMoroccanIdBackend(
    dynamic imageFile, {
    bool extractFace = true,
  }) async {
    print('[OCR Service] ==========================================');
    print(
        '[OCR Service] Starting CNI extraction via backend API (with face recognition)...');
    print('[OCR Service] Platform: ${kIsWeb ? "Web" : "Mobile/Desktop"}');

    try {
      String fileName;
      File? file;
      Uint8List? fileBytes;

      if (kIsWeb) {
        // Web: imageFile is Uint8List
        if (imageFile is! Uint8List) {
          return Failure('Invalid image file format for web');
        }
        fileBytes = imageFile;
        fileName = 'id_card_${DateTime.now().millisecondsSinceEpoch}.png';
        print('[OCR Service] Using image bytes for web platform');
      } else {
        // Mobile/Desktop: imageFile is File
        if (imageFile is! File) {
          return Failure('Invalid image file format');
        }
        file = imageFile;
        fileName = file.path.split('/').last;
        if (!fileName.contains('.')) {
          fileName = '$fileName.png';
        }
        print('[OCR Service] Using image file: ${file.path}');
      }

      print('[OCR Service] Calling backend API: ${ApiConstants.ocrMoroccanId}');
      print('[OCR Service] Extract face ID: $extractFace');

      // Call backend API with multipart upload
      final responseData = kIsWeb
          ? await apiClient!.postMultipart(
              ApiConstants.ocrMoroccanId,
              fields: {
                'extract_face': extractFace ? '1' : '0',
              },
              fileBytes: {
                'file': {
                  'bytes': fileBytes!,
                  'filename': fileName,
                },
              },
              requireAuth: true,
            )
          : await apiClient!.postMultipart(
              ApiConstants.ocrMoroccanId,
              fields: {
                'extract_face': extractFace ? '1' : '0',
              },
              files: {'file': file!},
              fileNames: {'file': fileName},
              requireAuth: true,
            );

      print('[OCR Service] ✓ Backend API response received');

      // Parse response
      if (responseData is Map<String, dynamic>) {
        final result = {
          'text': responseData['text'] ?? '',
          'parsed': responseData['parsed'] ?? {},
          'face_recognition': responseData['face_recognition'],
        };

        // Log face recognition data if available
        if (responseData['face_recognition'] != null) {
          final faceData =
              responseData['face_recognition'] as Map<String, dynamic>;
          print('[OCR Service] ✓ Face recognition data received');
          print(
              '[OCR Service]   - Photo path: ${faceData['photo_path'] ?? 'N/A'}');
          print(
              '[OCR Service]   - Has duplicate: ${faceData['has_duplicate'] ?? false}');
          print(
              '[OCR Service]   - Similar patients: ${(faceData['similar_patients'] as List?)?.length ?? 0}');
        }

        print('[OCR Service] ==========================================');
        return Success(result);
      } else {
        return Failure('Invalid response format from backend');
      }
    } on ApiException catch (e) {
      print('[OCR Service] ✗ API error: ${e.message}');
      return Failure(e.message);
    } catch (e, stackTrace) {
      print('[OCR Service] ✗ Exception occurred:');
      print('[OCR Service] Error: $e');
      print('[OCR Service] Stack trace: $stackTrace');
      return Failure('Failed to extract CNI information: $e');
    }
  }

  /// Extract using client-side ML Kit (fallback, no face recognition)
  Future<Result<Map<String, dynamic>>> _extractMoroccanIdClientSide(
    dynamic imageFile,
  ) async {
    print('[OCR Service] ==========================================');
    print('[OCR Service] Starting CNI extraction process (client-side)...');
    print('[OCR Service] Platform: ${kIsWeb ? "Web" : "Mobile/Desktop"}');
    print('[OCR Service] Using Google ML Kit Text Recognition (on-device)');

    try {
      InputImage inputImage;

      if (kIsWeb) {
        // Web: Google ML Kit doesn't support web platform
        print('[OCR Service] ✗ Web platform not supported by Google ML Kit');
        return Failure(
            'OCR is not available on web platform. Please use a mobile device.');
      } else {
        // Mobile/Desktop: imageFile is File
        print('[OCR Service] Processing image for Mobile/Desktop platform...');
        if (imageFile is! File) {
          print(
              '[OCR Service] ✗ Invalid image file format: ${imageFile.runtimeType}');
          return Failure('Invalid image file format');
        }
        final file = imageFile;
        final fileSize = await file.length();
        final filePath = file.path;
        print('[OCR Service] ✓ Image file found: $filePath');
        print(
            '[OCR Service] File size: $fileSize bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');

        inputImage = InputImage.fromFilePath(filePath);
      }

      // Perform text recognition
      print('[OCR Service] Running text recognition...');
      final startTime = DateTime.now();
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);
      final duration = DateTime.now().difference(startTime);

      print(
          '[OCR Service] ✓ Text recognition completed in ${duration.inMilliseconds}ms');

      // Extract all text
      String fullText = recognizedText.text;
      print('[OCR Service] Raw OCR text length: ${fullText.length} characters');
      print('[OCR Service] ==========================================');
      print('[OCR Service] FULL EXTRACTED TEXT FROM IMAGE:');
      print('[OCR Service] ==========================================');
      print(fullText);
      print('[OCR Service] ==========================================');

      // Also show line by line for easier debugging
      final lines = fullText.split('\n');
      print('[OCR Service] Text lines (${lines.length} total):');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          print('[OCR Service]   Line ${i + 1}: "$line"');
        }
      }
      print('[OCR Service] ==========================================');

      if (fullText.isEmpty) {
        print('[OCR Service] ✗ No text detected in image');
        return Failure(
            'No text detected in the image. Please ensure the CNI card is clearly visible.');
      }

      // Parse Moroccan CNI card information
      print('[OCR Service] Parsing Moroccan CNI card information...');
      final parsed = _parseMoroccanCNI(fullText);

      // Log parsed data
      if (parsed.isNotEmpty) {
        print('[OCR Service] ✓ Parsed data extracted:');
        print('[OCR Service]   - Name: ${parsed['name'] ?? 'N/A'}');
        print('[OCR Service]   - CNI Number: ${parsed['cni_number'] ?? 'N/A'}');
        print('[OCR Service]   - Birthdate: ${parsed['birthdate'] ?? 'N/A'}');
        print(
            '[OCR Service]   - Expiry Date: ${parsed['expiry_date'] ?? 'N/A'}');
      } else {
        print('[OCR Service] ⚠ Could not parse CNI information from text');
      }

      final result = {
        'text': fullText,
        'parsed': parsed,
      };

      print('[OCR Service] ==========================================');
      return Success(result);
    } catch (e, stackTrace) {
      print('[OCR Service] ✗ Exception occurred:');
      print('[OCR Service] Error: $e');
      print('[OCR Service] Stack trace: $stackTrace');

      String errorMessage = 'Failed to extract CNI information';
      if (e.toString().contains('PlatformException')) {
        errorMessage =
            'OCR processing error: Please try again with a clearer image';
        print('[OCR Service] Error type: Platform error');
      } else {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        print('[OCR Service] Error type: Unknown');
      }

      print('[OCR Service] Final error message: $errorMessage');
      print('[OCR Service] ==========================================');
      return Failure(errorMessage);
    }
  }

  /// Parse Moroccan CNI card text to extract structured information
  Map<String, dynamic> _parseMoroccanCNI(String text) {
    final parsed = <String, dynamic>{};
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    print('[OCR Service] Parsing ${lines.length} text lines...');
    print(
        '[OCR Service] Searching for CNI number pattern: [A-Z]{1,2}\\d{6,10}');

    // Extract CNI number (format: letters followed by digits)
    // Moroccan CNI numbers typically start with 1-2 letters followed by 5-10 digits
    print('[OCR Service] Searching for CNI number...');
    final cniPatterns = [
      RegExp(r'[A-Z]{1,2}\d{5,10}',
          caseSensitive: false), // 1-2 letters + 5-10 digits (most common)
      RegExp(r'[A-Z]{2}\d{5,7}'), // Two letters + 5-7 digits (like DJ45528)
      RegExp(r'[A-Z]\d{5,9}'), // Single letter + 5-9 digits
      RegExp(r'\d{8,10}'), // Just 8-10 digits (no letters)
    ];

    bool cniFound = false;
    for (final pattern in cniPatterns) {
      for (final line in lines) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final cniNumber = match.group(0)?.toUpperCase();
          // Additional validation: should be on its own line or with minimal other text
          if (cniNumber != null &&
              (line.trim() == cniNumber ||
                  line.trim().length <= cniNumber.length + 3)) {
            parsed['cni_number'] = cniNumber;
            print(
                '[OCR Service] ✓ Found CNI number: ${parsed['cni_number']} in line: "$line"');
            cniFound = true;
            break;
          }
        }
      }
      if (cniFound) break;
    }

    if (!cniFound) {
      print('[OCR Service] ✗ CNI number not found with any pattern');
    }

    // Extract dates (format: DD/MM/YYYY or DD-MM-YYYY or YYYY-MM-DD)
    print(
        '[OCR Service] Searching for dates with patterns: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD');
    final datePatterns = [
      RegExp(r'\d{2}[/-]\d{2}[/-]\d{4}'), // DD/MM/YYYY or DD-MM-YYYY
      RegExp(r'\d{4}[/-]\d{2}[/-]\d{2}'), // YYYY/MM/DD or YYYY-MM-DD
      RegExp(r'\d{2}\.\d{2}\.\d{4}'), // DD.MM.YYYY
      RegExp(r'\d{2}\s+\d{2}\s+\d{4}'), // DD MM YYYY (spaces)
    ];

    final dates = <String>[];
    for (final line in lines) {
      for (final pattern in datePatterns) {
        final matches = pattern.allMatches(line);
        for (final match in matches) {
          final dateStr = match.group(0)!;
          dates.add(dateStr);
          print('[OCR Service] Found date: "$dateStr" in line: "$line"');
        }
      }
    }
    print('[OCR Service] Total dates found: ${dates.length}');

    // Try to identify birthdate and expiry date
    // Use date value to determine: earlier date = birthdate, later date = expiry
    if (dates.isNotEmpty) {
      final normalizedDates = <String>[];
      for (final dateStr in dates) {
        final normalized = _normalizeDate(dateStr);
        if (normalized != null) {
          normalizedDates.add(normalized);
        }
      }

      if (normalizedDates.isNotEmpty) {
        // Sort dates chronologically
        normalizedDates.sort();

        // Earliest date is birthdate
        parsed['birthdate'] = normalizedDates[0];
        print('[OCR Service] Found birthdate: ${parsed['birthdate']}');

        // Latest date is expiry date
        if (normalizedDates.length > 1) {
          parsed['expiry_date'] = normalizedDates[normalizedDates.length - 1];
          print('[OCR Service] Found expiry date: ${parsed['expiry_date']}');
        }
      }
    }

    // Extract name - Look for consecutive single-word lines (first name + last name)
    // Or a single line with 2-4 words
    print('[OCR Service] Searching for name...');
    final skipWords = [
      'ROYAUME',
      'ROYAUMme',
      'DU',
      'MAROC',
      'MOROCCO',
      'IDENTITE',
      'CARTE',
      'NATIONAL',
      'NATIONALE',
      'NÉ',
      'LE',
      'VALABLE',
      'JUSQU\'AU',
      'À'
    ];

    // Strategy 1: Find all potential name words (single-word, uppercase, no digits, not in skip list)
    // Filter out very short words (like "MG" which is likely a country code)
    print('[OCR Service] Strategy 1: Finding all potential name words...');
    final potentialNames = <Map<String, dynamic>>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final isSingleWord = line.split(' ').length == 1;
      final hasValidLength = line.length >= 3 &&
          line.length <= 20; // At least 3 characters (filter out "MG", etc.)
      final noDigits = !line.contains(RegExp(r'\d'));
      final isUppercase = RegExp(r'^[A-ZÀ-ÿ]+$').hasMatch(line);

      if (isSingleWord && hasValidLength && noDigits && isUppercase) {
        // Check if it's not in skip list
        bool shouldSkip = false;
        for (final skipWord in skipWords) {
          if (line.toUpperCase().contains(skipWord)) {
            shouldSkip = true;
            break;
          }
        }
        if (!shouldSkip) {
          potentialNames.add({
            'text': line,
            'index': i,
            'lineNumber': i + 1,
          });
          print(
              '[OCR Service]   Found potential name word at line ${i + 1}: "$line"');
        }
      }
    }

    print('[OCR Service] Found ${potentialNames.length} potential name words');

    // Strategy 2: Look for names near "Né le" or "Né te" (birthdate indicator - OCR sometimes reads "le" as "te")
    bool nameFound = false;
    int neLeIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final lineLower = lines[i].toLowerCase();
      if (lineLower.contains('né le') ||
          lineLower.contains('ne le') ||
          lineLower.contains('né te') || // OCR error: "le" read as "te"
          lineLower.contains('ne te')) {
        neLeIndex = i;
        print('[OCR Service] Found "Né le/te" at line ${i + 1}: "${lines[i]}"');
        break;
      }
    }

    if (neLeIndex >= 0 && potentialNames.isNotEmpty) {
      // Look for name words near "Né le" (within 3 lines before or after)
      final nearbyNames = potentialNames.where((name) {
        final nameIndex = name['index'] as int;
        return (nameIndex >= neLeIndex - 3 && nameIndex <= neLeIndex + 3);
      }).toList();

      if (nearbyNames.length >= 2) {
        // Found multiple names near birthdate - combine them
        nearbyNames
            .sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
        final name1 = nearbyNames[0]['text'] as String;
        final name2 = nearbyNames[1]['text'] as String;

        // Usually the name appearing later (higher index) is first name
        // But in this case, check which order makes more sense
        final firstName =
            name2[0].toUpperCase() + name2.substring(1).toLowerCase();
        final lastName =
            name1[0].toUpperCase() + name1.substring(1).toLowerCase();
        parsed['name'] = '$firstName $lastName';
        print(
            '[OCR Service] ✓ Found name near "Né le": ${parsed['name']} from "$name1" + "$name2"');
        nameFound = true;
      } else if (nearbyNames.length == 1) {
        // Only one name found, might need to look further
        print(
            '[OCR Service] Only one name found near "Né le": ${nearbyNames[0]['text']}');
      }
    }

    // Strategy 3: Look for consecutive name words (highest priority - most reliable)
    if (!nameFound && potentialNames.length >= 2) {
      print(
          '[OCR Service] Strategy 3: Looking for consecutive name words (highest priority)...');
      for (int i = 0; i < potentialNames.length - 1; i++) {
        final name1 = potentialNames[i];
        final name2 = potentialNames[i + 1];
        final index1 = name1['index'] as int;
        final index2 = name2['index'] as int;

        // Check if they're consecutive (index difference = 1)
        if ((index2 - index1) == 1) {
          final text1 = name1['text'] as String;
          final text2 = name2['text'] as String;

          // Usually the one appearing later is first name
          final firstName =
              text2[0].toUpperCase() + text2.substring(1).toLowerCase();
          final lastName =
              text1[0].toUpperCase() + text1.substring(1).toLowerCase();
          parsed['name'] = '$firstName $lastName';
          print(
              '[OCR Service] ✓ Found name (consecutive lines): ${parsed['name']} from lines ${name1['lineNumber']} ("$text1") + ${name2['lineNumber']} ("$text2")');
          nameFound = true;
          break;
        }
      }
    }

    // Strategy 3b: If not found, look for two name words close to each other (within 3 lines)
    if (!nameFound && potentialNames.length >= 2) {
      print(
          '[OCR Service] Strategy 3b: Looking for two name words close to each other (within 3 lines)...');
      for (int i = 0; i < potentialNames.length - 1; i++) {
        final name1 = potentialNames[i];
        final name2 = potentialNames[i + 1];
        final index1 = name1['index'] as int;
        final index2 = name2['index'] as int;

        // Check if they're within 3 lines of each other (more strict than before)
        if ((index2 - index1) <= 3) {
          final text1 = name1['text'] as String;
          final text2 = name2['text'] as String;

          // Usually the one appearing later is first name
          final firstName =
              text2[0].toUpperCase() + text2.substring(1).toLowerCase();
          final lastName =
              text1[0].toUpperCase() + text1.substring(1).toLowerCase();
          parsed['name'] = '$firstName $lastName';
          print(
              '[OCR Service] ✓ Found name (close lines): ${parsed['name']} from lines ${name1['lineNumber']} ("$text1") + ${name2['lineNumber']} ("$text2")');
          nameFound = true;
          break;
        }
      }
    }

    // Strategy 4: Try consecutive single-word lines (original approach)
    if (!nameFound) {
      print(
          '[OCR Service] Strategy 4: Checking for consecutive single-word name lines...');
      for (int i = 0; i < lines.length - 1 && i < 10; i++) {
        final line1 = lines[i].trim();
        final line2 = lines[i + 1].trim();

        final isSingleWord1 = line1.split(' ').length == 1;
        final isSingleWord2 = line2.split(' ').length == 1;
        final hasValidLength1 = line1.length >= 2 && line1.length <= 20;
        final hasValidLength2 = line2.length >= 2 && line2.length <= 20;
        final noDigits1 = !line1.contains(RegExp(r'\d'));
        final noDigits2 = !line2.contains(RegExp(r'\d'));
        final isUppercase1 = RegExp(r'^[A-ZÀ-ÿ]+$').hasMatch(line1);
        final isUppercase2 = RegExp(r'^[A-ZÀ-ÿ]+$').hasMatch(line2);

        if (isSingleWord1 &&
            isSingleWord2 &&
            hasValidLength1 &&
            hasValidLength2 &&
            noDigits1 &&
            noDigits2 &&
            isUppercase1 &&
            isUppercase2) {
          bool shouldSkip = false;
          for (final skipWord in skipWords) {
            if (line1.toUpperCase().contains(skipWord) ||
                line2.toUpperCase().contains(skipWord)) {
              shouldSkip = true;
              break;
            }
          }
          if (!shouldSkip) {
            final firstName =
                line1[0].toUpperCase() + line1.substring(1).toLowerCase();
            final lastName =
                line2[0].toUpperCase() + line2.substring(1).toLowerCase();
            parsed['name'] = '$firstName $lastName';
            print(
                '[OCR Service] ✓ Found name (consecutive lines): ${parsed['name']} from lines "$line1" + "$line2"');
            nameFound = true;
            break;
          }
        }
      }
    }

    // If not found, try single line with 2-4 words
    if (!nameFound) {
      print('[OCR Service] Trying single line name pattern (2-4 words)...');
      final namePattern =
          RegExp(r'^[A-ZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞß\s]{3,50}$');
      for (int i = 0; i < lines.length && i < 10; i++) {
        final line = lines[i];
        print('[OCR Service] Checking line ${i + 1} for name: "$line"');
        if (namePattern.hasMatch(line) &&
            line.split(' ').length >= 2 &&
            line.split(' ').length <= 4 &&
            !line.contains(RegExp(r'\d'))) {
          // Skip if it contains common words that are not names
          final upperLine = line.toUpperCase();
          bool shouldSkip = false;
          for (final skipWord in skipWords) {
            if (upperLine.contains(skipWord)) {
              print(
                  '[OCR Service] Skipping line (contains "$skipWord"): "$line"');
              shouldSkip = true;
              break;
            }
          }
          if (!shouldSkip) {
            // Capitalize properly (first letter of each word)
            final nameParts = line.split(' ').map((part) {
              if (part.isEmpty) return part;
              return part[0].toUpperCase() + part.substring(1).toLowerCase();
            }).toList();
            parsed['name'] = nameParts.join(' ');
            print('[OCR Service] ✓ Found name: ${parsed['name']}');
            nameFound = true;
            break;
          }
        }
      }
    }

    if (!nameFound) {
      print('[OCR Service] ✗ Name not found');
    }

    // Extract address - Look for lines starting with "à" or containing location names
    print('[OCR Service] Searching for address...');
    bool addressFound = false;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      // Look for lines starting with "à" (French for "at/in")
      // Also handle OCR errors where "à" might be read as "a" without accent
      final lineLower = line.toLowerCase();
      if (lineLower.startsWith('à ') ||
          (lineLower.startsWith('a ') && line.length > 10)) {
        // "a " with enough text after
        // Remove "à " or "a " prefix and capitalize properly
        String address = line.substring(2).trim();
        if (address.isNotEmpty && address.length >= 5) {
          // Minimum address length
          // Capitalize first letter of each word
          final addressParts = address.split(' ').map((part) {
            if (part.isEmpty) return part;
            return part[0].toUpperCase() + part.substring(1).toLowerCase();
          }).toList();
          parsed['address'] = addressParts.join(' ');
          print(
              '[OCR Service] ✓ Found address: ${parsed['address']} from line ${i + 1}: "$line"');
          addressFound = true;
          break;
        }
      }
    }

    // Alternative: Look for lines with multiple uppercase words (likely addresses)
    if (!addressFound) {
      print(
          '[OCR Service] Trying alternative address pattern (multiple uppercase words)...');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // Look for lines with 3+ uppercase words, no digits, length > 10
        final words = line.split(' ');
        if (words.length >= 3 &&
            line.length > 10 &&
            !line.contains(RegExp(r'\d')) &&
            RegExp(r'^[A-ZÀ-ÿ\s]+$').hasMatch(line)) {
          // Check if it's not a skip word
          bool shouldSkip = false;
          for (final skipWord in skipWords) {
            if (line.toUpperCase().contains(skipWord)) {
              shouldSkip = true;
              break;
            }
          }
          if (!shouldSkip) {
            final addressParts = words.map((part) {
              if (part.isEmpty) return part;
              return part[0].toUpperCase() + part.substring(1).toLowerCase();
            }).toList();
            parsed['address'] = addressParts.join(' ');
            print(
                '[OCR Service] ✓ Found address (alternative): ${parsed['address']} from line ${i + 1}: "$line"');
            addressFound = true;
            break;
          }
        }
      }
    }

    if (!addressFound) {
      print('[OCR Service] ✗ Address not found');
    }

    return parsed;
  }

  /// Normalize date format to YYYY-MM-DD
  String? _normalizeDate(String dateStr) {
    try {
      // Handle dots, slashes, and dashes as separators
      List<String> parts;
      if (dateStr.contains('.')) {
        // DD.MM.YYYY format
        parts = dateStr.split('.');
      } else if (dateStr.contains('/')) {
        parts = dateStr.split('/');
      } else if (dateStr.contains('-')) {
        parts = dateStr.split('-');
      } else {
        return null;
      }

      if (parts.length != 3) return null;

      int day, month, year;

      // Determine format: if first part is 4 digits, it's YYYY-MM-DD
      if (parts[0].length == 4) {
        year = int.parse(parts[0]);
        month = int.parse(parts[1]);
        day = int.parse(parts[2]);
      } else {
        // Assume DD/MM/YYYY or DD-MM-YYYY
        day = int.parse(parts[0]);
        month = int.parse(parts[1]);
        year = int.parse(parts[2]);
      }

      // Validate date
      if (year < 1900 || year > 2100) return null;
      if (month < 1 || month > 12) return null;
      if (day < 1 || day > 31) return null;

      return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    } catch (e) {
      print('[OCR Service] ⚠ Failed to normalize date: $dateStr - $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _textRecognizer.close();
  }
}
