import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();

    final bool success = await authProvider.resetPassword(email);
    if (!mounted) return;

    if (success) {
      setState(() {
        _emailSent = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Request failed. Account may not exist.'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 700;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reset Password'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return Stack(
            children: [
              // Background glow
              if (isDark) ...[
                Positioned(
                  bottom: -100,
                  left: -80,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCyan.withOpacity(0.08),
                          blurRadius: 100,
                          spreadRadius: 100,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: isLargeScreen ? 460 : size.width,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill(Theme.of(context).brightness),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.glassBorder(Theme.of(context).brightness),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.black : Colors.grey).withOpacity(0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 400),
                      crossFadeState: _emailSent
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.lock_reset_rounded,
                              size: 64,
                              color: AppColors.accentAmber,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Recover Password',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Enter your registered email address below, and we will send a simulated recovery link to configure a new password.',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),

                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submitForgotPassword(),
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'driver@evhub.com',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Email is required';
                                }
                                if (!AuthService.validateEmail(val)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            ElevatedButton(
                              onPressed: _submitForgotPassword,
                              child: const Text('Send Reset Link'),
                            ),
                          ],
                        ),
                      ),
                      secondChild: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.mark_email_read_rounded,
                            size: 64,
                            color: AppColors.accentGreen,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Check Your Inbox',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'We have sent a simulated password recovery email. In production, this would contain a link to reset your account details.',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Back to Log In'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Loading Spinner
              if (authProvider.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.55),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
