import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nubify/firebase_options.dart';
import 'package:nubify/providers/user_provider.dart';
import 'package:nubify/responsive/mobile_screen_layout.dart';
import 'package:nubify/responsive/responsive_layout_screen.dart';
import 'package:nubify/responsive/web_screen_layout.dart';
import 'package:nubify/screens/login_screen.dart';
import 'package:nubify/screens/signup_screen.dart';
import 'package:nubify/utils/color.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDl7g6nF94iNevELPwv6b7TzMAFLyCin7E",
        projectId: "nubify-af91b",
        storageBucket: "nubify-af91b.firebasestorage.app",
        messagingSenderId: "69403007783",
        appId: "1:69403007783:web:a13f93c340cb9d2423e702",
      ),
    );
  } else {
    await Firebase.initializeApp();
   
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of my application
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => UserProvider(),
    ),
      ],
      child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nubify',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: mobileBackgroundColor,
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.hasData) {
              return const ResponsiveLayout(
                mobileScreenLayout: MobileScreenLayout(),
                webScreenLayout: WebScreenLayout(),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Text('${snapshot.error}'),
              );
            }
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            );
          }

          return const LoginScreen();
        },
      ),
      )
    );
  }
}