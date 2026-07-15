import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    
    // Autofill credentials if Remember Me was checked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final creds = authProvider.getRememberedCredentials();
      if (creds != null) {
        _emailController.text = creds['email'] ?? '';
        _passwordController.text = creds['password'] ?? '';
        if (!authProvider.rememberMe) {
          authProvider.toggleRememberMe(true);
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleObscure() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final bool success = await authProvider.login(email, password);
    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      // Show snackbar error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Authentication failed'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  Future<void> _loginAsGuest() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.loginAsGuest();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 700;

    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return Stack(
            children: [
              // Premium Background glow designs
              if (isDark) ...[
                Positioned(
                  top: -80,
                  left: -80,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCyan.withOpacity(0.12),
                          blurRadius: 100,
                          spreadRadius: 100,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  right: -80,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withOpacity(0.12),
                          blurRadius: 100,
                          spreadRadius: 100,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Main login layout
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header Logo/Icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? AppColors.primaryCyan.withOpacity(0.2) : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.electric_bolt_rounded,
                                  color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'EVHub Login',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Email Input
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
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
                          const SizedBox(height: 20),

                          // Password Input
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submitLogin(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: _toggleObscure,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Password is required';
                              }
                              if (!AuthService.validatePassword(val)) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Remember Me & Forgot Password Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Remember Me Checkbox
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: Checkbox(
                                      value: authProvider.rememberMe,
                                      onChanged: (val) {
                                        if (val != null) {
                                          authProvider.toggleRememberMe(val);
                                        }
                                      },
                                      activeColor: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                                      checkColor: isDark ? Colors.black : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => authProvider.toggleRememberMe(!authProvider.rememberMe),
                                    child: Text(
                                      'Remember Me',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Forgot Password Link
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.forgotPassword);
                                },
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                child: Text(
                                  'Forgot?',
                                  style: TextStyle(
                                    color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Submit Action Button
                          ElevatedButton(
                            onPressed: _submitLogin,
                            child: const Text('Log In'),
                          ),
                          const SizedBox(height: 16),

                          // Guest mode button
                          OutlinedButton(
                            onPressed: _loginAsGuest,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: isDark ? AppColors.primaryCyan.withOpacity(0.4) : AppColors.primaryPurple.withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              'Continue as Guest',
                              style: TextStyle(
                                color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Bottom Navigation to Signup
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Don\'t have an account? ',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, AppRoutes.signup);
                                },
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: isDark ? AppColors.primaryCyan : AppColors.primaryPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Full Screen Spinner Overlay during authentication
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
