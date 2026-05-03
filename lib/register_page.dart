import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_service.dart';
import 'app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _db = Supabase.instance.client.from('users');
  
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  final TextEditingController departmentCtrl = TextEditingController();
  final TextEditingController adminTypeCtrl = TextEditingController();
  final TextEditingController employeeIdCtrl = TextEditingController();
  final TextEditingController roleCtrl = TextEditingController();
  final TextEditingController otpCtrl = TextEditingController();
  
  String? selectedRole;
  String? selectedDepartment;
  String? selectedAdminType;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _otpSent = false;
  bool _isVerifying = false;
  String? _generatedOTP;
  DateTime? _otpExpiryTime;
  
  final List<String> departments = [
    'Computer Science',
    'Electrical Engineering',
    'Electronics and Communication',
    'Mechanical Engineering',
    'Civil Engineering',
    'Other'
  ];

  final List<String> adminTypes = [
    'Faculty',
    'Department Head',
    'Lab Incharge',
    'Security Staff',
    'Other'
  ];

  Future<void> sendOTP() async {
    if (emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter your email address"),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      _generatedOTP = EmailService.generateOTP();
      _otpExpiryTime = DateTime.now().add(const Duration(minutes: 10));
      
      bool emailSent = await EmailService.sendOTPEmail(emailCtrl.text, _generatedOTP!);
      
      if (emailSent) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text("OTP sent to your email!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Failed to send OTP. Please try again."),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isOTPExpired() {
    if (_otpExpiryTime == null) return true;
    return DateTime.now().isAfter(_otpExpiryTime!);
  }

  Future<void> verifyOTP() async {
    if (otpCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter the OTP"),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isOTPExpired()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("OTP has expired. Please request a new one."),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _otpSent = false;
        _generatedOTP = null;
        _otpExpiryTime = null;
        otpCtrl.clear();
      });
      return;
    }

    setState(() => _isVerifying = true);

    try {
      if (otpCtrl.text == _generatedOTP) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text("Email verified successfully!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Proceed with registration
        await _completeRegistration();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Invalid OTP. Please try again."),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _completeRegistration() async {
    try {
      // Check if username already exists
      final existing = await _db
          .select('id')
          .eq('username', usernameCtrl.text)
          .limit(1);
      if ((existing as List).isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Username already exists"),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Prepare user data
      Map<String, dynamic> userData = {
        "name": nameCtrl.text,
        "username": usernameCtrl.text,
        "email": emailCtrl.text,
        "password": passwordCtrl.text,
        "role": selectedRole,
        "created_at": DateTime.now().toIso8601String(),
        "profile_complete": false,
        "email_verified": true,
      };

      // Add role-specific data
      if (selectedRole == "Student") {
        userData["department"] = selectedDepartment;
        userData["user_type"] = "Student";
      } else if (selectedRole == "Admin") {
        userData["admin_type"] = selectedAdminType;
        userData["employee_id"] = employeeIdCtrl.text;
        userData["department"] = selectedDepartment ?? "Administration";
        userData["user_type"] = "Staff";
      }

      // Register new user in Supabase
      await _db.insert(userData);

      // Success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text("Registration successful!"),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate to appropriate page based on role
      Future.delayed(const Duration(milliseconds: 1500), () {
        Navigator.pop(context);
        if (selectedRole == "Student") {
          Navigator.pushReplacementNamed(context, '/home');
        } else if (selectedRole == "Admin") {
          Navigator.pushReplacementNamed(context, '/admin');
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> registerUser() async {
    // Basic validation
    if (nameCtrl.text.isEmpty ||
        usernameCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
        passwordCtrl.text.isEmpty ||
        selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please fill all required fields"),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Role-specific validation
    if (selectedRole == "Student") {
      if (selectedDepartment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Please select your department"),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else if (selectedRole == "Admin") {
      if (selectedAdminType == null || employeeIdCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Please fill all admin details"),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    
    if (passwordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Password must be at least 6 characters"),
          backgroundColor: Colors.orange[400],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Send OTP for email verification
    await sendOTP();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Centered Header
                Column(
                  children: [
                    // Back button at top left
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.aquaBlue,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Centered App Name
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Spot',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: 'it',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.aquaBlue,
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: ' AI\n',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.aquaBlue.withOpacity(0.8),
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: 'Registration',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.aquaBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      "Join our smart campus community",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Form Container
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.05),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Personal Info Section
                      _buildSectionHeader(
                        icon: Icons.person_outline_rounded,
                        title: "Personal Information",
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Name Field
                      _buildTextField(
                        controller: nameCtrl,
                        label: "Full Name",
                        hint: "Enter your full name",
                        icon: Icons.person,
                        isRequired: true,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Email Field
                      _buildTextField(
                        controller: emailCtrl,
                        label: "Email Address",
                        hint: "Enter your university email",
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        isRequired: true,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Username Field
                      _buildTextField(
                        controller: usernameCtrl,
                        label: "Username",
                        hint: "Choose a unique username",
                        icon: Icons.alternate_email_rounded,
                        isRequired: true,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Password Field
                      TextField(
                        controller: passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password *",
                          hintText: "At least 6 characters",
                          prefixIcon: Icon(
                            Icons.lock_rounded,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.aquaBlue,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: AppColors.getGrey(context, 50),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Role Selection
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Account Type *",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildRoleCard(
                                  title: "Student",
                                  subtitle: "For students",
                                  icon: Icons.school_rounded,
                                  color: AppColors.aquaBlue,
                                  isSelected: selectedRole == "Student",
                                  onTap: () {
                                    setState(() {
                                      selectedRole = "Student";
                                      roleCtrl.text = "Student";
                                      // Clear admin fields when switching to student
                                      selectedAdminType = null;
                                      adminTypeCtrl.text = "";
                                      employeeIdCtrl.text = "";
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildRoleCard(
                                  title: "Admin",
                                  subtitle: "Staff/Teacher",
                                  icon: Icons.admin_panel_settings_rounded,
                                  color: AppColors.aquaBlue,
                                  isSelected: selectedRole == "Admin",
                                  onTap: () {
                                    setState(() {
                                      selectedRole = "Admin";
                                      roleCtrl.text = "Admin";
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Dynamic Fields based on Role
                      if (selectedRole != null) ...[
                        if (selectedRole == "Student") ...[
                          // Student Specific Fields
                          _buildSectionHeader(
                            icon: Icons.school_rounded,
                            title: "Student Information",
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Department for Students
                          DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            items: departments.map((dept) {
                              return DropdownMenuItem(
                                value: dept,
                                child: Text(dept),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedDepartment = value;
                                departmentCtrl.text = value!;
                              });
                            },
                            decoration: InputDecoration(
                              labelText: "Department *",
                              hintText: "Select your department",
                              prefixIcon: Icon(
                                Icons.business_rounded,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.aquaBlue,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.getGrey(context, 50),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            icon: Icon(
                              Icons.arrow_drop_down_rounded,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ] else if (selectedRole == "Admin") ...[
                          // Admin Specific Fields
                          _buildSectionHeader(
                            icon: Icons.badge_rounded,
                            title: "Staff Information",
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Admin Type Selection
                          DropdownButtonFormField<String>(
                            value: selectedAdminType,
                            items: adminTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedAdminType = value;
                                adminTypeCtrl.text = value!;
                              });
                            },
                            decoration: InputDecoration(
                              labelText: "Staff Type *",
                              hintText: "Select your role",
                              prefixIcon: Icon(
                                Icons.work_rounded,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.aquaBlue,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.getGrey(context, 50),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            icon: Icon(
                              Icons.arrow_drop_down_rounded,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Employee ID
                          _buildTextField(
                            controller: employeeIdCtrl,
                            label: "Employee ID",
                            hint: "Enter your employee/staff ID",
                            icon: Icons.badge_outlined,
                            isRequired: true,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Optional Department for Admin
                          DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            items: [const DropdownMenuItem(value: null, child: Text("Not Applicable"))]
                              ..addAll(departments.map((dept) {
                                return DropdownMenuItem(
                                  value: dept,
                                  child: Text(dept),
                                );
                              }).toList()),
                            onChanged: (value) {
                              setState(() {
                                selectedDepartment = value;
                                if (value != null) {
                                  departmentCtrl.text = value;
                                }
                              });
                            },
                            decoration: InputDecoration(
                              labelText: "Department (Optional)",
                              hintText: "Select if applicable",
                              prefixIcon: Icon(
                                Icons.business_rounded,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.aquaBlue,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: AppColors.getGrey(context, 50),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            icon: Icon(
                              Icons.arrow_drop_down_rounded,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                      
                      // OTP Verification Section
                      if (_otpSent) ...[
                        _buildSectionHeader(
                          icon: Icons.verified_user_rounded,
                          title: "Email Verification",
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.aquaBlue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.aquaBlue.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: AppColors.aquaBlue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "We've sent a 6-digit OTP to ${emailCtrl.text}",
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // OTP Input Field
                              TextField(
                                controller: otpCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: InputDecoration(
                                  labelText: "Enter OTP *",
                                  hintText: "6-digit code",
                                  prefixIcon: Icon(
                                    Icons.password_rounded,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  counterText: "",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.aquaBlue,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.getGrey(context, 50),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Verify OTP Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isVerifying ? null : verifyOTP,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.aquaBlue,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: _isVerifying
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.verified_rounded, size: 20),
                                            SizedBox(width: 8),
                                            Text("Verify Email"),
                                          ],
                                        ),
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Resend OTP
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Didn't receive the code? ",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _isLoading ? null : sendOTP,
                                    child: Text(
                                      "Resend OTP",
                                      style: TextStyle(
                                        color: AppColors.aquaBlue,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                      ],
                      
                      // Register Button (hidden when OTP is sent)
                      if (!_otpSent) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : registerUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedRole == "Admin" 
                                  ? AppColors.aquaBlue
                                  : AppColors.aquaBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shadowColor: Colors.blue.withOpacity(0.2),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        selectedRole == "Admin" 
                                            ? Icons.admin_panel_settings_rounded 
                                            : Icons.person_add_alt_1_rounded,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "Create ${selectedRole == "Admin" ? "Staff" : "Student"} Account",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                      ],
                      
                      // Terms and Conditions
                      Text(
                        "By creating an account, you agree to our Terms & Privacy Policy",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Already have account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        "Sign In",
                        style: TextStyle(
                          color: AppColors.aquaBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.aquaBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.aquaBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: isRequired ? "$label *" : label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.aquaBlue,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: AppColors.getGrey(context, 50),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
            ? color.withOpacity(0.1)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? color.withOpacity(0.8) : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}