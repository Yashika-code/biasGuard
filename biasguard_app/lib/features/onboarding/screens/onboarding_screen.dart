import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      title: 'Structural Fairness',
      subtitle: 'BiasGuard scans your datasets for hidden structural biases that human eyes might miss.',
      icon: Icons.analytics_outlined,
      color: AppColors.primaryContainer,
    ),
    _OnboardingData(
      title: 'Explainable AI',
      subtitle: 'Our Gemini-powered engine explains root causes in plain language, helping you make better decisions.',
      icon: Icons.auto_awesome_outlined,
      color: AppColors.gradientStart,
    ),
    _OnboardingData(
      title: 'Direct Mitigation',
      subtitle: 'Don\'t just audit — fix bias in real-time with our interactive counterfactual simulators.',
      icon: Icons.shield_outlined,
      color: AppColors.tertiary,
    ),
  ];

  void _onFinish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemCount: _pages.length,
            itemBuilder: (context, idx) {
              final page = _pages[idx];
              return Padding(
                padding: const EdgeInsets.all(64.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: page.color.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: page.color.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(page.icon, size: 100, color: page.color),
                    ),
                    const SizedBox(height: 64),
                    Text(
                      page.title,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Text(
                        page.subtitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Bottom Navigation
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (idx) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == idx ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentPage == idx ? AppColors.primary : AppColors.outlineVariant,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _onFinish,
                          child: const Text('SKIP'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_currentPage == _pages.length - 1) {
                              _onFinish();
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_currentPage == _pages.length - 1 ? 'GET STARTED' : 'NEXT'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _OnboardingData({required this.title, required this.subtitle, required this.icon, required this.color});
}
