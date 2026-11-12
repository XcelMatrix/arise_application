import 'package:flutter/material.dart';

/// The blue ARISE logo, softly flashing. Used wherever the app is loading.
class FlashingLogo extends StatefulWidget {
  const FlashingLogo({super.key, this.size = 72, this.color = const Color(0xFF3C6E87)});

  final double size;
  final Color color;

  @override
  State<FlashingLogo> createState() => _FlashingLogoState();
}

class _FlashingLogoState extends State<FlashingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.25, end: 1.0)
            .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
          child: Image.asset(
            'assets/icons/icon_white.png',
            width: widget.size,
            height: widget.size,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.shield_outlined, size: widget.size, color: widget.color),
          ),
        ),
      ),
    );
  }
}
