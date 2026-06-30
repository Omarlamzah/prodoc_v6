// lib/widgets/face_detection_camera.dart
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionCamera extends StatefulWidget {
  final Function(File) onImageCaptured;
  final Function()? onCancel;
  final bool enableAutoDetection; // Default to false (OFF)

  const FaceDetectionCamera({
    Key? key,
    required this.onImageCaptured,
    this.onCancel,
    this.enableAutoDetection = false, // Default OFF
  }) : super(key: key);

  @override
  State<FaceDetectionCamera> createState() => _FaceDetectionCameraState();
}

class _FaceDetectionCameraState extends State<FaceDetectionCamera> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _faceDetected = false;
  FaceDetector? _faceDetector;
  Timer? _faceDetectionTimer;
  DateTime? _lastFaceDetectionTime;
  int _faceDetectionCount = 0;
  bool _autoDetectionEnabled = false; // User-controlled auto-detection
  static const int _requiredFaceDetections =
      3; // Require face detected 3 times before auto-capture
  static const Duration _faceDetectionInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _autoDetectionEnabled =
        widget.enableAutoDetection; // Initialize from parameter
    _initializeCamera();
    _initializeFaceDetector();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available')),
          );
        }
        return;
      }

      // Use rear camera if available, otherwise use first camera
      final camera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        // Only start face detection if auto-detection is enabled
        if (_autoDetectionEnabled) {
          _startFaceDetection();
        }
      }
    } catch (e) {
      print('[Face Detection Camera] Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableClassification: false,
      enableLandmarks: false,
      enableTracking: false,
      minFaceSize: 0.1, // Minimum face size (10% of image)
    );
    _faceDetector = FaceDetector(options: options);
  }

  void _startFaceDetection() {
    _faceDetectionTimer?.cancel();
    _faceDetectionTimer = Timer.periodic(_faceDetectionInterval, (timer) {
      if (_controller != null &&
          _controller!.value.isInitialized &&
          !_isCapturing) {
        _detectFaces();
      }
    });
  }

  Future<void> _detectFaces() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    try {
      final image = await _controller!.takePicture();
      if (!mounted || _isCapturing) return;

      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await _faceDetector!.processImage(inputImage);

      // Delete the temporary image
      try {
        await File(image.path).delete();
      } catch (e) {
        // Ignore deletion errors
      }

      if (faces.isNotEmpty && mounted) {
        setState(() {
          _faceDetected = true;
          _lastFaceDetectionTime = DateTime.now();
          _faceDetectionCount++;
        });

        // Auto-capture if face detected multiple times AND auto-detection is enabled
        if (_autoDetectionEnabled &&
            _faceDetectionCount >= _requiredFaceDetections &&
            !_isCapturing) {
          _captureImage();
        }
      } else if (mounted) {
        setState(() {
          _faceDetected = false;
          // Reset count if face not detected for a while
          if (_lastFaceDetectionTime != null &&
              DateTime.now().difference(_lastFaceDetectionTime!) >
                  Duration(seconds: 2)) {
            _faceDetectionCount = 0;
          }
        });
      }
    } catch (e) {
      print('[Face Detection Camera] Error detecting faces: $e');
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final image = await _controller!.takePicture();

      if (mounted) {
        widget.onImageCaptured(File(image.path));
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('[Face Detection Camera] Error capturing image: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    }
  }

  Future<void> _manualCapture() async {
    await _captureImage();
  }

  void _toggleAutoDetection() {
    setState(() {
      _autoDetectionEnabled = !_autoDetectionEnabled;
      if (_autoDetectionEnabled) {
        _startFaceDetection();
      } else {
        _faceDetectionTimer?.cancel();
        _faceDetectionCount = 0;
        _faceDetected = false;
      }
    });
  }

  @override
  void dispose() {
    _faceDetectionTimer?.cancel();
    _faceDetector?.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          // Auto-detection toggle
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.face_retouching_natural,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Auto Detection:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _autoDetectionEnabled,
                    onChanged: (value) => _toggleAutoDetection(),
                    activeColor: Colors.green,
                  ),
                ],
              ),
            ),
          ),
          // Face detection indicator (only show when auto-detection is enabled)
          if (_autoDetectionEnabled && _faceDetected)
            Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.face, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Face Detected${_faceDetectionCount >= _requiredFaceDetections ? ' - Capturing...' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Instructions
          Positioned(
            top: _autoDetectionEnabled && _faceDetected ? 160 : 110,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _autoDetectionEnabled
                    ? 'Position face in frame. Photo will be captured automatically when face is detected.'
                    : 'Position face in frame and tap the capture button to take photo.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () {
                    if (widget.onCancel != null) {
                      widget.onCancel!();
                    }
                    Navigator.of(context).pop();
                  },
                ),
                // Capture button
                GestureDetector(
                  onTap: _isCapturing ? null : _manualCapture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCapturing
                          ? Colors.grey
                          : (_faceDetected ? Colors.green : Colors.white),
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: _isCapturing
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            _faceDetected ? Icons.check : Icons.camera_alt,
                            color: _faceDetected ? Colors.white : Colors.black,
                            size: 32,
                          ),
                  ),
                ),
                // Placeholder for symmetry
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
