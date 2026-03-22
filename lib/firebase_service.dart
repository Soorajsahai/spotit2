import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_db.dart';
import 'user_service.dart';
import 'model/issue_model.dart';
import 'model/post_model.dart';

class FirebaseService {
  DatabaseReference get _ref => dbRef("issues");

  void addIssue(Issue issue) {
    _ref.push().set(issue.toJson());
  }

  DatabaseReference getIssues() => _ref;

  /// Vote on an issue for a specific user. `vote` is 1 (upvote), -1 (downvote), or 0 (remove vote).
  Future<void> voteIssue(String key, String userId, int vote) async {
    final issueRef = _ref.child(key);
    try {
      await issueRef.runTransaction((currentData) {
        final current = (currentData as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
        final votes = Map<String, dynamic>.from(current['votes'] ?? {});
        final prev = (votes[userId] is num) ? (votes[userId] as num).toInt() : (votes[userId] != null ? int.tryParse('${votes[userId]}') ?? 0 : 0);

        int up = (current['upvotes'] is num) ? (current['upvotes'] as num).toInt() : 0;
        int down = (current['downvotes'] is num) ? (current['downvotes'] as num).toInt() : 0;

        if (vote == prev) {
          // toggle off
          if (prev == 1) up = (up - 1).clamp(0, 1 << 30);
          if (prev == -1) down = (down - 1).clamp(0, 1 << 30);
          votes.remove(userId);
        } else {
          // change vote
          if (prev == 1) up = (up - 1).clamp(0, 1 << 30);
          if (prev == -1) down = (down - 1).clamp(0, 1 << 30);
          if (vote == 1) up = up + 1;
          if (vote == -1) down = down + 1;
          if (vote == 0) votes.remove(userId);
          else votes[userId] = vote;
        }

        final updated = Map<dynamic, dynamic>.from(current);
        updated['upvotes'] = up;
        updated['downvotes'] = down;
        updated['votes'] = votes;

        return Transaction.success(updated);
      });
    } catch (e) {
      print('voteIssue error: $e');
    }
  }

  // Admin helpers
  DatabaseReference get _usersRef => dbRef('users');

  DatabaseReference getUsers() => _usersRef;

  DatabaseReference get reportsRef => dbRef('reports');
  Stream<DatabaseEvent> get reportsStream => reportsRef.onValue.asBroadcastStream();

  DatabaseReference get postsRef => dbRef('posts');
  Stream<DatabaseEvent> get postsStream => postsRef.onValue.asBroadcastStream();

  /// Upload image for a post (to Storage under posts/) and return download URL.
  Future<String?> uploadPostImage(File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = imageFile.path.split(RegExp(r'[/\\]')).last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'posts/${timestamp}_$name';
      final ref = storageRef.child(path);
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('uploadPostImage error: $e');
      return null;
    }
  }

  /// Save a post to Realtime Database (imageUrl, description, authorId, authorName, createdAt).
  Future<void> addPost(Post post) async {
    await postsRef.push().set(post.toJson());
  }

  // Broadcast streams to allow multiple listeners across widgets
  Stream<DatabaseEvent> get issuesStream => _ref.onValue.asBroadcastStream();
  Stream<DatabaseEvent> get usersStream => _usersRef.onValue.asBroadcastStream();

  /// Reference to comments for an issue (post). Path: issue_comments/{issueKey}
  DatabaseReference issueCommentsRef(String issueKey) =>
      dbRef('issue_comments').child(issueKey);

  /// Stream of comments for an issue
  Stream<DatabaseEvent> issueCommentsStream(String issueKey) =>
      issueCommentsRef(issueKey).onValue.asBroadcastStream();

  /// Add a comment to an issue. Uses current user from UserService.
  Future<void> addIssueComment(String issueKey, String text) async {
    if (text.trim().isEmpty) return;
    await issueCommentsRef(issueKey).push().set({
      'text': text.trim(),
      'authorId': UserService.userId ?? '',
      'authorName': UserService.username ?? 'Anonymous',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateIssueStatus(String key, String status) async {
    try {
      await _ref.child(key).update({'status': status});
    } catch (e) {
      print('updateIssueStatus error: $e');
    }
  }

  Future<void> deleteIssue(String key) async {
    try {
      await _ref.child(key).remove();
    } catch (e) {
      print('deleteIssue error: $e');
    }
  }

  Future<void> deleteUser(String key) async {
    try {
      await _usersRef.child(key).remove();
    } catch (e) {
      print('deleteUser error: $e');
    }
  }

  /// Upload an image file to Firebase Storage and return the download URL
  Future<String?> uploadImage(File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'issue_images/${timestamp}_${imageFile.path.split('/').last}';
      final imageRef = storageRef.child(fileName);

      await imageRef.putFile(imageFile);
      final downloadUrl = await imageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('uploadImage error: $e');
      return null;
    }
  }

  /// Reset a user's password by their registered email. Returns true if the
  /// email was found and password updated, false otherwise.
  Future<bool> resetPasswordByEmail(String email, String newPassword) async {
    try {
      final snapshot = await _usersRef.orderByChild('email').equalTo(email).once();
      final value = snapshot.snapshot.value;
      if (value == null) return false;

      final Map<dynamic, dynamic> map = value as Map<dynamic, dynamic>;
      final key = map.keys.first.toString();
      await _usersRef.child(key).update({'password': newPassword});
      return true;
    } catch (e) {
      print('resetPasswordByEmail error: $e');
      return false;
    }
  }

  /// Uploads a report image from gallery to Firebase Storage and saves metadata to Realtime Database.
  /// 
  /// Steps:
  /// 1. Picks image from gallery using ImagePicker
  /// 2. Uploads it to Firebase Storage under reports/
  /// 3. Gets the download URL
  /// 4. Saves to Realtime Database 'reports' with imageUrl and createdAt
  /// 5. Returns the download URL
  /// 
  /// Returns the download URL on success, null on failure.
  /// Throws exceptions for proper error handling.
  Future<String?> uploadReportImage() async {
    try {
      // Step 1: Pick image from gallery
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        throw Exception('No image selected');
      }

      // Convert XFile to File
      final File imageFile = File(pickedFile.path);

      if (!await imageFile.exists()) {
        throw Exception('Selected image file does not exist');
      }

      // Verify file size
      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        throw Exception('Selected file is empty');
      }

      // Step 2: Upload to Firebase Storage under reports/
      // Use the same pattern as the working uploadImage function
      final storageRef = FirebaseStorage.instance.ref();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalFileName = imageFile.path.split('/').last;
      // Sanitize filename to avoid issues
      final sanitizedFileName = originalFileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final fileName = 'reports/${timestamp}_$sanitizedFileName';
      
      print('Uploading to: $fileName');
      print('File size: $fileSize bytes');
      print('File path: ${imageFile.path}');
      
      final imageRef = storageRef.child(fileName);

      try {
        // Use putFile with metadata for better error handling
        final uploadTask = imageRef.putFile(
          imageFile,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          ),
        );

        // Wait for upload to complete
        final snapshot = await uploadTask;
        print('Upload completed. Bytes transferred: ${snapshot.bytesTransferred}');
      } on FirebaseException catch (e) {
        print('Firebase Storage error code: ${e.code}');
        print('Firebase Storage error message: ${e.message}');
        if (e.code == 'object-not-found') {
          throw Exception('Storage bucket not found or not configured. Please check Firebase Storage settings.');
        } else if (e.code == 'unauthorized') {
          throw Exception('Permission denied. Please check Firebase Storage security rules.');
        } else if (e.code == 'unauthenticated') {
          throw Exception('Authentication required. Please sign in.');
        } else {
          throw Exception('Failed to upload image to Storage: ${e.code} - ${e.message}');
        }
      } catch (e) {
        print('Upload error: $e');
        throw Exception('Failed to upload image to Storage: $e');
      }

      // Step 3: Get the download URL
      String downloadUrl;
      try {
        downloadUrl = await imageRef.getDownloadURL();
        print('Download URL obtained: $downloadUrl');
      } catch (e) {
        print('Failed to get download URL: $e');
        throw Exception('Failed to get download URL: $e');
      }

      // Step 4: Return the download URL.
      // The caller creates the actual campus issue entry (with location, status, etc.).
      return downloadUrl;
    } on Exception catch (e) {
      print('uploadReportImage error: $e');
      rethrow;
    } catch (e) {
      print('uploadReportImage unexpected error: $e');
      throw Exception('Unexpected error occurred: $e');
    }
  }
}

