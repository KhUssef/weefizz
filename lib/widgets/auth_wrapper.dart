import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth.service.dart';
import '../screens/login.dart';
import '../screens/main_navigation.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
  if (authService.connected) {
          return MainNavigationScreen.shell();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}