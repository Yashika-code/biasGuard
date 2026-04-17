import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = AuthService().currentUser;
    final uid = user?.uid ?? 'anonymous';
    final name = user?.displayName ?? 'Community Sentinel';
    final email = user?.email ?? 'anonymous_auditor@biasguard.ai';
    final initials = name.split(' ').map((e) => e[0]).take(2).join('').toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          TextButton.icon(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary,
                  child: Text(initials, style: const TextStyle(fontSize: 32, color: Colors.white)),
                ),
                const SizedBox(width: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(email, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        user?.isAnonymous == true ? 'Community Plan' : 'Enterprise Plan',
                        style: const TextStyle(color: AppColors.tertiary, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 64),
            Text('Account Statistics', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('scans')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return _buildStatCard(context, 'Total Audits Initiated', '$count');
                    },
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(child: _buildStatCard(context, 'Mitigation Rules Exported', '12')), // Placeholder for now
                const SizedBox(width: 24),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('direct_queries')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return _buildStatCard(context, 'Direct Mode Queries', '$count');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out of your session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().signOut();
      if (context.mounted) context.go('/login');
    }
  }

  Widget _buildStatCard(BuildContext context, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 16),
          Text(value, style: Theme.of(context).textTheme.headlineLarge),
        ],
      ),
    );
  }
}
