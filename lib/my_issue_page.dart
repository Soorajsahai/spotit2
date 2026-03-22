import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'model/issue_model.dart';
import 'model/post_model.dart';
import 'user_service.dart';
import 'app_theme.dart';

class MyIssuesPage extends StatefulWidget {
  const MyIssuesPage({super.key});

  @override
  State<MyIssuesPage> createState() => _MyIssuesPageState();
}

class _MyIssuesPageState extends State<MyIssuesPage> {
  final service = FirebaseService();

  String _formatTimeAgo(DateTime? reportedAt) {
    if (reportedAt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(reportedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final userId = UserService.userId;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? colorScheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? colorScheme.onSurface,
        elevation: 1,
        title: const Text('My Reports'),
      ),
      body: userId == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Not signed in'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            )
          : StreamBuilder(
              stream: service.getIssues().onValue.asBroadcastStream(),
              builder: (context, issueSnap) {
                final issues = <Issue>[];
                if (issueSnap.hasData) {
                  final value = issueSnap.data!.snapshot.value;
                  if (value is Map) {
                    final map = Map<dynamic, dynamic>.from(value);
                    issues.addAll(
                      map.entries
                          .map((e) => Issue.fromJson(Map<dynamic, dynamic>.from(e.value)))
                          // Match either by stored userId (legacy) or username (new)
                          .where((i) =>
                              (i.reportedBy ?? '') == userId ||
                              (i.reportedBy ?? '') == (UserService.username ?? '')),
                    );
                    issues.sort((a, b) {
                      if (b.upvotes != a.upvotes) return b.upvotes.compareTo(a.upvotes);
                      return (b.reportedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                          .compareTo(a.reportedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
                    });
                  }
                }

                return StreamBuilder(
                  stream: service.postsStream,
                  builder: (context, postSnap) {
                    final myPosts = <Post>[];
                    if (postSnap.hasData) {
                      final value = postSnap.data!.snapshot.value;
                      if (value is Map) {
                        final map = Map<dynamic, dynamic>.from(value);
                        myPosts.addAll(
                          map.entries
                              .map((e) => Post.fromJson(Map<dynamic, dynamic>.from(e.value), e.key.toString()))
                              .where((p) => p.authorId == userId),
                        );
                        myPosts.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
                      }
                    }

                    if (issues.isEmpty && myPosts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('No issues or posts yet', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/create-post'),
                              icon: const Icon(Icons.add),
                              label: const Text('Create a post'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (myPosts.isNotEmpty) ...[
                          Text('My Posts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                          const SizedBox(height: 8),
                          ...myPosts.map(_buildPostCard),
                          const SizedBox(height: 16),
                        ],
                        if (issues.isNotEmpty) ...[
                          Text('My Reported Issues', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                          const SizedBox(height: 8),
                          ...issues.map(_buildIssueCard),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildPostCard(Post post) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeAgo = _formatTimeAgo(post.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              post.imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                color: colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image, size: 48),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.description, style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(timeAgo, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    const Spacer(),
                    Text('by ${post.authorName}', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(Issue it) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          it.title,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: colorScheme.onSurface),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text('${it.className} • ${it.status} • ${it.severity}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(_formatTimeAgo(it.reportedAt), style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
