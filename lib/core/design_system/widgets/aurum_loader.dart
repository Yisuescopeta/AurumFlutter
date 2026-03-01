import 'package:flutter/material.dart';

class AurumLoader extends StatelessWidget {
  const AurumLoader({
    super.key,
    this.size = 28,
    this.strokeWidth = 3,
    this.color,
    this.centerLogoAsset = 'assets/icons/loader_logo.png',
    this.showCenterLogo = false,
    this.centerLabel = 'A',
    this.showCenterLabel = true,
    this.semanticsLabel = 'Cargando',
    this.centerBackgroundColor,
  });

  final double size;
  final double strokeWidth;
  final Color? color;
  final String centerLogoAsset;
  final bool showCenterLogo;
  final String centerLabel;
  final bool showCenterLabel;
  final String semanticsLabel;
  final Color? centerBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = color ?? theme.colorScheme.primary;
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final innerSize = size * 0.62;
    final trackColor = resolvedColor.withValues(alpha: 0.2);
    final shouldShowCenterLogo = showCenterLogo && size >= 16;
    final shouldShowCenterLabel = showCenterLabel && size >= 14;

    final indicator = reducedMotion
        ? CustomPaint(
            painter: _StaticRingPainter(
              color: resolvedColor,
              strokeWidth: strokeWidth,
              trackColor: trackColor,
            ),
          )
        : CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(resolvedColor),
            backgroundColor: trackColor,
          );

    return Semantics(
      label: semanticsLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: indicator),
              if (shouldShowCenterLogo)
                Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: centerBackgroundColor ?? theme.colorScheme.surface,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (shouldShowCenterLogo)
                        ClipOval(
                          child: Image.asset(
                            centerLogoAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      if (shouldShowCenterLabel)
                        Text(
                          centerLabel,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: resolvedColor,
                            fontWeight: FontWeight.w800,
                            fontSize: innerSize * 0.5,
                            height: 1,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AurumCenteredLoader extends StatelessWidget {
  const AurumCenteredLoader({
    super.key,
    this.size = 32,
    this.strokeWidth = 3,
    this.color,
    this.centerLogoAsset = 'assets/icons/loader_logo.png',
    this.showCenterLogo = false,
    this.centerLabel = 'A',
    this.showCenterLabel = true,
    this.semanticsLabel = 'Cargando',
    this.centerBackgroundColor,
  });

  final double size;
  final double strokeWidth;
  final Color? color;
  final String centerLogoAsset;
  final bool showCenterLogo;
  final String centerLabel;
  final bool showCenterLabel;
  final String semanticsLabel;
  final Color? centerBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AurumLoader(
        size: size,
        strokeWidth: strokeWidth,
        color: color,
        centerLogoAsset: centerLogoAsset,
        showCenterLogo: showCenterLogo,
        centerLabel: centerLabel,
        showCenterLabel: showCenterLabel,
        semanticsLabel: semanticsLabel,
        centerBackgroundColor: centerBackgroundColor,
      ),
    );
  }
}

class _StaticRingPainter extends CustomPainter {
  _StaticRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.trackColor,
  });

  final Color color;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -1.1, 3.7, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _StaticRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor;
  }
}
