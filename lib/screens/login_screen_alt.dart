import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Alternate login screen based on Stitch design:
/// Project ID: 14485259789386925154
/// Screen ID: 96c853dc1ca2417daa3400041ffd6cd6
/// Screen name: Login Screen with Help Section
class LoginScreenAlt extends StatefulWidget {
  const LoginScreenAlt({super.key});

  @override
  State<LoginScreenAlt> createState() => _LoginScreenAltState();
}

class _LoginScreenAltState extends State<LoginScreenAlt> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  static const _primaryBlue = Color(0xFF2B8CEE);
  static const _darkText = Color(0xFF101922);
  static const _subtleText = Color(0xFF64748B);
  static const _labelText = Color(0xFF334155);
  static const _hintText = Color(0xFF94A3B8);
  static const _borderColor = Color(0xFFE2E8F0);
  static const _bgLight = Color(0xFFF6F7F8);

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();

      final success = await authProvider.login(
        _userIdController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        context.go('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildTopBar(context),
                _buildWelcomeHeader(),
                const SizedBox(height: 40),
                _buildFormSection(),
                const SizedBox(height: 40),
                _buildFooterSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _darkText),
            onPressed: () => context.go('/landing'),
          ),
          const Expanded(
            child: Text(
              'Sign In',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkText,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _primaryBlue.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(48),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Login to your account to continue',
            style: TextStyle(
              fontSize: 16,
              color: _subtleText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username field
          const Text(
            'Username',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _labelText,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _userIdController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Enter your username',
              prefixIcon: const Icon(Icons.person_outline, size: 22),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your user ID';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password field
          const Text(
            'Password',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _labelText,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline, size: 22),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),

          // Forgot password link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {}, // TODO: implement forgot password
              child: const Text(
                'Forgot password?',
                style: TextStyle(color: _primaryBlue),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Login button
          Consumer<AuthProvider>(
            builder: (context, auth, child) {
              return SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: _primaryBlue.withOpacity(0.4),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Login',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.login, size: 20),
                          ],
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        children: [
          // Back to home link
          TextButton(
            onPressed: () => context.go('/landing'),
            child: const Text(
              'Back to Home',
              style: TextStyle(color: _subtleText),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(indent: 40, endIndent: 40),
          const SizedBox(height: 16),

          // Help section
          TextButton(
            onPressed: () {}, // TODO: implement help dialog
            child: const Text(
              'Need help?',
              style: TextStyle(color: _subtleText),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Tip: Use a strong, unique password to keep your account secure.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _hintText,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
