import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'model/issue_model.dart';

class TrackIssuesPage extends StatelessWidget {
  const TrackIssuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirebaseService();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? colorScheme.surface,
        title: Text(
          'Track Issues',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.appBarTheme.foregroundColor ?? Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campus Issues',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Overview of active, resolved and in‑progress issues',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StreamBuilder(
              stream: service.getIssues().onValue.asBroadcastStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const _LoadingStatsRow();
                }

                final event = snapshot.data;
                final value = event!.snapshot.value;
                if (value == null) {
                  return const _EmptyStatsRow();
                }

                final Map<dynamic, dynamic> map =
                    value as Map<dynamic, dynamic>;
                final issues = map.entries
                    .map((e) =>
                        Issue.fromJson(Map<dynamic, dynamic>.from(e.value)))
                    .toList();

                final activeIssues = issues
                    .where(
                        (issue) => issue.status.toLowerCase() == 'pending')
                    .length;
                final resolvedIssues = issues
                    .where(
                        (issue) => issue.status.toLowerCase() == 'resolved')
                    .length;
                final inProgressIssues = issues
                    .where((issue) =>
                        issue.status.toLowerCase() == 'in progress')
                    .length;

                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Active Issues',
                        count: activeIssues.toString(),
                        color: Colors.orange,
                        icon: Icons.warning_amber_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Resolved',
                        count: resolvedIssues.toString(),
                        color: Colors.green,
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'In Progress',
                        count: inProgressIssues.toString(),
                        color: Colors.blue,
                        icon: Icons.build_rounded,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                count,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingStatsRow extends StatelessWidget {
  const _LoadingStatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ShimmerBox()),
        const SizedBox(width: 12),
        Expanded(child: _ShimmerBox()),
        const SizedBox(width: 12),
        Expanded(child: _ShimmerBox()),
      ],
    );
  }
}

class _EmptyStatsRow extends StatelessWidget {
  const _EmptyStatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(title: 'Active Issues', count: '0', color: Colors.grey, icon: Icons.warning_amber_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(title: 'Resolved', count: '0', color: Colors.grey, icon: Icons.check_circle_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(title: 'In Progress', count: '0', color: Colors.grey, icon: Icons.build_rounded)),
      ],
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
