import 'dart:math' as math;
import 'package:flutter/material.dart';

/// State of the Sun connection widget
enum SunConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

class RoozanehSunWidget extends StatefulWidget {
  const RoozanehSunWidget({
    super.key,
    required this.connectionState,
    required this.onTap,
    this.enabled = true,
    this.size = 200,
  });

  final SunConnectionState connectionState;
  final VoidCallback onTap;
  final bool enabled;
  final double size;

  @override
  State<RoozanehSunWidget> createState() => _RoozanehSunWidgetState();
}

class _RoozanehSunWidgetState extends State<RoozanehSunWidget>
    with TickerProviderStateMixin {
  // Continuous rotation for outer orbital rings & particles
  late final AnimationController _orbitController;

  // Pulse / breathing animation controller for glow and aura
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Interaction feedback (press scale)
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didUpdateWidget(covariant RoozanehSunWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectionState != widget.connectionState) {
      if (widget.connectionState == SunConnectionState.connecting ||
          widget.connectionState == SunConnectionState.disconnecting) {
        _orbitController.duration = const Duration(seconds: 4);
        if (!_orbitController.isAnimating) {
          _orbitController.repeat();
        }
      } else if (widget.connectionState == SunConnectionState.connected) {
        _orbitController.duration = const Duration(seconds: 14);
        if (!_orbitController.isAnimating) {
          _orbitController.repeat();
        }
      } else {
        _orbitController.duration = const Duration(seconds: 24);
        if (!_orbitController.isAnimating) {
          _orbitController.repeat();
        }
      }
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnecting =
        widget.connectionState == SunConnectionState.connecting;
    final isDisconnecting =
        widget.connectionState == SunConnectionState.disconnecting;
    final isConnected = widget.connectionState == SunConnectionState.connected;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: isConnecting
          ? "در حال اتصال"
          : isDisconnecting
              ? "در حال قطع اتصال"
              : isConnected
                  ? "متصل است"
                  : "متصل نیست",
      child: GestureDetector(
        onTapDown: widget.enabled
            ? (_) => setState(() => _isPressed = true)
            : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _isPressed = false);
                widget.onTap();
              }
            : null,
        onTapCancel: widget.enabled
            ? () => setState(() => _isPressed = false)
            : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: Listenable.merge([_orbitController, _pulseAnimation]),
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _SunPainter(
                    orbitProgress: _orbitController.value,
                    pulseProgress: _pulseAnimation.value,
                    connectionState: widget.connectionState,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SunPainter extends CustomPainter {
  _SunPainter({
    required this.orbitProgress,
    required this.pulseProgress,
    required this.connectionState,
  });

  final double orbitProgress;
  final double pulseProgress;
  final SunConnectionState connectionState;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final isConnected = connectionState == SunConnectionState.connected;
    final isConnecting = connectionState == SunConnectionState.connecting;
    final isDisconnecting = connectionState == SunConnectionState.disconnecting;

    // Dimensions relative to total size
    final sunRadius = size.width * 0.285;
    final innerOrbitRadius = size.width * 0.355;
    final outerOrbitRadius = size.width * 0.425;

    // -------------------------------------------------------------
    // 1. AMBIENT RADIAL BLOOM & GLOW (Diffused aura behind the sun)
    // -------------------------------------------------------------
    final glowRadius = size.width * (isConnected ? 0.48 : 0.44) * (0.92 + (pulseProgress - 0.85) * 0.4);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: isConnected
            ? [
                const Color(0xFFFFB300).withValues(alpha: 0.55),
                const Color(0xFFFF8F00).withValues(alpha: 0.32),
                const Color(0xFFFF6F00).withValues(alpha: 0.12),
                Colors.transparent,
              ]
            : [
                const Color(0xFFFFB74D).withValues(alpha: isConnecting ? 0.6 : 0.42),
                const Color(0xFFFF9800).withValues(alpha: isConnecting ? 0.35 : 0.22),
                const Color(0xFFFF5722).withValues(alpha: 0.08),
                Colors.transparent,
              ],
        stops: const [0.0, 0.45, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

    canvas.drawCircle(center, glowRadius, glowPaint);

    // -------------------------------------------------------------
    // 2. ORBITAL RINGS (Thin luminous circles)
    // -------------------------------------------------------------
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Inner orbital ring
    ringPaint.color = isConnected
        ? const Color(0xFFFFC107).withValues(alpha: 0.50)
        : const Color(0xFFFFB74D).withValues(alpha: isConnecting ? 0.65 : 0.38);
    canvas.drawCircle(center, innerOrbitRadius, ringPaint);

    // Outer orbital ring
    ringPaint.color = isConnected
        ? const Color(0xFFFFD54F).withValues(alpha: 0.65)
        : const Color(0xFFFFB74D).withValues(alpha: isConnecting ? 0.75 : 0.45);
    ringPaint.strokeWidth = 1.5;
    canvas.drawCircle(center, outerOrbitRadius, ringPaint);

    // -------------------------------------------------------------
    // 3. ORBITING PARTICLES & SPARKLE DOTS
    // -------------------------------------------------------------
    final particleAngles = [
      0.0,
      math.pi * 0.48,
      math.pi * 0.95,
      math.pi * 1.42,
      math.pi * 1.85,
    ];

    for (int i = 0; i < particleAngles.length; i++) {
      final baseAngle = particleAngles[i];
      // Alternate rotation directions or offsets
      final currentAngle = baseAngle + (orbitProgress * 2 * math.pi) * (i.isEven ? 1 : -0.7);
      final dotRadius = (i == 0 || i == 3) ? outerOrbitRadius : innerOrbitRadius;
      final dotOffset = Offset(
        center.dx + dotRadius * math.cos(currentAngle),
        center.dy + dotRadius * math.sin(currentAngle),
      );

      final dotSize = (i == 0 || i == 2) ? 3.0 : 2.2;
      final sparkleBrightness = (math.sin(orbitProgress * 2 * math.pi * 2 + i) + 1) / 2;

      // Particle outer soft glow
      final pGlow = Paint()
        ..color = (isConnected ? const Color(0xFFFFE082) : const Color(0xFFFFCC80))
            .withValues(alpha: 0.3 + sparkleBrightness * 0.4);
      canvas.drawCircle(dotOffset, dotSize * 2.2, pGlow);

      // Particle core dot
      final pDot = Paint()
        ..color = isConnected ? Colors.white : const Color(0xFFFFF8E1);
      canvas.drawCircle(dotOffset, dotSize, pDot);
    }

    // -------------------------------------------------------------
    // 4. 3D SPHERICAL SUN CORE DISC (Rich Radiant Gradient)
    // -------------------------------------------------------------
    // Subtle 3D focal point offset slightly towards top-center
    final focalOffset = Offset(center.dx, center.dy - (sunRadius * 0.15));

    final sunShader = RadialGradient(
      center: Alignment(
        (focalOffset.dx - center.dx) / sunRadius,
        (focalOffset.dy - center.dy) / sunRadius,
      ),
      radius: 0.95,
      colors: isConnected
          ? const [
              Color(0xFFFFFDE7), // Luminous white-yellow solar core
              Color(0xFFFFEE58), // Radiant warm yellow
              Color(0xFFFFB300), // Golden amber
              Color(0xFFFF8F00), // Rich orange
              Color(0xFFE65100), // Deep rim
            ]
          : [
              const Color(0xFFFFF9C4), // Bright light center
              const Color(0xFFFFD54F), // Gold yellow
              const Color(0xFFFFA726), // Amber
              const Color(0xFFFF7A00), // Warm orange
              const Color(0xFFE65100), // Deep orange border
            ],
      stops: const [0.0, 0.25, 0.55, 0.82, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: sunRadius));

    final sunPaint = Paint()..shader = sunShader;
    canvas.drawCircle(center, sunRadius, sunPaint);

    // -------------------------------------------------------------
    // 5. CRISP GOLDEN RIM / BEVEL
    // -------------------------------------------------------------
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFFE082),
          Color(0xFFFFB74D),
          Color(0xFFFF8F00),
          Color(0xFFFFE082),
        ],
        stops: [0.0, 0.45, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: sunRadius));

    canvas.drawCircle(center, sunRadius, rimPaint);

    // -------------------------------------------------------------
    // 6. SUN EMBLEM / ICON IN CENTER (Stylized glyph)
    // -------------------------------------------------------------
    canvas.save();
    // If connecting, give the center sun glyph a smooth continuous rotation
    if (isConnecting || isDisconnecting) {
      canvas.translate(center.dx, center.dy);
      canvas.rotate(orbitProgress * 2 * math.pi * 2);
      canvas.translate(-center.dx, -center.dy);
    }

    const emblemColor = Color(0xFF292524); // Warm deep charcoal
    final emblemPaint = Paint()
      ..color = emblemColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final centerRingRadius = sunRadius * 0.32;
    // Central hollow sun ring
    canvas.drawCircle(center, centerRingRadius, emblemPaint);

    // 8 Solar Ray Pins
    final rayStartDist = centerRingRadius + (sunRadius * 0.12);
    final rayLength = sunRadius * 0.18;

    for (int i = 0; i < 8; i++) {
      final angle = i * (math.pi / 4);
      final x1 = center.dx + rayStartDist * math.cos(angle);
      final y1 = center.dy + rayStartDist * math.sin(angle);
      final x2 = center.dx + (rayStartDist + rayLength) * math.cos(angle);
      final y2 = center.dy + (rayStartDist + rayLength) * math.sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), emblemPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SunPainter oldDelegate) {
    return oldDelegate.orbitProgress != orbitProgress ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.connectionState != connectionState;
  }
}
