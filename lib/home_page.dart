import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';
import 'model/issue_model.dart';
import 'package:geolocator/geolocator.dart';
import 'user_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final service = FirebaseService();
  Position? _currentPosition;
  bool _nearbyOnly = true;
  double _radiusMeters = 1000; // default radius
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        // permission denied; user can enable from settings
        setState(() {});
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      setState(() => _currentPosition = pos);
    } catch (e) {
      print('Location init error: $e');
    }
  }

  void _toggleNearby() {
    setState(() => _nearbyOnly = !_nearbyOnly);
  }

  void _pickRadius() async {
    final selected = await showDialog<double>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Select radius'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 100.0), child: const Text('100 m')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 500.0), child: const Text('500 m')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 1000.0), child: const Text('1 km')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 2000.0), child: const Text('2 km')),
        ],
      ),
    );
    if (selected != null) setState(() => _radiusMeters = selected);
  }

  Future<void> _openSearchDialog() async {
    final controller = TextEditingController(text: _searchQuery);
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search issues'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Search by title or class'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Clear')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Search')),
        ],
      ),
    );

    if (result != null) setState(() => _searchQuery = result);
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spot It',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.appBarTheme.foregroundColor ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Student Dashboard',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      color: (theme.appBarTheme.foregroundColor ?? Colors.white).withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _toggleNearby,
            tooltip: _nearbyOnly ? 'Showing nearby only' : 'Showing all issues',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _nearbyOnly ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.location_on_outlined, size: 20, color: _nearbyOnly ? Colors.green[700] : Colors.grey[700]),
            ),
          ),
          IconButton(
            onPressed: _pickRadius,
            tooltip: 'Radius: ${(_radiusMeters >= 1000) ? '${(_radiusMeters/1000).toStringAsFixed(1)} km' : '${_radiusMeters.toInt()} m'}',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.tune, size: 20, color: Colors.blue[700]),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/report'),
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.add_rounded, size: 24),
          label: const Text(
            "Report Issue",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Issues List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StreamBuilder(
                  stream: service.getIssues().onValue.asBroadcastStream(),
                  builder: (context, snapshot) {
                    int totalIssues = 0;
                    if (snapshot.hasData) {
                      final event = snapshot.data;
                      final value = event!.snapshot.value;
                      if (value != null) {
                        final Map<dynamic, dynamic> map = value as Map<dynamic, dynamic>;
                        totalIssues = map.length;
                      }
                    }
                    
                    return Text(
                      'Recent Issues ($totalIssues)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    if (_searchQuery.isNotEmpty) 
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              _searchQuery,
                              style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(onTap: () => setState(() => _searchQuery = ''), child: const Icon(Icons.close, size: 16, color: Colors.blue)),
                          ],
                        ),
                      ),
                    IconButton(
                      onPressed: _openSearchDialog,
                      tooltip: 'Search issues',
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.search, size: 20, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Issues List
          Expanded(
            child: StreamBuilder(
              stream: service.getIssues().onValue.asBroadcastStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.blue[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Loading issues...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final event = snapshot.data;
                final value = event!.snapshot.value;
                if (value == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.report_problem_outlined,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Issues Reported',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to report a campus issue',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                final Map<dynamic, dynamic> map = value as Map<dynamic, dynamic>;
                // Build list of items with keys so we can update votes
                final items = map.entries
                    .map((e) => {
                          'key': e.key.toString(),
                          'issue': Issue.fromJson(Map<dynamic, dynamic>.from(e.value)),
                        })
                    .toList();

                // Optionally filter by proximity and search query
                final filtered = items.where((it) {
                  final issue = it['issue'] as Issue;
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matches = (issue.title.toLowerCase().contains(q) || issue.className.toLowerCase().contains(q));
                    if (!matches) return false;
                  }
                  if (!_nearbyOnly || _currentPosition == null) return true;
                  final dist = Geolocator.distanceBetween(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    issue.latitude,
                    issue.longitude,
                  );
                  return dist <= _radiusMeters;
                }).toList();

                // Sort by priority: primary = upvotes descending (highest first), secondary = reportedAt descending
                // Sort so latest posted issues come first
                filtered.sort((a, b) {
                  final A = a['issue'] as Issue;
                  final B = b['issue'] as Issue;
                  final aTime = A.reportedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime = B.reportedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final it = filtered[i];
                      final issue = it['issue'] as Issue;
                      final key = it['key'] as String;
                      return _buildIssueCard(issue, key, context);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStats() {
    return Row(
      children: [
        Expanded(child: _buildStatCardSkeleton()),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCardSkeleton()),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCardSkeleton()),
      ],
    );
  }

  Widget _buildStatCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 30,
            height: 24,
            color: Colors.grey[200],
            margin: const EdgeInsets.only(bottom: 4),
          ),
          Container(
            width: 60,
            height: 14,
            color: Colors.grey[100],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Active Issues',
            count: '0',
            color: Colors.grey,
            icon: Icons.warning_amber_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Resolved',
            count: '0',
            color: Colors.grey,
            icon: Icons.check_circle_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'In Progress',
            count: '0',
            color: Colors.grey,
            icon: Icons.build_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: theme.drawerTheme.backgroundColor ?? theme.colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer Header
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              ),
            ),
            child: SafeArea(
              top: true,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    const Text('Student Dashboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Welcome back!', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                    const SizedBox(height: 4),
                    if (UserService.username != null)
                      Text(UserService.username!, style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          
          // Menu Items — same full menu for all logged-in users
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                _buildDrawerItem(
                  context: context,
                  icon: Icons.dashboard_rounded,
                  title: 'Dashboard',
                  isSelected: true,
                  onTap: () {},
                ),
                if (UserService.role?.toLowerCase() == 'admin')
                  _buildDrawerItem(
                  context: context,
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Admin',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin');
                    },
                  ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.report_problem_rounded,
                  title: 'My Reports',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/my-reports');
                  },
                ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.track_changes_rounded,
                    title: 'Track Issues',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/track-issues');
                    },
                  ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.announcement_rounded,
                  title: 'Announcements',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.schedule_rounded,
                  title: 'Schedule',
                  onTap: () {},
                ),
                Divider(color: theme.colorScheme.outline.withOpacity(0.3), height: 24),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.help_rounded,
                  title: 'Help & Support',
                  onTap: () {},
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  color: Colors.red,
                  onTap: () async {
                    Navigator.pop(context);
                    await UserService.clear();
                    if (context.mounted) Navigator.pushReplacementNamed(context, '/');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    Color? color,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurfaceVariant;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.15) : (theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? theme.colorScheme.primary : effectiveColor,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(Issue issue, String key, BuildContext context) {
    // Determine status color
    Color statusColor;
    IconData statusIcon;
    
    switch (issue.status.toLowerCase()) {
      case 'resolved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'in progress':
        statusColor = Colors.blue;
        statusIcon = Icons.build_rounded;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.error_rounded;
    }

    // Determine severity color
    Color severityColor;
    switch (issue.severity.toLowerCase()) {
      case 'high':
        severityColor = Colors.red;
        break;
      case 'medium':
        severityColor = Colors.orange;
        break;
      case 'low':
        severityColor = Colors.green;
        break;
      default:
        severityColor = Colors.grey;
    }

    // Format date if available
    String timeAgo = '';
    if (issue.reportedAt != null) {
      final now = DateTime.now();
      final difference = now.difference(issue.reportedAt!);
      
      if (difference.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (difference.inHours < 1) {
        timeAgo = '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        timeAgo = '${difference.inHours}h ago';
      } else {
        timeAgo = '${difference.inDays}d ago';
      }
    }

    // Distance (if available)
    String distanceText = '';
    if (_currentPosition != null && issue.latitude != 0 && issue.longitude != 0) {
      final dist = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, issue.latitude, issue.longitude);
      if (dist < 1000) distanceText = '${dist.toInt()} m';
      else distanceText = '${(dist / 1000).toStringAsFixed(2)} km';
    }

    final hasImage = issue.imageUrl != null && issue.imageUrl!.isNotEmpty;

    Widget voteActions() {
      return Builder(builder: (ctx) {
        final userId = UserService.userId;
        final userVote = (userId != null && issue.votes.containsKey(userId)) ? issue.votes[userId] : 0;

        return Row(
          children: [
            IconButton(
              icon: Icon(userVote == 1 ? Icons.thumb_up : Icons.thumb_up_outlined, size: 20, color: userVote == 1 ? Colors.green : Colors.grey[700]),
              onPressed: () async {
                if (userId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please sign in to vote')));
                  return;
                }
                final newVote = (userVote == 1) ? 0 : 1;
                await service.voteIssue(key, userId, newVote);
              },
            ),
            Text('${issue.upvotes}'),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(userVote == -1 ? Icons.thumb_down : Icons.thumb_down_outlined, size: 20, color: userVote == -1 ? Colors.red : Colors.grey[700]),
              onPressed: () async {
                if (userId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please sign in to vote')));
                  return;
                }
                final newVote = (userVote == -1) ? 0 : -1;
                await service.voteIssue(key, userId, newVote);
              },
            ),
            Text('${issue.downvotes}'),
          ],
        );
      });
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: hasImage
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: colorScheme.primary.withOpacity(0.2),
                        child: Icon(statusIcon, size: 16, color: statusColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              issue.reportedBy == null || issue.reportedBy!.isEmpty ? 'Campus User' : issue.reportedBy!,
                              style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                            ),
                            Text(
                              timeAgo.isEmpty ? 'Posted' : timeAgo,
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (distanceText.isNotEmpty)
                        Text(distanceText, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    issue.imageUrl!,
                    width: double.infinity,
                    height: 210,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 210,
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: severityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: severityColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              issue.severity.toUpperCase(),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: severityColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Text(
                              issue.className,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue[700]),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.circle, size: 8, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            issue.status,
                            style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          voteActions(),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${(issue.confidence * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCommentsSection(context, key),
                    ],
                  ),
                ),
              ],
            )
          : ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor),
              ),
              title: Text(
                issue.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: severityColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          issue.severity.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: severityColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Text(
                          issue.className,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue[700]),
                        ),
                      ),
                      if (timeAgo.isNotEmpty || distanceText.isNotEmpty) ...[
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (timeAgo.isNotEmpty) Text(timeAgo, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            if (distanceText.isNotEmpty) Text(distanceText, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        issue.status,
                        style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      voteActions(),
                    ],
                  ),
                    ],
              ),
            ),
    );
  }

  Widget _buildCommentsSection(BuildContext context, String issueKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Comments', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            TextButton.icon(
              icon: const Icon(Icons.add_comment_outlined, size: 18),
              label: const Text('Add comment'),
              onPressed: () => _showAddCommentDialog(context, issueKey),
            ),
          ],
        ),
        StreamBuilder<DatabaseEvent>(
          stream: service.issueCommentsStream(issueKey),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.snapshot.value == null) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('No comments yet.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              );
            }
            final map = snap.data!.snapshot.value as Map<dynamic, dynamic>?;
            if (map == null || map.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('No comments yet.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              );
            }
            final entries = map.entries.toList()
              ..sort((a, b) {
                final aData = a.value is Map ? a.value as Map<dynamic, dynamic> : null;
                final bData = b.value is Map ? b.value as Map<dynamic, dynamic> : null;
                final aTime = aData?['createdAt']?.toString() ?? '';
                final bTime = bData?['createdAt']?.toString() ?? '';
                return aTime.compareTo(bTime);
              });
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entries.map((e) {
                  final data = e.value is Map ? Map<dynamic, dynamic>.from(e.value as Map) : <dynamic, dynamic>{};
                  final text = data['text']?.toString() ?? '';
                  final authorName = data['authorName']?.toString() ?? 'Anonymous';
                  final createdAt = data['createdAt']?.toString();
                  String timeStr = '';
                  if (createdAt != null && createdAt.isNotEmpty) {
                    try {
                      final dt = DateTime.tryParse(createdAt);
                      if (dt != null) {
                        final now = DateTime.now();
                        final diff = now.difference(dt);
                        if (diff.inMinutes < 1) timeStr = 'Just now';
                        else if (diff.inHours < 1) timeStr = '${diff.inMinutes}m ago';
                        else if (diff.inDays < 1) timeStr = '${diff.inHours}h ago';
                        else timeStr = '${diff.inDays}d ago';
                      }
                    } catch (_) {}
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 12, backgroundColor: Colors.blue[100], child: Text((authorName.isNotEmpty ? authorName[0] : '?').toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.blue[800]))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(authorName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  if (timeStr.isNotEmpty) Text(' · $timeStr', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(text, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showAddCommentDialog(BuildContext context, String issueKey) async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add comment'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Write a comment...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (submitted == true && controller.text.trim().isNotEmpty && context.mounted) {
      await service.addIssueComment(issueKey, controller.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment added')));
      }
    }
  }
}