import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/user_provider.dart';

import 'responsive/mobile_screen_layout.dart';
import 'responsive/responsive_layout_screen.dart';
import 'responsive/web_screen_layout.dart';

import 'screens/feed/comment_screen.dart';
import 'screens/chat/groups/group_chat_screen.dart';
import 'screens/marketplace/marketplace_screen.dart';
import 'screens/marketplace/create_marketplace_listing_screen.dart';
import 'screens/marketplace/marketplace_listing_details_screen.dart';
import 'screens/marketplace/marketplace_reports_admin_screen.dart';
import 'screens/marketplace/my_marketplace_listings_screen.dart';
import 'screens/marketplace/saved_marketplace_listings_screen.dart';
import 'screens/stories/story_viewer_screen.dart';
import 'screens/feed/hidden_posts_screen.dart';
import 'screens/feed/post_engagements_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/auth/login_screen.dart';

import 'services/common/nubify_appearance_controller.dart';

import 'models/stories/story.dart';
import 'services/common/media_route_observer.dart';
import 'widgets/chat/incoming_call_listener.dart';
import 'widgets/links/nubify_deep_link_gate.dart';

import 'package:firebase_app_check/firebase_app_check.dart';


//===================================================
// MAIN
//===================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //===================================================
  // FIREBASE
  //===================================================

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDl7g6nF94iNevELPwv6b7TzMAFLyCin7E',
        projectId: 'nubify-af91b',
        storageBucket:
        'nubify-af91b.firebasestorage.app',
        messagingSenderId: '69403007783',
        appId:
        '1:69403007783:web:a13f93c340cb9d2423e702',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
    );
  }

  runApp(const MyApp());
}

//===================================================
// APP
//===================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  //===================================================
  // FIREBASE AUTHENTICATION STREAM
  //===================================================

  static final Stream<User?> _authStream =
  FirebaseAuth.instance.authStateChanges();

  //===================================================
  // EXISTING NUBIFY HOME LAYOUT
  //===================================================

  Widget _homeLayout() {
    return const IncomingCallListener(
      child: ResponsiveLayout(
        mobileScreenLayout:
        MobileScreenLayout(),

        webScreenLayout:
        WebScreenLayout(),
      ),
    );
  }

  //===================================================
  // ROUTES
  //===================================================

  Route<dynamic>? _onGenerateRoute(
      RouteSettings settings,
      ) {
    //=================================================
    // AUTHENTICATION ROUTE PROTECTION
    //=================================================

    if (settings.name == '/login' ||
        FirebaseAuth.instance.currentUser == null) {
      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) => const LoginScreen(),
      );
    }

    //=================================================
    // PROFILE
    //=================================================

    if (settings.name == '/profile') {
      final String? uid =
      settings.arguments is String
          ? (settings.arguments as String)
          .trim()
          : null;

      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) =>
            ProfileScreen(userId: uid),
      );
    }

    //=================================================
    // POST LINK
    //=================================================

    if (settings.name == '/post') {
      final String postId =
          settings.arguments
              ?.toString()
              .trim() ??
              '';

      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) => postId.isEmpty
            ? const _InvalidRouteScreen(
          title: 'Post',
          message:
          'The post could not be found.',
        )
            : CommentsScreen(
          postId: postId,
        ),
      );
    }

    //=================================================
    // STORY LINK
    //=================================================

    if (settings.name == '/story') {
      final String storyId =
          settings.arguments
              ?.toString()
              .trim() ??
              '';

      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) =>
            _StoryLinkLoaderScreen(
              storyId: storyId,
            ),
      );
    }

    //=================================================
    // GROUP LINK
    //=================================================

    if (settings.name == '/group') {
      final String groupId =
          settings.arguments
              ?.toString()
              .trim() ??
              '';

      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) => groupId.isEmpty
            ? const _InvalidRouteScreen(
          title: 'Group',
          message:
          'The group could not be found.',
        )
            : GroupChatScreen(
          groupId: groupId,
        ),
      );
    }

    //=================================================
    // MARKETPLACE LINK
    //=================================================

    if (settings.name == '/marketplace') {
      final String initialProductId =
          settings.arguments
              ?.toString()
              .trim() ??
              '';

      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) => MarketplaceScreen(
          initialProductId:
          initialProductId,
        ),
      );
    }

    //=================================================
    // MARKETPLACE LISTING DETAILS
    //=================================================

    if (settings.name ==
        '/marketplace/listing') {
      final String listingId =
          settings.arguments
              ?.toString()
              .trim() ??
              '';

      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) => listingId.isEmpty
            ? const _InvalidRouteScreen(
          title:
          'Marketplace Listing',
          message:
          'The listing could not be found.',
        )
            : MarketplaceListingDetailsScreen(
          listingId: listingId,
        ),
      );
    }

    //=================================================
    // CREATE MARKETPLACE LISTING
    //=================================================

    if (settings.name ==
        '/marketplace/create') {
      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) =>
        const CreateMarketplaceListingScreen(),
      );
    }

    //=================================================
    // MARKETPLACE ADMIN
    //=================================================

    if (settings.name ==
        '/marketplace/admin') {
      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) =>
        const MarketplaceReportsAdminScreen(),
      );
    }

    if (settings.name ==
        '/marketplace/admin/reports') {
      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) =>
        const MarketplaceReportsAdminScreen(),
      );
    }

    //=================================================
    // MY MARKETPLACE LISTINGS
    //=================================================

    if (settings.name ==
        '/marketplace/my-listings') {
      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) =>
        const MyMarketplaceListingsScreen(),
      );
    }

    //=================================================
    // SAVED MARKETPLACE LISTINGS
    //=================================================

    if (settings.name ==
        '/marketplace/saved') {
      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) =>
        const SavedMarketplaceListingsScreen(),
      );
    }

    //=================================================
    // HOME
    //=================================================

    if (settings.name == '/home') {
      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) => _homeLayout(),
      );
    }

    //=================================================
    // HIDDEN POSTS
    //=================================================

    if (settings.name ==
        '/hidden-posts') {
      final String? uid =
      settings.arguments is String
          ? (settings.arguments as String)
          .trim()
          : null;

      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) =>
            HiddenPostsScreen(
              userId: uid,
            ),
      );
    }

    //=================================================
    // POST ENGAGEMENTS
    //=================================================

    if (settings.name ==
        '/post-engagements') {
      String postId = '';

      int initialTab = 0;

      //===============================================
      // STRING ARGUMENT
      //===============================================

      if (settings.arguments is String) {
        postId =
            (settings.arguments as String)
                .trim();
      }

      //===============================================
      // MAP ARGUMENT
      //===============================================

      if (settings.arguments is Map) {
        final Map<dynamic, dynamic> arguments =
        settings.arguments
        as Map<dynamic, dynamic>;

        postId =
            (arguments['postId'] ?? '')
                .toString()
                .trim();

        final dynamic rawTab =
        arguments['initialTab'];

        if (rawTab is int) {
          initialTab = rawTab;
        } else if (rawTab is num) {
          initialTab = rawTab.toInt();
        } else {
          initialTab = int.tryParse(
            rawTab?.toString() ?? '',
          ) ??
              0;
        }
      }

      //===============================================
      // VALID TAB RANGE
      //===============================================

      if (initialTab < 0) {
        initialTab = 0;
      }

      if (initialTab > 1) {
        initialTab = 1;
      }

      //===============================================
      // INVALID POST
      //===============================================

      if (postId.isEmpty) {
        return MaterialPageRoute<void>(
          settings: settings,

          builder: (_) =>
          const _InvalidRouteScreen(
            title: 'Post Engagements',
            message:
            'The post could not be found.',
          ),
        );
      }

      return MaterialPageRoute<void>(
        settings: settings,

        builder: (_) =>
            PostEngagementsScreen(
              postId: postId,
              initialTab: initialTab,
            ),
      );
    }

    return null;
  }

  //===================================================
  // NUBIFY GLOBAL LIGHT & DARK THEME
  //===================================================

  ThemeData _appTheme(
      Brightness brightness,
      ) {
    final bool isDark =
        brightness == Brightness.dark;

    final scheme =
    ColorScheme.fromSeed(
      seedColor:
      const Color(0xFF29B6F6),
      brightness: brightness,

      surface: isDark
          ? const Color(0xFF1C2735)
          : Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,

      scaffoldBackgroundColor: isDark
          ? const Color(0xFF101824)
          : const Color(0xFFF5F7FB),

      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF101824)
            : const Color(0xFFF5F7FB),

        foregroundColor: isDark
            ? Colors.white
            : const Color(0xFF202D40),

        elevation: 0,
        surfaceTintColor:
        Colors.transparent,
      ),

      cardTheme: CardThemeData(
        color: isDark
            ? const Color(0xFF1C2735)
            : Colors.white,

        elevation: 0,
      ),
    );
  }

  //===================================================
  // BUILD APPLICATION
  //===================================================

  @override
  Widget build(BuildContext context) {
    //=================================================
    // GLOBAL APPEARANCE PROVIDER
    //=================================================

    return ChangeNotifierProvider<
        NubifyAppearanceController>(
      create: (_) =>
          NubifyAppearanceController(),

      child:
      Consumer<NubifyAppearanceController>(
        builder: (
            context,
            appearance,
            _,
            ) {
          //===========================================
          // AUTHENTICATION STATE LISTENER
          //===========================================

          return StreamBuilder<User?>(
            stream: _authStream,

            builder: (context, snapshot) {
              final bool loading =
                  snapshot.connectionState !=
                      ConnectionState.active;

              final User? authenticatedUser =
                  snapshot.data;

              //=====================================
              // SESSION IDENTITY KEY
              //=====================================

              final String sessionKey =
              loading
                  ? 'loading'
                  : (authenticatedUser?.uid ??
                  'signed-out');

              //=====================================
              // USER PROVIDER
              //=====================================

              return ChangeNotifierProvider<
                  UserProvider>(
                key: ValueKey<String>(
                  'user-provider-$sessionKey',
                ),

                create: (_) =>
                    UserProvider(),

                child: MaterialApp(
                  //=================================
                  // IMPORTANT:
                  // A different authentication
                  // session creates a new Navigator.
                  //
                  // Old protected routes and
                  // authenticated widgets are
                  // discarded after logout.
                  //=================================

                  key: ValueKey<String>(
                    'nubify-session-$sessionKey',
                  ),

                  debugShowCheckedModeBanner:
                  false,

                  title: 'Nubify',

                  // LIGHT THEME
                  theme: _appTheme(
                    Brightness.light,
                  ),

                  // DARK THEME
                  darkTheme: _appTheme(
                    Brightness.dark,
                  ),

                  // SELECTED THEME
                  themeMode:
                  appearance.mode,

                  // EXISTING NAMED ROUTES
                  onGenerateRoute:
                  _onGenerateRoute,

                  // MEDIA ROUTE OBSERVERS
                  navigatorObservers:
                  authenticatedUser == null
                      ? <NavigatorObserver>[]
                      : <NavigatorObserver>[
                    nubifyMediaRouteObserver,
                  ],

                  //=================================
                  // AUTHENTICATION GATE
                  //=================================

                  home: NubifyDeepLinkGate(
                    child: loading
                        ? const Scaffold(
                      body: Center(
                        child:
                        CircularProgressIndicator(),
                      ),
                    )

                    // AUTHENTICATION ERROR
                        : snapshot.hasError
                        ? Scaffold(
                      body: Center(
                        child: Text(
                          'Unable to check your login status: ${snapshot.error}',
                        ),
                      ),
                    )

                    //=======================
                    // SIGNED OUT
                    //=======================

                        : authenticatedUser ==
                        null
                        ? const LoginScreen()

                    //===================
                    // SIGNED IN
                    //===================

                        : _homeLayout(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

//===================================================
// INVALID ROUTE SCREEN
//===================================================

class _InvalidRouteScreen
    extends StatelessWidget {
  const _InvalidRouteScreen({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),

      body: Center(
        child: Padding(
          padding:
          const EdgeInsets.all(24),

          child: Column(
            mainAxisSize:
            MainAxisSize.min,

            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 54,
                color:
                Color(0xFF29B6F6),
              ),

              const SizedBox(height: 14),

              Text(
                message,
                textAlign: TextAlign.center,

                style: const TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const SizedBox(height: 18),

              FilledButton.icon(
                onPressed: () {
                  if (Navigator.of(context)
                      .canPop()) {
                    Navigator.of(context)
                        .pop();
                    return;
                  }

                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(
                    '/home',
                        (Route<dynamic> route) =>
                    false,
                  );
                },

                icon: const Icon(
                  Icons.arrow_back_rounded,
                ),

                label:
                const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//===================================================
// STORY LINK LOADER
//===================================================

class _StoryLinkLoaderScreen
    extends StatelessWidget {
  const _StoryLinkLoaderScreen({
    required this.storyId,
  });

  final String storyId;

  @override
  Widget build(BuildContext context) {
    if (storyId.trim().isEmpty) {
      return const _InvalidRouteScreen(
        title: 'Story',
        message:
        'The Story could not be found.',
      );
    }

    return FutureBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .get(),

      builder: (
          BuildContext context,
          AsyncSnapshot<
              DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
        //===========================================
        // LOADING
        //===========================================

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor:
            Colors.black,

            body: Center(
              child:
              CircularProgressIndicator(
                color:
                Color(0xFF29B6F6),
              ),
            ),
          );
        }

        //===========================================
        // STORY NOT FOUND
        //===========================================

        if (!snapshot.hasData ||
            !snapshot.data!.exists) {
          return const _InvalidRouteScreen(
            title: 'Story',
            message:
            'This Story is no longer available.',
          );
        }

        //===========================================
        // OPEN EXISTING STORY VIEWER
        //===========================================

        try {
          final NubifyStory story =
          NubifyStory.fromFirestore(
            snapshot.data!,
          );

          return StoryViewerScreen(
            stories: <NubifyStory>[
              story,
            ],

            allowExpiredStories: true,
          );
        } catch (_) {
          return const _InvalidRouteScreen(
            title: 'Story',
            message:
            'Unable to open this Story.',
          );
        }
      },
    );
  }
}