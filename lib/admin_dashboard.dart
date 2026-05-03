import 'package:flutter/material.dart';
import 'supabase_service.dart';
import 'model/issue_model.dart';
import 'user_service.dart';
import 'app_theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final service = SupabaseService();
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  late final Stream<List<Issue>> _issuesStream;
  late final Stream<List<Map<String, dynamic>>> _usersStream;

  @override
  void initState() {
    super.initState();
    _issuesStream = service.issuesStream;
    _usersStream = service.usersStream;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openSearchDialog() async {
    _searchCtrl.text = _searchQuery;
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(hintText: 'Search by title, class, status, username, or email'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Clear')),
          ElevatedButton(onPressed: () => Navigator.pop(context, _searchCtrl.text.trim()), child: const Text('Search')),
        ],
      ),
    );

    if (result != null) {
      setState(() => _searchQuery = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? colorScheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? colorScheme.onSurface,
        elevation: 1,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.aquaBlue, AppColors.skyBlue],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SpotIt AI',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Admin Dashboard',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openSearchDialog,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.search, size: 20, color: Colors.blue[700]),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _searchQuery = ''),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(_searchQuery, style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Icon(Icons.close, size: 16, color: Colors.blue[700]),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),

          // Logout button
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
                  ],
                ),
              );
              if (confirm == true) {
                await UserService.clear();
                if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.logout, size: 20, color: Colors.red[400]),
            ),
          ),

          // Show currently logged-in admin name
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Row(
              children: [
                if (UserService.username != null) ...[
                  Text(
                    'Hi, ${UserService.username}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                  ),
                  const SizedBox(width: 8),
                ],
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue[50],
                  child: Text(
                    UserService.username != null && UserService.username!.isNotEmpty ? UserService.username![0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Administration',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage issues and users',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<List<Issue>>(
                stream: service.issuesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final issues = snapshot.data!;
                  if (issues.isEmpty) return const SizedBox.shrink();

                  final pending = issues.where((i) => i.status.toLowerCase() == 'pending').length;
                  final inProgress = issues.where((i) => i.status.toLowerCase() == 'in progress').length;
                  final resolved = issues.where((i) => i.status.toLowerCase() == 'resolved').length;

                  return Row(
                    children: [
                      Expanded(child: _buildStatCard(title: 'Pending', count: pending.toString(), color: Colors.orange, icon: Icons.pending_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard(title: 'In Progress', count: inProgress.toString(), color: Colors.blue, icon: Icons.build_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard(title: 'Resolved', count: resolved.toString(), color: Colors.green, icon: Icons.check_circle_rounded)),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Tabs
            TabBar(
              labelColor: AppColors.aquaBlue,
              unselectedLabelColor: AppColors.charcoal.withOpacity(0.7),
              indicatorColor: AppColors.aquaBlue,
              tabs: const [
                Tab(text: 'Issues'),
                Tab(text: 'Analytics'),
                Tab(text: 'Manage Students'),
              ],
            ),

            Expanded(
              child: TabBarView(
                children: [
                  // Issues Tab
                  _KeepAliveTab(
                    child: StreamBuilder<List<Issue>>(
                      stream: _issuesStream,
                      builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final issues = snapshot.data!;
                      if (issues.isEmpty) return const Center(child: Text('No issues'));

                      final q = _searchQuery.toLowerCase();
                      final filtered = q.isNotEmpty
                          ? issues.where((issue) {
                              return issue.title.toLowerCase().contains(q) ||
                                  issue.className.toLowerCase().contains(q) ||
                                  issue.severity.toLowerCase().contains(q) ||
                                  issue.status.toLowerCase().contains(q);
                            }).toList()
                          : issues;

                      filtered.sort((a, b) {
                        if (b.upvotes != a.upvotes) return b.upvotes.compareTo(a.upvotes);
                        return (b.reportedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.reportedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
                      });

                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final issue = filtered[i];
                          final key = issue.id ?? i.toString();
                          return _buildAdminIssueTile(issue, key);
                        },
                      );
                    },
                  ),
                  ),

                  // Analytics Tab — use one-time fetch (stream doesn't replay to new listeners)
                  _KeepAliveTab(
                    child: FutureBuilder<List<Issue>>(
                      future: service.fetchIssues(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final issues = snapshot.data!;
                        if (issues.isEmpty) {
                          return Center(child: Text('No issues yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)));
                        }

                        final Map<String, int> byClass = {};
                        for (final issue in issues) {
                          final key = issue.className.isNotEmpty ? issue.className : 'Other';
                          byClass[key] = (byClass[key] ?? 0) + 1;
                        }
                        final sorted = byClass.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                        final maxCount = sorted.isEmpty ? 1.0 : sorted.first.value.toDouble();

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text('Most Reported Issues',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            const SizedBox(height: 8),
                            Text('Issue types by report count', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                            const SizedBox(height: 20),
                            if (sorted.isEmpty)
                              const Center(child: Text('No issues reported yet'))
                            else
                              ...sorted.map((e) => _buildAnalyticsBar(e.key, e.value, maxCount)),
                          ],
                        );
                      },
                    ),
                  ),

                  // Manage Students Tab
                  _KeepAliveTab(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _usersStream,
                      builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final users = snapshot.data!;
                      if (users.isEmpty) return const Center(child: Text('No users registered'));

                      final q = _searchQuery.toLowerCase();
                      final filteredUsers = q.isNotEmpty
                          ? users.where((u) {
                              final name = (u['name'] ?? '').toString().toLowerCase();
                              final username = (u['username'] ?? '').toString().toLowerCase();
                              final email = (u['email'] ?? '').toString().toLowerCase();
                              return name.contains(q) || username.contains(q) || email.contains(q);
                            }).toList()
                          : users;

                      filteredUsers.sort((a, b) =>
                          (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));

                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, i) {
                          final u = filteredUsers[i];
                          final key = u['id'].toString();
                          return _buildUserTile(key, u);
                        },
                      );
                    },
                  ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsBar(String label, int count, double maxCount) {
    final width = maxCount > 0 ? (count / maxCount).clamp(0.1, 1.0) : 0.1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              Text('$count reports', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: width,
              minHeight: 24,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.aquaBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String count, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.grey[800]),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAdminIssueTile(Issue issue, String key) {
    Color statusColor;
    switch (issue.status.toLowerCase()) {
      case 'resolved':
        statusColor = Colors.green;
        break;
      case 'in progress':
        statusColor = Colors.blue;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    // Check if image is available; prefer detected image for admin thumbnail
    final hasOriginalImage = (issue.imageUrl != null && issue.imageUrl!.isNotEmpty);
    final hasDetectedImage = (issue.detectedImageUrl != null && issue.detectedImageUrl!.isNotEmpty);
    final hasBase64Image = (issue.imageBase64 != null && issue.imageBase64!.isNotEmpty);
    final hasImage = hasOriginalImage || hasDetectedImage || hasBase64Image;
    
    final thumbUrl = hasDetectedImage ? issue.detectedImageUrl! : issue.imageUrl;

    return InkWell(
      onTap: () => _showIssueImageDialog(issue),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.03),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                hasImage && thumbUrl != null && thumbUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          thumbUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.report_problem_rounded, color: statusColor),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.report_problem_rounded, color: statusColor),
                      ),
                // AI detection indicator badge
                if (hasDetectedImage)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          issue.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      if (hasDetectedImage)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'AI',
                            style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issue.className,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          issue.status,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: issue.status.toLowerCase(),
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'in progress', child: Text('In Progress')),
                          DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                        ],
                        onChanged: (val) async {
                          if (val == null) return;
                          await service.updateIssueStatus(key, val);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Issue status updated to $val')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.thumb_up_alt_outlined, size: 18, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Text(
                        '${issue.upvotes}',
                        style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.thumb_down_alt_outlined, size: 18, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Text(
                        '${issue.downvotes}',
                        style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Issue'),
                        content: const Text('Are you sure you want to delete this issue? This action cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await service.deleteIssue(key);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Issue deleted')),
                        );
                      }
                    }
                  },
                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showIssueImageDialog(Issue issue) {
    final hasOriginalImage = (issue.imageUrl != null && issue.imageUrl!.isNotEmpty);
    final hasDetectedImage = (issue.detectedImageUrl != null && issue.detectedImageUrl!.isNotEmpty);
    final hasBase64Image = (issue.imageBase64 != null && issue.imageBase64!.isNotEmpty);
    
    if (!hasOriginalImage && !hasDetectedImage && !hasBase64Image) return;

    // For admins, show both images if available, with detected image as primary
    final primaryImageUrl = hasDetectedImage ? issue.detectedImageUrl! : (issue.imageUrl ?? '');
    final showBothImages = hasDetectedImage && hasOriginalImage;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black87,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDetectedImage ? 'AI Annotated Image' : 'Issue Image',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                if (showBothImages)
                  Text(
                    'Swipe to see original image',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
            actions: [
              if (showBothImages)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'AI DETECTED',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: showBothImages
              ? PageView.builder(
                  itemCount: 2,
                  itemBuilder: (context, index) {
                    final imageUrl = index == 0 ? primaryImageUrl : issue.imageUrl!;
                    final isDetected = index == 0;
                    return InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5.0,
                      panEnabled: true,
                      child: Center(
                        child: Column(
                          children: [
                            Expanded(
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                          : null,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
                                ),
                              ),
                            ),
                            if (isDetected)
                              Container(
                                padding: const EdgeInsets.all(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome, color: Colors.green, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'AI Detection with Bounding Boxes',
                                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  panEnabled: true,
                  child: Center(
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.network(
                            primaryImageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                      : null,
                                  color: Colors.white,
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
                            ),
                          ),
                        ),
                        if (hasDetectedImage)
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, color: Colors.green, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI Detection with Bounding Boxes',
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildUserTile(String key, Map<dynamic, dynamic> data) {
    final role = (data['role'] ?? '').toString();
    final userType = (data['userType'] ?? '').toString();
    final name = (data['name'] ?? data['username'] ?? 'Unknown').toString();
    final username = (data['username'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.03), blurRadius: 8, spreadRadius: 1)],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[50],
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.blue)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(username, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
          if (userType.toLowerCase() == 'student' || role.toLowerCase() == 'student')
            IconButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Student'),
                    content: const Text('Are you sure you want to delete this student? This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await service.deleteUser(key);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student deleted')));
                }
              },
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(role, style: TextStyle(color: Colors.grey[600])),
            )
        ],
      ),
    );
  }
}

/// Keeps tab content alive when switching tabs so stream subscriptions
/// stay active and don't cause infinite loading when returning.
class _KeepAliveTab extends StatefulWidget {
  final Widget child;

  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
