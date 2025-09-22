import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth.service.dart';
import 'services/fabrics.service.dart';
import 'services/templates.service.dart';
import 'services/api_client.dart';
import 'widgets/auth_wrapper.dart';
import 'screens/login.dart';
import 'screens/signup.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  ApiClient.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FabricsService()),
        ChangeNotifierProvider(create: (_) => TemplatesService()),
      ],
      child: MaterialApp(
        navigatorKey: AuthService.navigatorKey,
        title: 'Your App',
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
          '/login': (context) => const LoginPage(),
          '/signup': (context) => const SignupPage(),
        },
      ),
    );
  }
}
