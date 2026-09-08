import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../screens/egyptian_arabic_screen.dart';
import '../screens/home_screen.dart';
import '../screens/marketplace_screen.dart';
import '../screens/menu_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/nub_ai_tutor_screen.dart';
import '../screens/nubuzz_screen.dart';
import '../screens/profile_screen.dart';

//===================================================
// MOBILE SCREEN LAYOUT
//===================================================

class MobileScreenLayout extends StatefulWidget {
  const MobileScreenLayout({super.key});

  @override
  State<MobileScreenLayout> createState() => _MobileScreenLayoutState();
}

//===================================================
// MOBILE SCREEN LAYOUT STATE
//===================================================

class _MobileScreenLayoutState extends State<MobileScreenLayout> {
  int _page = 0;

  final String _aiTutorIcon =
      'https://img.icons8.com/?size=100&id=9inONWn9EvfI&format=png&color=000000';

  final String _nubuzzIcon =
      'https://img.icons8.com/?size=100&id=auxN3eox5Uvi&format=png&color=000000';

  final String _egyptianArabicIcon =
      'https://img.icons8.com/?size=100&id=w_qRMJOKoZGs&format=png&color=000000';

  final String _notificationsIcon =
      'https://img.icons8.com/?size=100&id=F5WMYjiT3vpJ&format=png&color=000000';

  final String _marketplaceIcon =
  'https://img.icons8.com/?size=100&id=fhk2K3BpkLYx&format=png&color=000000';
  //===================================================
  // HOME KEY
  //===================================================

  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  //===================================================
  // NUBUZZ KEY
  //===================================================

  final GlobalKey<NubuzzScreenState> _nubuzzKey =
      GlobalKey<NubuzzScreenState>();

  //===================================================
  // PAGES
  //===================================================

  late final List<Widget> _pages = <Widget>[
    HomeScreen(key: _homeKey),
    const NUBAiTutorScreen(),
    NubuzzScreen(key: _nubuzzKey, onBackToHome: _goHomeFromNubuzz),
    const EgyptianArabicScreen(),
    const MenuScreen(),
  ];

  //===================================================
  // NUBUZZ BACK TO HOME
  //===================================================

  void _goHomeFromNubuzz() {
    if (!mounted) {
      return;
    }

    setState(() {
      _page = 0;
    });
  }

  //===================================================
  // PAGE CHANGED
  //===================================================

  void onPageChanged(int page) {
    if (!mounted) {
      return;
    }

    //===================================================
    // HOME TAP
    //===================================================

    if (page == 0) {
      if (_page != 0) {
        setState(() {
          _page = 0;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _homeKey.currentState?.reshuffleFeed();
      });

      return;
    }

    //===================================================
    // NUBUZZ TAP AGAIN = REFRESH
    //===================================================

    if (_page == 2 && page == 2) {
      _nubuzzKey.currentState?.refreshFeed();

      return;
    }

    setState(() {
      _page = page;
    });
  }

  //===================================================
  // TOP PROFILE BUTTON
  //
  // STREAMS CURRENT USER DOC SO PROFILE PICTURE
  // CHANGES IMMEDIATELY AFTER EDIT PROFILE.
  //===================================================

  Widget _buildTopProfileButton() {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return _profileAction(photoUrl: '', uid: '');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic>? data = snapshot.data?.data();

            final String photoUrl = (data?['photoUrl'] ?? '').toString().trim();

            return _profileAction(photoUrl: photoUrl, uid: currentUser.uid);
          },
    );
  }

  //===================================================
  // PROFILE ACTION
  //===================================================

  Widget _profileAction({required String photoUrl, required String uid}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ProfileScreen(userId: uid.isEmpty ? null : uid),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF29B6F6), width: 1.2),
              ),
              clipBehavior: Clip.antiAlias,
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return const Icon(
                              Icons.person_rounded,
                              size: 17,
                              color: Color(0xFF29B6F6),
                            );
                          },
                    )
                  : const Icon(
                      Icons.person_rounded,
                      size: 17,
                      color: Color(0xFF29B6F6),
                    ),
            ),

            const Text('Profile', style: TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //===================================================
      // NUBUZZ HAS ITS OWN HEADER
      //===================================================

      appBar: _page == 2
          ? null
          : AppBar(
              //============================
              // SAME BACKGROUND AS HOME
              //============================

              backgroundColor: Theme.of(context).scaffoldBackgroundColor,

              surfaceTintColor: Colors.transparent,

              elevation: 0,

              scrolledUnderElevation: 0,

              automaticallyImplyLeading: false,
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Nubify',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Color(0xFF29B6F6),
                    ),
                  ),
                  Text(
                    'Campus Social',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF29B6F6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                //===================================================
                // MARKET
                //===================================================

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const MarketplaceScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Image.network(
                          _marketplaceIcon,
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.storefront_outlined,
                              size: 20,
                              color: Color(0xFF29B6F6),
                            );
                          },
                        ),
                        const Text('Market', style: TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),

                //===================================================
                // CHAT
                //===================================================
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ChatScreen(),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.chat_bubble_outline_rounded, size: 24),
                        Text('Chat', style: TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),

                //===================================================
                // NOTIFICATIONS
                //===================================================
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Image.network(
                          _notificationsIcon,
                          width: 24,
                          height: 24,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.notifications_none,
                              size: 20,
                            );
                          },
                        ),
                        const Text(
                          'Notifications',
                          style: TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                ),

                //===================================================
                // PROFILE
                //===================================================
                _buildTopProfileButton(),

                const SizedBox(width: 12),
              ],
            ),

      //===================================================
      // PAGE
      //===================================================
      body: _pages[_page],

      //===================================================
      // BOTTOM NAVIGATION
      //===================================================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _page,
        onTap: onPageChanged,
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),

          BottomNavigationBarItem(
            icon: Image.network(
              _aiTutorIcon,
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) {
                return const Icon(Icons.smart_toy_outlined);
              },
            ),
            label: 'NUBi',
          ),

          BottomNavigationBarItem(
            icon: Image.network(
              _nubuzzIcon,
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) {
                return const Icon(Icons.play_circle_outline);
              },
            ),
            label: 'NUBuzz',
          ),

          BottomNavigationBarItem(
            icon: Image.network(
              _egyptianArabicIcon,
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) {
                return const Icon(Icons.language);
              },
            ),
            label: 'EGP Arabic',
          ),

          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Menu',
          ),
        ],
      ),
    );
  }
}
