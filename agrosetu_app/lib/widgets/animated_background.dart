import 'dart:math';
import 'package:flutter/material.dart';

class Bubble {
  double x;
  double y;
  double size;
  double dx;
  double dy;
  Color color;
  double opacity;

  Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.dx,
    required this.dy,
    required this.color,
    this.opacity = 0.5,
  });
}

class AnimatedFarmBackground extends StatefulWidget {
  const AnimatedFarmBackground({super.key});

  @override
  State<AnimatedFarmBackground> createState() => _AnimatedFarmBackgroundState();
}

class _AnimatedFarmBackgroundState extends State<AnimatedFarmBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bubbleScale;
  late Animation<double> _sunRayScale;
  
  final List<Bubble> _bubbles = [];
  final Random _random = Random();
  final int _bubbleCount = 8;
  
  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // REMOVED: _logoReveal animation

    // Bubble scale animation (for bouncing bubbles only)
    _bubbleScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.9, end: 1.1), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 0.9), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    // Sun ray scale animation
    _sunRayScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 0.8), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Initialize bubbles
    _initializeBubbles();

    // Start continuous animation for bubbles
    _controller.addListener(() {
      _updateBubbles();
    });
  }

  void _initializeBubbles() {
    _bubbles.clear();
    for (int i = 0; i < _bubbleCount; i++) {
      _bubbles.add(Bubble(
        x: _random.nextDouble() * 300 + 50,
        y: _random.nextDouble() * 300 + 50,
        size: _random.nextDouble() * 40 + 20,
        dx: (_random.nextDouble() * 2 - 1) * 1.5,
        dy: (_random.nextDouble() * 2 - 1) * 1.5,
        color: _getRandomGreenColor(),
        opacity: _random.nextDouble() * 0.3 + 0.2,
      ));
    }
  }

  Color _getRandomGreenColor() {
    final greens = [
      const Color(0xFFC8E6C9),
      const Color(0xFFA5D6A7),
      const Color(0xFF81C784),
      const Color(0xFF66BB6A),
      const Color(0xFF4CAF50),
      const Color(0xFF43A047),
    ];
    return greens[_random.nextInt(greens.length)];
  }

  void _updateBubbles() {
    if (!mounted) return;

    final screenWidth = 400.0;
    final screenHeight = 800.0;

    for (var bubble in _bubbles) {
      bubble.x += bubble.dx;
      bubble.y += bubble.dy;

      if (bubble.x <= 0 || bubble.x >= screenWidth - bubble.size) {
        bubble.dx *= -1;
        bubble.x = bubble.x.clamp(0, screenWidth - bubble.size);
      }
      if (bubble.y <= 0 || bubble.y >= screenHeight - bubble.size) {
        bubble.dy *= -1;
        bubble.y = bubble.y.clamp(0, screenHeight - bubble.size);
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2E7D32).withValues(alpha: 0.9),
                const Color(0xFF1B5E20).withValues(alpha: 0.95),
                const Color(0xFF0D4112).withValues(alpha: 0.9),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Moving bubbles with bounce animation
              ..._buildMovingBubbles(),

              // Sun rays (bouncing) - centered where logo would be
              ..._buildGreenSunRays(screenWidth, screenHeight),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildMovingBubbles() {
    return _bubbles.map((bubble) {
      final scale = _bubbleScale.value;
      
      return Positioned(
        left: bubble.x,
        top: bubble.y,
        child: Opacity(
          opacity: bubble.opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: bubble.size,
              height: bubble.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    bubble.color.withValues(alpha: 0.9),
                    bubble.color.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: bubble.color.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildGreenSunRays(double screenWidth, double screenHeight) {
    final rays = <Widget>[];
    final rayCount = 12;
    final centerX = screenWidth / 2;
    final centerY = screenHeight * 0.25 + 70;

    for (int i = 0; i < rayCount; i++) {
      final angle = i * 2 * pi / rayCount;
      final rayOpacity = 0.4 + sin(_controller.value * 2 * pi + i) * 0.3;
      
      rays.add(
        Positioned(
          left: centerX,
          top: centerY,
          child: Transform.translate(
            offset: Offset(cos(angle) * 80, sin(angle) * 80),
            child: Transform.scale(
              scale: _sunRayScale.value,
              child: Transform.rotate(
                angle: angle,
                child: Opacity(
                  opacity: rayOpacity * 0.7, // Reduced opacity since no logo
                  child: Container(
                    width: 120,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4CAF50).withValues(alpha: 0.9),
                          const Color(0xFF81C784).withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return rays;
  }
}