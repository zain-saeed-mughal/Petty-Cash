import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'adaptive_scaffold.dart';

class CurvedNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigationIndexChanged;
  final List<NavigationItem> destinations;

  const CurvedNavBar({
    super.key,
    required this.currentIndex,
    required this.onNavigationIndexChanged,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox();

    const activePurple = Color(0xFF7C3AED);
    const inactiveIconColor = Color(0xFF94A3B8);
    const inactiveTextColor = Color(0xFF64748B);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 86,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: currentIndex.toDouble()),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Curved upward background (Active Bubble shape)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BulgePainter(
                        selectedIndex: value,
                        itemCount: destinations.length,
                        fillColor: barBgColor,
                        isDark: isDark,
                        isRtl: isRtl,
                      ),
                    ),
                  ),

                  // Navigation Items
                  Positioned.fill(
                    child: Row(
                      children: List.generate(destinations.length, (index) {
                        final diff = (value - index).abs();
                        final activeProgress = (1.0 - diff).clamp(0.0, 1.0);
                        final isSelected = index == currentIndex;
                        final d = destinations[index];

                        final iconColor = Color.lerp(
                          inactiveIconColor,
                          Colors.white,
                          activeProgress,
                        )!;

                        final textColor = Color.lerp(
                          inactiveTextColor,
                          activePurple,
                          activeProgress,
                        )!;

                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onNavigationIndexChanged(index),
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                // Bottom Label with FittedBox to prevent any text overflow
                                Positioned(
                                  bottom: 8,
                                  left: 2,
                                  right: 2,
                                  height: 16,
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        d.label,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Active Purple Bubble / Inactive Icon
                                Positioned(
                                  top: 10.0 + (1.0 - activeProgress) * 11.0,
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: activePurple.withValues(
                                        alpha: activeProgress,
                                      ),
                                      boxShadow: activeProgress > 0.1
                                          ? [
                                              BoxShadow(
                                                color: activePurple.withValues(
                                                  alpha: 0.35 * activeProgress,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: d.badgeCount != null &&
                                              d.badgeCount! > 0
                                          ? Badge(
                                              label: Text('${d.badgeCount}'),
                                              backgroundColor:
                                                  const Color(0xFFEF4444),
                                              child: Icon(
                                                isSelected
                                                    ? d.selectedIcon
                                                    : d.icon,
                                                color: iconColor,
                                                size: 24,
                                              ),
                                            )
                                          : Icon(
                                              isSelected
                                                  ? d.selectedIcon
                                                  : d.icon,
                                              color: iconColor,
                                              size: 24,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BulgePainter extends CustomPainter {
  final double selectedIndex;
  final int itemCount;
  final Color fillColor;
  final bool isDark;
  final bool isRtl;

  _BulgePainter({
    required this.selectedIndex,
    required this.itemCount,
    required this.fillColor,
    required this.isDark,
    required this.isRtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final itemWidth = size.width / itemCount;
    final visualIndex = isRtl ? (itemCount - 1 - selectedIndex) : selectedIndex;
    final centerX = (visualIndex + 0.5) * itemWidth;

    const cornerRadius = 24.0;
    const flatTopY = 24.0;
    const bulgePeakY = 4.0;
    const bulgeRadius = 46.0;

    // Smooth Gaussian/Cosine bell curve for upward active bubble bulge
    double getY(double x) {
      final d = (x - centerX).abs();
      if (d >= bulgeRadius) return flatTopY;
      final t = d / bulgeRadius;
      final factor = 0.5 * (1.0 + math.cos(t * math.pi));
      return flatTopY - (flatTopY - bulgePeakY) * factor;
    }

    final path = Path();

    // Start at bottom-left corner
    path.moveTo(0, size.height - cornerRadius);

    // Left edge up to top-left corner
    path.lineTo(0, getY(0) + cornerRadius);
    path.quadraticBezierTo(0, getY(0), cornerRadius, getY(cornerRadius));

    // Across the top edge following the upward bulge wave
    const step = 3.0;
    for (double x = cornerRadius + step; x < size.width - cornerRadius; x += step) {
      path.lineTo(x, getY(x));
    }

    // Top-right corner
    path.lineTo(size.width - cornerRadius, getY(size.width - cornerRadius));
    path.quadraticBezierTo(
      size.width,
      getY(size.width),
      size.width,
      getY(size.width) + cornerRadius,
    );

    // Down to bottom-right corner
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(size.width, size.height, size.width - cornerRadius, size.height);

    // Across bottom edge
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);

    path.close();

    // Drop shadow
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(
      path,
      Paint()
        ..color = isDark
            ? Colors.black.withValues(alpha: 0.35)
            : const Color(0x18000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.restore();

    // Background fill
    canvas.drawPath(
      path,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    // Subtle outline border
    canvas.drawPath(
      path,
      Paint()
        ..color = isDark
            ? const Color(0xFF334155).withValues(alpha: 0.6)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _BulgePainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.itemCount != itemCount ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isRtl != isRtl;
  }
}
