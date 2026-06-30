import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_providers.dart';
import '../core/config/api_constants.dart';

/// Displays a patient photo securely.
///
/// The `/api/patients/{id}/photo` endpoint requires an Authorization header.
/// Since [Image.network] cannot send custom headers reliably on all platforms,
/// this widget fetches the image bytes via [ApiClient] (which attaches the
/// Bearer token automatically) and renders them with [Image.memory].
///
/// For URLs that are already full public B2 signed URLs (start with
/// `https://f` — Backblaze CDN), [Image.network] is used directly since
/// those are already time-limited signed URLs that don't need extra auth.
///
/// Parameters:
///   [photoUrl]     – the URL from patient.photoUrl (already absolute)
///   [width]        – optional width constraint
///   [height]       – optional height constraint
///   [fit]          – BoxFit, default cover
///   [fallback]     – widget to show when there is no photo
///   [errorFallback]– widget to show on load error
class AuthenticatedImage extends ConsumerStatefulWidget {
  final String? photoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;
  final Widget? errorFallback;

  const AuthenticatedImage({
    super.key,
    required this.photoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
    this.errorFallback,
  });

  @override
  ConsumerState<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends ConsumerState<AuthenticatedImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;
  String? _lastUrl;

  @override
  void didUpdateWidget(AuthenticatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _fetch();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final url = widget.photoUrl;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() { _loading = false; _error = false; _bytes = null; });
      return;
    }

    // B2 signed URLs are already publicly accessible (time-limited) — use Image.network directly
    // They look like: https://f002.backblazeb2.com/... or contain Authorization=...
    final isPublicSignedUrl = url.contains('backblazeb2.com') ||
        url.contains('Authorization=') ||
        url.contains('authorizationToken=');

    if (isPublicSignedUrl) {
      if (mounted) setState(() { _loading = false; _bytes = null; _lastUrl = url; });
      return;
    }

    if (mounted) setState(() { _loading = true; _error = false; });
    _lastUrl = url;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.getRaw(url);
      if (!mounted) return;
      if (response != null && response.isNotEmpty) {
        setState(() { _bytes = response; _loading = false; _error = false; });
      } else {
        setState(() { _loading = false; _error = true; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.photoUrl;

    if (url == null || url.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.fallback ?? const SizedBox.shrink(),
      );
    }

    // Public signed URL — use Image.network directly
    final isPublicSignedUrl = url.contains('backblazeb2.com') ||
        url.contains('Authorization=') ||
        url.contains('authorizationToken=');

    if (isPublicSignedUrl) {
      return Image.network(
        url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) =>
            widget.errorFallback ?? widget.fallback ?? const SizedBox.shrink(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _buildLoading(),
      );
    }

    if (_loading) return _buildLoading();

    if (_error || _bytes == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorFallback ?? widget.fallback ?? const SizedBox.shrink(),
      );
    }

    return Image.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) =>
          widget.errorFallback ?? widget.fallback ?? const SizedBox.shrink(),
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
