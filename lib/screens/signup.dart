import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:weefizz/services/auth.service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
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
                    // Logo container matching login page
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
                'Créez votre compte',
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
                      onTap: () => _handleAppleSignup(),
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
                      onTap: () => _handleGoogleSignup(),
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

              // Username Field
              const Text(
                'Nom d\'utilisateur',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'david123',
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

              const SizedBox(height: 24),

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

              // Signup Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _acceptTerms ? () => _handleSignup() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C6BC0),
                    disabledBackgroundColor: const Color(0xFFE0E0E0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Créer un compte',
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
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Vous avez déjà un compte? Connectez-vous',
                  style: TextStyle(color: Color(0xFF757575)),
                ),
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

  void _handleAppleSignup() {
    // Implement Apple signup logic
    debugPrint('Apple signup tapped');
  }

  void _handleGoogleSignup() {
    // Implement Google signup logic
    debugPrint('Google signup tapped');
  }

  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    // You'll need to update your AuthService.signup method to accept username
    final success = await AuthService.signup(email, password, username);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compte créé avec succès !')),
      );
      Navigator.pop(context); // Return to login on success
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de la création du compte')),
      );
    }
  }
}