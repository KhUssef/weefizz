import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth.service.dart';
import '../screens/login.dart';
import '../screens/home.dart';

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.connected) {
          return HomeScreen(); // or your main app widget
        } else {
          return LoginPage();
        }
      },
    );
  }
}