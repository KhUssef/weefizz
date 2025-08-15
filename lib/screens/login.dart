import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:weefizz/services/auth.service.dart';
import 'signup.dart';
import 'main_navigation.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptTerms = false;
  final AuthService authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Logo Section
              Center(
                child: Column(
                  children: [
                    // Placeholder logo - replace with your actual logo
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E676), Color(0xFF2196F3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.bubble_chart_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'WeeFizz',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          TextSpan(
                            text: '\nCreator',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF5C6BC0),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Title
              const Text(
                'Connectez-vous à votre compte',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A237E),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Social Login Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildSocialButton(
                      onTap: () => _handleAppleLogin(),
                      child: SvgPicture.asset(
                        'assets/apple.svg',
                        height: 24,
                        width: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSocialButton(
                      onTap: () => _handleGoogleLogin(),
                      child: SvgPicture.asset(
                        'assets/google.svg',
                        height: 24,
                        width: 24,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Divider
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'ou',
                      style: TextStyle(color: Color(0xFF757575), fontSize: 14),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                ],
              ),

              const SizedBox(height: 24),

              // Email Field
              const Text(
                'Adresse mail',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'dupondavid@gmail.com',
                  hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Password Field
              const Text(
                'Mot de passe',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'min. 8 caractères',
                  hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: const Color(0xFFBDBDBD),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Forgot Password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _handleForgotPassword(),
                  child: const Text(
                    'Forgot your password?',
                    style: TextStyle(color: Color(0xFF757575), fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Terms Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) {
                      setState(() {
                        _acceptTerms = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF5C6BC0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'En sélectionnant cette option, j\'accepte la politique de confidentialité et les CGU de WeeFizz et nos conditions d\'utilisation.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Login Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _acceptTerms ? () => _handleLogin() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C6BC0),
                    disabledBackgroundColor: const Color(0xFFE0E0E0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Connexion',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignupPage()),
                  );
                },
                child: const Text("Don't have an account? Sign up"),
              ),

              const SizedBox(height: 24),

              // Footer Text
              const Text(
                'Toutes les données sont cryptées dans les deux sens, sécurisées par SSL et ne sont jamais partagées avec qui que ce soit.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF757575),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }

  void _handleAppleLogin() {
    // Implement Apple login logic
    debugPrint('Apple login tapped');
  }

  void _handleGoogleLogin() {
    // Implement Google login logic
    debugPrint('Google login tapped');
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      await authService.login(email, password);

      // Hide loading indicator
      if (mounted) Navigator.of(context).pop();

      if (authService.connected) {
        // Success - Show success message and navigate to home
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connexion réussie !'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to home screen and remove login from stack
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MainNavigationScreen()),
          );
        }
      } else {
        // Failed - Show specific error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authService.lastError ?? 'Échec de la connexion'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading indicator
      if (mounted) Navigator.of(context).pop();

      // Show generic error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une erreur est survenue. Veuillez réessayer.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    // Implement forgot password logic
    debugPrint("Forgot password tapped");
  }
}
