// BiasGuard — App Router (go_router)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/audit/screens/audit_screen.dart';
import '../../features/audit/screens/processing_screen.dart';
import '../../features/results/screens/results_screen.dart';
import '../../features/direct_mode/screens/direct_mode_screen.dart';
import '../../features/counterfactual/screens/counterfactual_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/report/screens/report_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/about/screens/about_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/settings/screens/privacy_policy_screen.dart';
import '../../features/settings/screens/terms_screen.dart';

class AppRoutes {
  static const login        = '/login';
  static const dashboard    = '/dashboard';
  static const audit        = '/audit';
  static const processing   = '/processing';
  static const results      = '/results';
  static const directMode   = '/direct-mode';
  static const counterfactual = '/counterfactual';
  static const history      = '/history';
  static const report       = '/report';
  static const settings     = '/settings';
  static const profile      = '/profile';
  static const about        = '/about';
  static const onboarding   = '/onboarding';
  static const privacy      = '/settings/privacy';
  static const terms        = '/settings/terms';
}

final onboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final onboardingComplete = ref.watch(onboardingProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: (context, state) {
      if (onboardingComplete.isLoading) return null;
      
      final completed = onboardingComplete.value ?? false;
      final isGoingToOnboarding = state.matchedLocation == AppRoutes.onboarding;

      if (!completed && !isGoingToOnboarding) {
        return AppRoutes.onboarding;
      }
      
      // If completed and trying to go back to onboarding, redirect to home
      if (completed && isGoingToOnboarding) {
        return AppRoutes.dashboard;
      }

      if (state.uri.toString() == '/' || state.uri.toString() == '') {
        return AppRoutes.dashboard;
      }
      return null;
    },
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.audit,
            name: 'audit',
            builder: (context, state) => const AuditScreen(),
          ),
          GoRoute(
            path: AppRoutes.processing,
            name: 'processing',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ProcessingScreen(
                fileName: extra?['fileName'] ?? 'Dataset',
                scanId: extra?['scanId'] ?? '',
                csvData: extra?['csvData'], // Pass CSV string
                isDemo: extra?['isDemo'] ?? false,
                useCase: extra?['useCase'],
              );
            },
          ),
          GoRoute(
            path: AppRoutes.results,
            name: 'results',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ResultsScreen(
                scanId: extra?['scanId'] ?? '',
                scanData: extra?['scanData'],
              );
            },
          ),
          GoRoute(
            path: AppRoutes.directMode,
            name: 'direct-mode',
            builder: (context, state) => const DirectModeScreen(),
          ),
          GoRoute(
            path: AppRoutes.counterfactual,
            name: 'counterfactual',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return CounterfactualScreen(scanId: extra?['scanId'] ?? '');
            },
          ),
          GoRoute(
            path: AppRoutes.history,
            name: 'history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.report,
            name: 'report',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ReportScreen(scanId: extra?['scanId'] ?? '');
            },
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.privacy,
            builder: (context, state) => const PrivacyPolicyScreen(),
          ),
          GoRoute(
            path: AppRoutes.terms,
            builder: (context, state) => const TermsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,

            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.about,
            name: 'about',
            builder: (context, state) => const AboutScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

/// Side-nav shell that wraps all authenticated screens
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const _SideNav(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav();

  @override
  Widget build(BuildContext context) {
    final route = GoRouterState.of(context).uri.toString();
    return Container(
      width: 72,
      color: const Color(0xFF1B1B24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.balance, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 32),
          const Divider(height: 1, color: Color(0xFF2A2A45)),
          const SizedBox(height: 16),
          _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard',
              route: AppRoutes.dashboard, current: route),
          _NavItem(icon: Icons.upload_file_outlined, label: 'Audit',
              route: AppRoutes.audit, current: route),
          _NavItem(icon: Icons.psychology_outlined, label: 'Direct',
              route: AppRoutes.directMode, current: route),
          _NavItem(icon: Icons.history_outlined, label: 'History',
              route: AppRoutes.history, current: route),
          const Spacer(),
          _NavItem(icon: Icons.settings_outlined, label: 'Settings',
              route: AppRoutes.settings, current: route),
          _NavItem(icon: Icons.info_outline, label: 'About',
              route: AppRoutes.about, current: route),
          const Divider(height: 32, color: Color(0xFF2A2A45)),
          ListTile(
            dense: true,
            leading: Icon(Icons.logout, color: AppColors.error, size: 20),
            title: Text('Sign Out', style: TextStyle(color: AppColors.error, fontSize: 13)),
            onTap: () async {
              await AuthService().signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String current;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current.startsWith(route);
    return Semantics(
      label: 'Navigation to $label',
      button: true,
      enabled: true,
      child: Tooltip(
        message: label,
        preferBelow: false,
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              gradient: isActive
                  ? const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive
                  ? Colors.white
                  : const Color(0xFF908FA0),
            ),
          ),
        ),
      ),
    );
  }
}
