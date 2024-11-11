import 'package:cryptox/crypto/crypto_provider.dart';
import 'package:cryptox/pages/first/login_page.dart';
import 'package:cryptox/pages/second/page_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CryptoProvider(),
        ),
      ],
      child: const Main(),
    ),
  );
}

class Main extends StatelessWidget {
  const Main({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cryptox',
      theme: ThemeData(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: Colors.greenAccent,
            fontFamily: 'Source Code Pro',
            letterSpacing: 1.2,
          ),
          bodyMedium: TextStyle(
            color: Colors.greenAccent,
            fontFamily: 'Source Code Pro',
            letterSpacing: 1.2,
          ),
        ),
      ),
      home: FirebaseAuth.instance.currentUser != null
          ? const MainPage()
          : const LoginPage(),
    );
  }
}
