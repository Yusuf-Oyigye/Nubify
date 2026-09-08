import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

import 'providers/user_provider.dart';

import 'responsive/mobile_screen_layout.dart';
import 'responsive/responsive_layout_screen.dart';
import 'responsive/web_screen_layout.dart';

import 'screens/profile_screen.dart';
import 'screens/signup_screen.dart';

import 'utils/color.dart';

//===================================================
// MAIN
//===================================================

Future<void> main() async {
  WidgetsFlutterBinding
      .ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options:
      const FirebaseOptions(
        apiKey:
        'AIzaSyDl7g6nF94iNevELPwv6b7TzMAFLyCin7E',

        projectId:
        'nubify-af91b',

        storageBucket:
        'nubify-af91b.firebasestorage.app',

        messagingSenderId:
        '69403007783',

        appId:
        '1:69403007783:web:a13f93c340cb9d2423e702',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(
    const MyApp(),
  );
}

//===================================================
// APP
//===================================================

class MyApp
    extends StatelessWidget {
  const MyApp({
    super.key,
  });

  //===================================================
  // HOME
  //===================================================

  Widget _homeLayout() {
    return const ResponsiveLayout(
      mobileScreenLayout:
      MobileScreenLayout(),

      webScreenLayout:
      WebScreenLayout(),
    );
  }

  //===================================================
  // ROUTES
  //===================================================

  Route<dynamic>?
  _onGenerateRoute(
      RouteSettings settings,
      ) {
    //=================================================
    // PROFILE
    //=================================================

    if (settings.name ==
        '/profile') {
      final String? uid =
      settings.arguments
      is String
          ? (settings.arguments
      as String)
          .trim()
          : null;

      return MaterialPageRoute<void>(
        settings:
        settings,

        builder:
            (_) =>
            ProfileScreen(
              userId:
              uid,
            ),
      );
    }

    //=================================================
    // HOME
    //=================================================

    if (settings.name ==
        '/home') {
      return MaterialPageRoute<void>(
        settings:
        settings,

        builder:
            (_) =>
            _homeLayout(),
      );
    }

    return null;
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return MultiProvider(
      providers:
      [
        ChangeNotifierProvider<
            UserProvider>(
          create:
              (_) =>
              UserProvider(),
        ),
      ],

      child:
      MaterialApp(
        debugShowCheckedModeBanner:
        false,

        title:
        'Nubify',

        theme:
        ThemeData.dark()
            .copyWith(
          scaffoldBackgroundColor:
          mobileBackgroundColor,
        ),

        onGenerateRoute:
        _onGenerateRoute,

        home:
        StreamBuilder<User?>(
          stream:
          FirebaseAuth.instance
              .authStateChanges(),

          builder:
              (
              BuildContext context,

              AsyncSnapshot<User?>
              snapshot,
              ) {
            if (snapshot
                .connectionState ==
                ConnectionState
                    .active) {
              if (snapshot.hasData) {
                return _homeLayout();
              }

              if (snapshot.hasError) {
                return Center(
                  child:
                  Text(
                    '${snapshot.error}',
                  ),
                );
              }
            }

            if (snapshot
                .connectionState ==
                ConnectionState
                    .waiting) {
              return const Center(
                child:
                CircularProgressIndicator(
                  color:
                  primaryColor,
                ),
              );
            }

            return const SignupScreen();
          },
        ),
      ),
    );
  }
}