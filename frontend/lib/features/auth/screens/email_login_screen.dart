// MOVED FROM: lib/features/auth/screens/email_login_screen.dart
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'otp_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final String _selectedCountryCode = "+91";
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEmailOnlyMode = true;

  void _handleLogin() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = "Please enter a valid email address");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();

    if (_isEmailOnlyMode) {
      // Try to send OTP with just the email (assumes existing user)
      final result = await authProvider.sendEmailOtp(email);
      
      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success'] == true) {
          // Existing user, OTP sent successfully
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(email: email),
            ),
          );
        } else if (result['error'] != null && result['error'].toString().contains('Name and Phone')) {
          // New user, backend requires name and phone
          setState(() {
            _isEmailOnlyMode = false;
            _errorMessage = "New email detected. Please complete registration.";
          });
        } else {
          setState(() {
            _errorMessage = result['error'] ?? "Failed to verify email.";
          });
        }
      }
    } else {
      // Full registration mode
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      if (name.isEmpty || name.length < 2) {
        setState(() {
          _errorMessage = "Please enter your full name";
          _isLoading = false;
        });
        return;
      }

      if (phone.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
        setState(() {
          _errorMessage = "Enter a valid 10-digit mobile number";
          _isLoading = false;
        });
        return;
      }

      final fullPhoneNumber = "$_selectedCountryCode$phone";
      final result = await authProvider.sendEmailOtp(email, name: name, phone: fullPhoneNumber);

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(email: email),
            ),
          );
        } else {
          setState(() {
            _errorMessage = result['error'] ?? "Failed to send verification email.";
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInDown(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEmailOnlyMode ? "Login / Register" : "Registration",
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isEmailOnlyMode 
                          ? "Enter your email to receive a verification code" 
                          : "Complete your profile to finish registration",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // 1. Email Field (Always visible)
              FadeInLeft(
                delay: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surface),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, color: AppColors.textPrimary, size: 20),
                      const SizedBox(width: 16),
                      Container(height: 24, width: 1, color: AppColors.surface),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: AppColors.textPrimary),
                          readOnly: !_isEmailOnlyMode, // Lock email if they are completing registration
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Email Address",
                            hintStyle: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (!_isEmailOnlyMode) ...[
                const SizedBox(height: 16),
                // 2. Name Field
                FadeInLeft(
                  delay: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.surface),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, color: AppColors.textPrimary, size: 20),
                        const SizedBox(width: 16),
                        Container(height: 24, width: 1, color: AppColors.surface),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "Full Name",
                              hintStyle: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Phone Field
                FadeInLeft(
                  delay: const Duration(milliseconds: 400),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.surface),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(_selectedCountryCode, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Container(height: 24, width: 1, color: AppColors.surface),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "Phone Number",
                              hintStyle: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 32),
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Send Verification Code"),
                ),
              ),
              const SizedBox(height: 40),
              FadeInRight(
                delay: const Duration(milliseconds: 700),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.surface)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "OR",
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.surface)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FadeInUp(
                delay: const Duration(milliseconds: 900),
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    side: const BorderSide(color: AppColors.surface),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_android_outlined, color: AppColors.textPrimary),
                      const SizedBox(width: 12),
                      Text(
                        "Continue with Phone Number",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
