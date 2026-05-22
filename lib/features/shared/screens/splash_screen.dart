import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Màn hình Splash hiện đại với gradient xanh dương,
/// hiệu ứng particle sáng, logo animate, tên app và tagline.
/// Logo xuất hiện ngay lập tức khi màn hình hiện ra.
class SplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const SplashScreen({super.key, this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ─── Animation Controllers ────────────────────────────────
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loaderController;
  late AnimationController _particleController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;

  // ─── Animations ───────────────────────────────────────────
  late Animation<double> _bgFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineFade;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _loaderFade;
  late Animation<double> _pulseAnimation;

  // Particles
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    // ── Background gradient fade (nhanh hơn vì logo cần hiện ngay) ──
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bgFade = CurvedAnimation(parent: _bgController, curve: Curves.easeOut);

    // ── Logo entrance (hiện ngay, không delay) ──
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutCubic,
    ));

    // ── Text entrance ──
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _titleFade = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));
    _taglineFade = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    // ── Loader ──
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loaderFade = CurvedAnimation(
      parent: _loaderController,
      curve: Curves.easeIn,
    );

    // ── Particles ──
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _particles = List.generate(25, (_) => _Particle.random());

    // ── Shimmer on logo ──
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // ── Pulse glow on logo ──
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── Orchestrate sequence ──
    _startSequence();
  }

  Future<void> _startSequence() async {
    // 1. Background + Logo hiện ngay cùng lúc
    _bgController.forward();
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 400));

    // 2. Text slides up
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 400));

    // 3. Loader appears
    _loaderController.forward();

    // 4. Đợi đủ 2.5s tổng cộng rồi callback
    await Future.delayed(const Duration(milliseconds: 1700));
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _loaderController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Đặt nền navy đậm giống native splash để tránh flash trắng
      backgroundColor: AppColors.primaryDark,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgFade,
          _particleController,
          _pulseAnimation,
        ]),
        builder: (context, child) {
          return Stack(
            children: [
              // ── Gradient Background ──
              _buildBackground(),

              // ── Floating Particles ──
              ..._buildParticles(),

              // ── Main Content ──
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // ── Logo with shimmer + pulse glow ──
                    _buildAnimatedLogo(),

                    const SizedBox(height: 32),

                    // ── App Name ──
                    _buildTitle(),

                    const SizedBox(height: 10),

                    // ── Tagline ──
                    _buildTagline(),

                    const Spacer(flex: 2),

                    // ── Loading indicator ──
                    _buildLoader(),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Background
  // ════════════════════════════════════════════════════════════
  Widget _buildBackground() {
    return FadeTransition(
      opacity: _bgFade,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.splashGradient,
            stops: [0.0, 0.3, 0.6, 0.85, 1.0],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Floating Particles
  // ════════════════════════════════════════════════════════════
  List<Widget> _buildParticles() {
    return _particles.map((p) {
      final t = (_particleController.value + p.offset) % 1.0;
      final y = 1.0 - t * p.speed;
      final x = p.x + sin(t * 2 * pi * p.waveCycles) * p.waveAmp;
      final opacity = (sin(t * pi) * p.maxOpacity).clamp(0.0, 1.0);

      return Positioned(
        left: MediaQuery.of(context).size.width * x,
        top: MediaQuery.of(context).size.height * y,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: p.size,
            height: p.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.4),
                  blurRadius: p.size * 2,
                  spreadRadius: p.size * 0.5,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  // ════════════════════════════════════════════════════════════
  // Logo
  // ════════════════════════════════════════════════════════════
  Widget _buildAnimatedLogo() {
    return SlideTransition(
      position: _logoSlide,
      child: FadeTransition(
        opacity: _logoFade,
        child: ScaleTransition(
          scale: _logoScale,
          child: AnimatedBuilder(
            animation: Listenable.merge([_shimmerController, _pulseAnimation]),
            builder: (context, child) {
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLight.withValues(alpha: _pulseAnimation.value),
                      blurRadius: 40,
                      spreadRadius: 4,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Logo image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'lib/data/images/Logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Shimmer overlay
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          final shimmerPos =
                              _shimmerController.value * 2.0 - 0.5;
                          return LinearGradient(
                            begin: Alignment(-1.0 + shimmerPos * 3, -0.3),
                            end: Alignment(1.0 + shimmerPos * 3, 0.3),
                            colors: const [
                              Color(0x00FFFFFF),
                              Color(0x33FFFFFF),
                              Color(0x00FFFFFF),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcATop,
                        child: Container(
                          width: 140,
                          height: 140,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Title
  // ════════════════════════════════════════════════════════════
  Widget _buildTitle() {
    return SlideTransition(
      position: _titleSlide,
      child: FadeTransition(
        opacity: _titleFade,
        child: const Text(
          'VGo',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: Color(0x55000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Tagline
  // ════════════════════════════════════════════════════════════
  Widget _buildTagline() {
    return SlideTransition(
      position: _taglineSlide,
      child: FadeTransition(
        opacity: _taglineFade,
        child: const Text(
          'Học mọi lúc, vui mọi nơi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Loader
  // ════════════════════════════════════════════════════════════
  Widget _buildLoader() {
    return FadeTransition(
      opacity: _loaderFade,
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: Colors.white.withValues(alpha: 0.7),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Đang tải...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Particle Model
// ════════════════════════════════════════════════════════════════
class _Particle {
  final double x;
  final double offset;
  final double speed;
  final double size;
  final double maxOpacity;
  final double waveAmp;
  final double waveCycles;

  const _Particle({
    required this.x,
    required this.offset,
    required this.speed,
    required this.size,
    required this.maxOpacity,
    required this.waveAmp,
    required this.waveCycles,
  });

  factory _Particle.random() {
    final rng = Random();
    return _Particle(
      x: rng.nextDouble(),
      offset: rng.nextDouble(),
      speed: 0.6 + rng.nextDouble() * 0.6,
      size: 2 + rng.nextDouble() * 4,
      maxOpacity: 0.15 + rng.nextDouble() * 0.35,
      waveAmp: 0.01 + rng.nextDouble() * 0.03,
      waveCycles: 1 + rng.nextDouble() * 2,
    );
  }
}
