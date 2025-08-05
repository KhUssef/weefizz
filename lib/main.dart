import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth.service.dart';
import 'services/materials.service.dart';
import 'services/templates.service.dart';
import 'services/api_client.dart';
import 'widgets/auth_wrapper.dart';
import 'screens/login.dart';
import 'screens/signup.dart';

void main() {
  ApiClient.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => MaterialsService()),
        ChangeNotifierProvider(create: (_) => TemplatesService()),
      ],
      child: MaterialApp(
        navigatorKey: AuthService.navigatorKey,
        title: 'Your App',
        initialRoute: '/',
        routes: {
          '/': (context) => AuthWrapper(),
          '/login': (context) => LoginPage(),
          '/signup': (context) => SignupPage(),
        },
      ),
    );
  }
}
