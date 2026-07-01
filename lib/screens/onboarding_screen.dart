import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../services/app_theme.dart';
import 'turbo_dashboard_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TURBOGET ONBOARDING - World Class Design
/// Designed by Olatunji Ayobami Ayanlowo +2347038193753
/// ═══════════════════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _buttonController;
  late Animation<double> _buttonAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: '🚀 Turbo Speed',
      subtitle: 'Lightning Fast Downloads',
      description:
          'Experience download speeds up to 10x faster with our multi-connection technology. Download large files in seconds, not minutes.',
      icon: Icons.bolt_rounded,
      gradient: const [Color(0xFF0066FF), Color(0xFF8B5CF6)],
      particles: ['⚡', '🔥', '⚡', '✨', '🔥'],
    ),
    OnboardingPage(
      title: '☁️ Cloud Sync',
      subtitle: 'Access Anywhere',
      description:
          'Your downloads sync across all your devices. Start a download on your phone, finish it on your laptop. Seamless experience guaranteed.',
      icon: Icons.cloud_sync_rounded,
      gradient: const [Color(0xFF00D9FF), Color(0xFF0066FF)],
      particles: ['☁️', '📱', '💻', '☁️', '🔄'],
    ),
    OnboardingPage(
      title: '📋 Smart Queue',
      subtitle: 'Intelligent Management',
      description:
          'Queue multiple downloads and let our AI prioritize them. Set schedules, bandwidth limits, and pause/resume anytime.',
      icon: Icons.auto_awesome_rounded,
      gradient: const [Color(0xFF8B5CF6), Color(0xFFFF006E)],
      particles: ['🎯', '📊', '🎯', '⚡', '📋'],
    ),
    OnboardingPage(
      title: '🔒 Secure & Private',
      subtitle: 'Your Data is Safe',
      description:
          'End-to-end encryption for all downloads. Automatic virus scanning. Zero tracking. Your privacy is our priority.',
      icon: Icons.security_rounded,
      gradient: const [Color(0xFF10B981), Color(0xFF059669)],
      particles: ['🔒', '🛡️', '🔐', '🛡️', '🔒'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _buttonAnimation = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOut,
    );
    _buttonController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _goToHome();
    }
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const TurboDashboard();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip Button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextButton(
                    onPressed: _goToHome,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Page Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),

              // Page Indicators
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => _buildIndicator(index == _currentPage),
                  ),
                ),
              ),

              // Navigation Button
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                child: ScaleTransition(
                  scale: _buttonAnimation,
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == _pages.length - 1
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Floating Particles
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow Background
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.gradient[0].withOpacity(0.3),
                      page.gradient[1].withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              
              // Icon Container
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: page.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: page.gradient[0].withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  page.icon,
                  size: 100,
                  color: Colors.white,
                ),
              ),
              
              // Floating particles
              ...List.generate(page.particles.length, (index) {
                final angle = (index / page.particles.length) * 3.14159 * 2;
                return Positioned(
                  left: 125 + 140 * math.cos(angle),
                  top: 125 + 140 * math.sin(angle),
                  child: Text(
                    page.particles[index],
                    style: const TextStyle(fontSize: 24),
                  ),
                );
              }),
            ],
          ),
          
          const SizedBox(height: 60),
          
          // Title
          ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(colors: page.gradient).createShader(bounds);
            },
            child: Text(
              page.title,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: page.gradient[0],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        gradient: isActive
            ? AppTheme.turboGradient
            : null,
        color: isActive ? null : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final List<String> particles;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.particles,
  });
}
