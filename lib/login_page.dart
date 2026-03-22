import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'register_page.dart';
import 'user_service.dart';
import 'firebase_db.dart';
import 'app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  
  DatabaseReference get _db => dbRef("users");

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedRole;

  Future<void> _login() async {
    if (usernameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      setState(() => _errorMessage = "Please enter username and password");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch all users and find matching username (avoids Firebase index requirement)
      final snapshot = await _db
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection timeout. Please check your internet connection and Firebase configuration.');
            },
          );

      final value = snapshot.value;
      if (value == null) {
        setState(() {
          _errorMessage = "No users in database. Register first (Create New Account).";
          _isLoading = false;
        });
        return;
      }

      final Map<dynamic, dynamic> users = value is Map ? Map<dynamic, dynamic>.from(value) : <dynamic, dynamic>{};
      String? userKey;
      Map<dynamic, dynamic>? userData;

      for (final e in users.entries) {
        final data = e.value;
        if (data is Map && (data["username"]?.toString() ?? "") == usernameCtrl.text.trim()) {
          userKey = e.key.toString();
          userData = Map<dynamic, dynamic>.from(data);
          break;
        }
      }

      if (userData == null) {
        setState(() {
          _errorMessage = "Username not found. Register first if you haven’t.";
          _isLoading = false;
        });
        return;
      }

      // Check password (trim both; Firebase may store with different type)
      if (userData["password"]?.toString().trim() != passwordCtrl.text.trim()) {
        setState(() {
          _errorMessage = "Incorrect password";
          _isLoading = false;
        });
        return;
      }

      // Get user role and navigate accordingly (case-insensitive)
      final String role = (userData["role"] ?? "Student").toString().trim();
      setState(() => _selectedRole = role);

      // Save current user id and username for vote tracking
      try {
        UserService.setCurrentUser(userKey!, (userData["username"] ?? usernameCtrl.text).toString(), role);
      } catch (e) {
        print('Failed to set current user: $e');
      }

      // Navigate based on role (use root navigator to ensure correct route stack)
      if (mounted) {
        setState(() => _isLoading = false);
        final nav = Navigator.of(context, rootNavigator: true);
        if (role.toLowerCase() == "admin") {
          nav.pushNamedAndRemoveUntil('/admin', (route) => false);
        } else {
          nav.pushNamedAndRemoveUntil('/home', (route) => false);
        }
      }

    } on Exception catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('timeout') || errorMsg.contains('Connection') || errorMsg.contains('Database') || errorMsg.contains('Firebase')) {
        setState(() {
          _errorMessage = "Database connection failed.\n\nPossible causes:\n• Wrong Firebase project configured\n• Database not enabled\n• Network connection issue\n\nPlease run 'flutterfire configure' to fix.";
          _isLoading = false;
        });
      } else if (errorMsg.contains('Permission') || errorMsg.contains('permission_denied') || errorMsg.contains('PERMISSION_DENIED')) {
        setState(() {
          _errorMessage = "Database permission denied.\n\nIn Firebase Console → Realtime Database → Rules, allow read for login, e.g.:\n\"users\": { \".read\": true, \".write\": true }\n(Use stricter rules in production.)";
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Login failed: $errorMsg";
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      setState(() {
        _errorMessage = "Login failed: $e\n\nIf you see permission_denied, update Realtime Database rules in Firebase Console to allow read on 'users'.";
        _isLoading = false;
      });
      debugPrint('Login error: $e\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // App Name Section
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Spot',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -1,
                          height: 1.2,
                        ),
                      ),
                      TextSpan(
                        text: ' It',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppColors.aquaBlue,
                          letterSpacing: -1,
                          height: 1.2,
                        ),
                      ),
                      TextSpan(
                        text: ' AI',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppColors.charcoal,
                          letterSpacing: -1,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.aquaBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.aquaBlue.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    "See it • Report it • Fix it",
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Login Form Container
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.elevatedShadow,
                    border: Border.all(
                      color: AppColors.skyBlue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Login Header
                      const Row(
                        children: [
                          Icon(
                            Icons.login_rounded,
                              color: AppColors.aquaBlue,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Sign In to Continue",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Username Field
                      TextField(
                        controller: usernameCtrl,
                        decoration: InputDecoration(
                          labelText: "Username",
                          labelStyle: TextStyle(
                            color: AppColors.charcoal.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: "Enter your username",
                          hintStyle: TextStyle(
                            color: AppColors.skyBlue,
                          ),
                          prefixIcon: Container(
                            margin: EdgeInsets.all(12),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.aquaBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.aquaBlue,
                              size: 20,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.skyBlue, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.skyBlue, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.aquaBlue,
                              width: 2.5,
                            ),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                        ),
                        onChanged: (_) => setState(() => _errorMessage = null),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Password Field
                      TextField(
                        controller: passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: TextStyle(
                            color: AppColors.charcoal.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: "Enter your password",
                          hintStyle: TextStyle(
                            color: AppColors.skyBlue,
                          ),
                          prefixIcon: Container(
                            margin: EdgeInsets.all(12),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.aquaBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.aquaBlue,
                              size: 20,
                            ),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.skyBlue,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.skyBlue, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.skyBlue, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.aquaBlue,
                              width: 2.5,
                            ),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                        ),
                        onChanged: (_) => setState(() => _errorMessage = null),
                        onSubmitted: (_) => _login(),
                      ),
                      
                      // Error Message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[100]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red[400],
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.aquaBlue,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: AppColors.aquaBlue.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login_rounded, size: 24),
                                    SizedBox(width: 12),
                                    Text(
                                      "Sign In",
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Forgot Password (optional)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/forgot'),
                          child: Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Divider with decorative elements
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.grey[300],
                        thickness: 1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.getGrey(context, 50),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.getGrey(context, 200)),
                      ),
                      child: Text(
                        "NEW TO SPOTIT AI?",
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.grey[300],
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Register Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.aquaBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Colors.blue.shade100,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shadowColor: Colors.blue.withOpacity(0.1),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded, size: 22),
                        SizedBox(width: 12),
                        Text(
                          "Create New Account",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Note about automatic role detection
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Your role (Student/Admin) will be automatically detected based on your registration",
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Footer
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.getGrey(context, 50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.getGrey(context, 200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.security_rounded,
                            size: 16,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Secure Authentication • AI-Powered Campus",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "© 2024 SpotIt AI. All rights reserved",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}