import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/auth_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final isHindi = ref.watch(localeProvider.notifier).isHindi;
    final uid = AuthService().currentUid ?? 'anonymous';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───────────────────────────────────
            _buildHeader(context, isHindi),
            const SizedBox(height: 48),

            // ─── Quick Action Buttons ─────────────────────
            _buildQuickActions(context, isHindi),
            const SizedBox(height: 48),

            // ─── Metric Cards Row ─────────────────────────
            _buildMetricCards(context, uid),
            const SizedBox(height: 32),

            // ─── Two Column: Chart + Heartbeat ────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildAuditMomentum(context),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _buildEngineHeartbeat(context),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ─── Audit Log ────────────────────────────────
            _buildSecurityLog(context, uid),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isHindi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, AppColors.tertiary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
          child: Text(
            isHindi ? 'प्रहरी' : 'The Sentinel',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isHindi ? 'सर्वोच्च बुद्धिमत्ता' : 'Sovereign Intelligence',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isHindi) {
    return Row(
      children: [
        _GradientActionButton(
          icon: Icons.upload_file,
          label: isHindi ? 'ऑडिट मोड' : 'Audit Mode',
          onTap: () => context.go('/audit'),
        ),
        const SizedBox(width: 16),
        _GradientActionButton(
          icon: Icons.psychology,
          label: isHindi ? 'डायरेक्ट मोड' : 'Direct Mode',
          onTap: () => context.go('/direct-mode'),
          isOutlined: true,
        ),
        const Spacer(),
        // Language Toggle
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _buildLangBtn('EN', !isHindi),
              _buildLangBtn('HI', isHindi),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLangBtn(String label, bool active) {
    return GestureDetector(
      onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCards(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('scans')
          .snapshots(),
      builder: (context, snapshot) {
        final totalAudits = snapshot.hasData ? snapshot.data!.docs.length : 0;

        // Calculate average equity score
        double avgScore = 0;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          double sum = 0;
          int count = 0;
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final metrics = data['metrics'] as Map<String, dynamic>?;
            if (metrics != null && metrics['equity_score'] != null) {
              sum += (metrics['equity_score'] as num).toDouble();
              count++;
            }
          }
          if (count > 0) avgScore = sum / count;
        }

        return Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.query_stats,
                iconColor: AppColors.primary,
                title: 'Total Audits Performed',
                value: '$totalAudits',
                subtitle: null,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _MetricCard(
                icon: Icons.verified_user,
                iconColor: AppColors.tertiary,
                title: 'Average Equity Score',
                value: avgScore > 0 ? '${avgScore.toInt()}%' : '—',
                subtitle: avgScore > 70 ? 'Within fair threshold' : (avgScore > 0 ? 'Below fair threshold' : null),
                subtitleColor: avgScore > 70 ? AppColors.tertiary : AppColors.moderateAmber,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _MetricCard(
                icon: Icons.shield,
                iconColor: AppColors.moderateAmber,
                title: 'Active Bias Mitigation',
                value: '3/4',
                subtitle: 'Engines currently suppressing proxies',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAuditMomentum(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audit Momentum',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'System performance over the last 30 days',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 20,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['W1', 'W2', 'W3', 'W4'];
                        if (value.toInt() >= 0 && value.toInt() < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[value.toInt()],
                              style: const TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, 8, 5),
                  _makeBarGroup(1, 12, 7),
                  _makeBarGroup(2, 15, 4),
                  _makeBarGroup(3, 10, 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y1, double y2) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y1,
          gradient: const LinearGradient(
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        BarChartRodData(
          toY: y2,
          color: AppColors.surfaceContainerHighest,
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _buildEngineHeartbeat(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engine Heartbeat',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 32),
          _HeartbeatRow(
            label: 'Neural Engine',
            status: 'Lat: 12ms',
            color: AppColors.tertiary,
          ),
          const SizedBox(height: 24),
          _HeartbeatRow(
            label: 'Gemini Analysis',
            status: 'Sync: Stable',
            color: AppColors.tertiary,
          ),
          const SizedBox(height: 24),
          _HeartbeatRow(
            label: 'Data Privacy Layer',
            status: 'Zero Leakage',
            color: AppColors.tertiary,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: AppColors.tertiary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All systems are currently running within optimal tolerance. No critical drift detected in the last 6 hours.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.5,
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

  Widget _buildSecurityLog(BuildContext context, String uid) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security & Audit Log',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('scans')
                .orderBy('created_at', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No recent audit activity.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                    ),
                  ),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['dataset_name'] ?? 'Untitled Scan';
                  final status = data['status'] ?? 'processing';
                  final severity = (data['severity'] as String?)?.toUpperCase() ?? 'PENDING';

                  IconData icon;
                  Color iconColor;
                  String subtitle;

                  if (status == 'analysis_complete') {
                    icon = Icons.assignment_turned_in;
                    iconColor = AppColors.tertiary;
                    subtitle = 'Report Generated — Severity: $severity';
                  } else {
                    icon = Icons.play_circle_outline;
                    iconColor = AppColors.primary;
                    subtitle = 'Audit in progress';
                  }

                  return _LogEntry(
                    icon: icon,
                    iconColor: iconColor,
                    title: name,
                    subtitle: subtitle,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Subcomponents ──────────────────────────────────────────────

class _GradientActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isOutlined;

  const _GradientActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: isOutlined
                ? null
                : const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
            color: isOutlined ? Colors.transparent : null,
            border: isOutlined
                ? Border.all(color: AppColors.outlineVariant)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isOutlined ? AppColors.onSurface : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isOutlined ? AppColors.onSurface : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;
  final Color? subtitleColor;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: subtitleColor ?? AppColors.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeartbeatRow extends StatelessWidget {
  final String label;
  final String status;
  final Color color;

  const _HeartbeatRow({
    required this.label,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _LogEntry extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _LogEntry({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
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
