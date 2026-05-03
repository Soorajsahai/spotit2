import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'model/issue_model.dart';
import 'model/post_model.dart';
import 'user_service.dart';

final supabase = Supabase.instance.client;

class SupabaseService {
  // ─── Issues ───────────────────────────────────────────────────────────────

  Stream<List<Issue>> get issuesStream => supabase
      .from('issues')
      .stream(primaryKey: ['id'])
      .order('reported_at', ascending: false)
      .map((rows) => rows.map((r) => Issue.fromMap(r)).toList());

  Future<List<Issue>> fetchIssues() async {
    final res = await supabase
        .from('issues')
        .select()
        .order('reported_at', ascending: false);
    return (res as List).map((r) => Issue.fromMap(r)).toList();
  }

  Future<String?> addIssue(Issue issue) async {
    try {
      final res = await supabase
          .from('issues')
          .insert(issue.toSupabaseJson())
          .select('id')
          .single();
      return res['id'] as String?;
    } catch (e) {
      print('addIssue error: $e');
      throw e;
    }
  }

  Future<void> updateIssueStatus(String id, String status) async {
    try {
      await supabase
          .from('issues')
          .update({'status': status})
          .eq('id', id);
    } catch (e) {
      print('updateIssueStatus error: $e');
    }
  }

  Future<void> deleteIssue(String id) async {
    try {
      await supabase.from('issues').delete().eq('id', id);
    } catch (e) {
      print('deleteIssue error: $e');
    }
  }

  // ─── Votes ─────────────────────────────────────────────────────────────────

  /// vote: 1 = upvote, -1 = downvote, 0 = remove
  Future<void> voteIssue(String issueId, String userId, int vote) async {
    try {
      if (vote == 0) {
        // Remove existing vote
        await supabase
            .from('issue_votes')
            .delete()
            .eq('issue_id', issueId)
            .eq('user_id', userId);
      } else {
        // Upsert vote
        await supabase.from('issue_votes').upsert({
          'issue_id': issueId,
          'user_id': userId,
          'vote': vote,
        });
      }
      // Recalculate upvotes/downvotes
      final votes = await supabase
          .from('issue_votes')
          .select('vote')
          .eq('issue_id', issueId);
      final up = (votes as List).where((v) => v['vote'] == 1).length;
      final down = (votes).where((v) => v['vote'] == -1).length;
      await supabase
          .from('issues')
          .update({'upvotes': up, 'downvotes': down})
          .eq('id', issueId);
    } catch (e) {
      print('voteIssue error: $e');
    }
  }

  Future<Map<String, int>> fetchVotesForIssue(String issueId) async {
    try {
      final rows = await supabase
          .from('issue_votes')
          .select('user_id, vote')
          .eq('issue_id', issueId);
      return Map.fromEntries(
        (rows as List).map((r) => MapEntry(r['user_id'] as String, r['vote'] as int)),
      );
    } catch (_) {
      return {};
    }
  }

  // ─── Comments ──────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> issueCommentsStream(String issueId) =>
      supabase
          .from('issue_comments')
          .stream(primaryKey: ['id'])
          .eq('issue_id', issueId)
          .order('created_at')
          .map((rows) => rows.cast<Map<String, dynamic>>());

  Future<void> addIssueComment(String issueId, String text) async {
    if (text.trim().isEmpty) return;
    await supabase.from('issue_comments').insert({
      'issue_id': issueId,
      'text': text.trim(),
      'author_id': UserService.userId ?? '',
      'author_name': UserService.username ?? 'Anonymous',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── Posts ─────────────────────────────────────────────────────────────────

  Stream<List<Post>> get postsStream => supabase
      .from('posts')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map((r) => Post.fromMap(r)).toList());

  Future<void> addPost(Post post) async {
    await supabase.from('posts').insert(post.toSupabaseJson());
  }

  // ─── Reports ───────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> get reportsStream => supabase
      .from('reports')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.cast<Map<String, dynamic>>());

  // ─── Users ─────────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> get usersStream => supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.cast<Map<String, dynamic>>());

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final res = await supabase.from('users').select().order('created_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> deleteUser(String id) async {
    try {
      await supabase.from('users').delete().eq('id', id);
    } catch (e) {
      print('deleteUser error: $e');
    }
  }

  Future<bool> resetPasswordByEmail(String email, String newPassword) async {
    try {
      final res = await supabase
          .from('users')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      if (res == null) return false;
      await supabase
          .from('users')
          .update({'password': newPassword})
          .eq('email', email);
      return true;
    } catch (e) {
      print('resetPasswordByEmail error: $e');
      return false;
    }
  }

  // ─── Storage ───────────────────────────────────────────────────────────────

  Future<String?> uploadImage(File imageFile, {String bucket = 'issue-images'}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final rawName = imageFile.path.split(RegExp(r'[/\\]')).last;
      final safeName = rawName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '${timestamp}_$safeName';

      await supabase.storage.from(bucket).upload(
        path,
        imageFile,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      final url = supabase.storage.from(bucket).getPublicUrl(path);
      return url;
    } catch (e) {
      print('uploadImage error ($bucket): $e');
      return null;
    }
  }

  Future<String?> uploadPostImage(File imageFile) =>
      uploadImage(imageFile, bucket: 'post-images');

  Future<String?> uploadReportImage(File imageFile) async {
    final url = await uploadImage(imageFile, bucket: 'report-images');
    if (url != null) {
      await supabase.from('reports').insert({
        'image_url': url,
        'created_at': DateTime.now().toIso8601String(),
        'uploaded_by': UserService.userId,
      });
    }
    return url;
  }
}
