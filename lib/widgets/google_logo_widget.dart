// lib/widgets/google_logo_widget.dart - Custom Google Logo Widget
import 'package:flutter/material.dart';

class GoogleLogoWidget extends StatelessWidget {
  final double size;

  const GoogleLogoWidget({
    super.key,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          // Try to load Google logo from network first
          Image.network(
            'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback: Create Google logo with colored segments
              return _buildFallbackLogo();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: CustomPaint(
        painter: GoogleLogoPainter(size: size),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  final double size;

  GoogleLogoPainter({required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = canvasSize.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // White background circle
    paint.color = Colors.white;
    canvas.drawCircle(center, radius, paint);

    // Blue segment (top-right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -1.57, 1.57, true, paint);

    // Green segment (bottom-right)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0, 1.57, true, paint);

    // Yellow segment (bottom-left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 1.57, 1.57, true, paint);

    // Red segment (top-left, smaller)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.14, 1.0, true, paint);

    // Inner white circle for "G" shape
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.6, paint);

    // Blue horizontal line for "G"
    paint.color = const Color(0xFF4285F4);
    paint.strokeWidth = size * 0.12;
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.35, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
