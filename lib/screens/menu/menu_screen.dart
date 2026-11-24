import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profile/profile_screen.dart';
import 'nubify_information_screens.dart';
import '../faculties/nub_faculties_screen.dart';
import 'honorary_recognition_screen.dart';
import 'nubify_settings_screen.dart';
import '../profile/user_connections_screen.dart';
import '../../services/common/language_preference.dart';
import '../../widgets/menu/nubify_menu_components.dart';
import 'about_developer_screen.dart';
import 'explore_nub_screen.dart';
import 'nubify_support_screen.dart';
import '../huddles/huddles_screen.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// NUBIFY — PREMIUM MENU SCREEN
//===================================================

class MenuScreenController {
  VoidCallback? _resetCallback;

  void resetToTop() => _resetCallback?.call();
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, this.controller});

  final MenuScreenController? controller;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

//===================================================
// MENU STATE
//===================================================

class _MenuScreenState extends State<MenuScreen> {
  static const String _languagePreferenceKey = 'nubify_language_preference_v1';

  // Shared with login and signup.
  static const List<NubifyLanguage> _languages = LanguagePreference.options;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;
  final ScrollController _scrollController = ScrollController();

  bool _isSigningOut = false;

  String _languageCode = 'en';

  //===================================================
  // INITIALIZE USER PROFILE
  //===================================================

  @override
  void initState() {
    super.initState();
    widget.controller?._resetCallback = resetToTop;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _profileStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    }

    _loadLanguagePreference();
  }

  @override
  void didUpdateWidget(covariant MenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._resetCallback = null;
      widget.controller?._resetCallback = resetToTop;
    }
  }

  void resetToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    widget.controller?._resetCallback = null;
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguagePreference() async {
    String languageCode = 'en';

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      languageCode =
          preferences.getString(_languagePreferenceKey) ?? languageCode;

      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        final String remote = (snapshot.data()?['languagePreference'] ?? '')
            .toString()
            .trim();
        if (_languages.any((option) => option.code == remote)) {
          languageCode = remote;
          await preferences.setString(_languagePreferenceKey, remote);
        }
      }
    } catch (_) {
      // Keep English when preference storage is temporarily unavailable.
    }

    if (!mounted || !_languages.any((option) => option.code == languageCode)) {
      return;
    }

    setState(() => _languageCode = languageCode);
    // The profile may hold a newer choice (another phone).
    AppLanguage.code.value = languageCode;
  }

  String _emailIdentity(String? email) {
    final String cleanEmail = email?.trim() ?? '';
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return '';
    }

    return cleanEmail.substring(0, cleanEmail.indexOf('@')).trim();
  }

  Future<void> _saveLanguagePreference(String languageCode) async {
    if (_languageCode == languageCode) {
      return;
    }

    final String previous = _languageCode;
    setState(() => _languageCode = languageCode);
    // Switch the whole app straight away.
    AppLanguage.code.value = languageCode;

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      await preferences.setString(_languagePreferenceKey, languageCode);

      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          <String, dynamic>{'languagePreference': languageCode},
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _languageCode = previous);
      AppLanguage.code.value = previous;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Could not save language preference. Please retry.'),
          ),
        ),
      );
    }
  }

  Future<void> _chooseLanguage() async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      // Six languages with two lines each are taller than
      // the default sheet: let it grow and scroll.
      isScrollControlled: true,
      backgroundColor: NubifyMenuColors.surface(context),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        LanguagePreference.chooseTitle,
                        style: TextStyle(
                          color: NubifyMenuColors.primaryText(sheetContext),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        LanguagePreference.chooseTitleArabic,
                        style: TextStyle(
                          color: NubifyMenuColors.secondaryText(sheetContext),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final NubifyLanguage language in _languages)
                  ListTile(
                    onTap: () => Navigator.pop(sheetContext, language.code),
                    leading: NubifyIconTile(
                      icon: Symbols.translate_rounded,
                      fill: 1,
                      color: language.code == _languageCode
                          ? nubifySky
                          : NubifyPalette.slate,
                      size: 40,
                      iconSize: 21,
                    ),
                    title: Text(
                      language.nativeAndArabic,
                      style: TextStyle(
                        color: NubifyMenuColors.primaryText(sheetContext),
                        fontWeight: language.code == _languageCode
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                    subtitle: language.englishUnder == null
                        ? null
                        : Text(
                            language.englishUnder!,
                            style: TextStyle(
                              color: NubifyMenuColors.secondaryText(
                                sheetContext,
                              ),
                            ),
                          ),
                    trailing: language.code == _languageCode
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: nubifySky,
                          )
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await _saveLanguagePreference(selected);
    }
  }

  //===================================================
  // OPEN AN EXISTING OR NEW SCREEN
  //===================================================

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  //===================================================
  // FEATURE CURRENTLY UNAVAILABLE
  //===================================================

  void _unavailable(String title) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: NubifyMenuColors.surface(context),

      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const NubifyIconTile(
                icon: Icons.construction_rounded,
                color: NubifyPalette.amber,
                size: 56,
                iconSize: 28,
              ),

              const SizedBox(height: 16),

              Text(
                context.tr(title),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: NubifyMenuColors.primaryText(sheetContext),
                ),
              ),

              const SizedBox(height: 9),

              Text(
                context.tr(
                  'This feature is not available in the current version of Nubify yet.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NubifyMenuColors.secondaryText(sheetContext),
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 19),
            ],
          ),
        ),
      ),
    );
  }

  //===================================================
  // SECURE LOGOUT CONFIRMATION
  //===================================================

  Future<void> _confirmLogout() async {
    if (_isSigningOut) return;

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) => AlertDialog(
        backgroundColor: NubifyMenuColors.surface(dialogContext),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: NubifyPalette.crimson),

            SizedBox(width: 12),

            Text(context.tr('Log Out?')),
          ],
        ),

        content: Text(
          context.tr(
            'Are you sure you want to log out of your Nubify account?',
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },

            child: Text(context.tr('Cancel')),
          ),

          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NubifyPalette.crimson,
              foregroundColor: Colors.white,
            ),

            onPressed: () {
              Navigator.pop(dialogContext, true);
            },

            child: Text(context.tr('Log Out')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    //===================================================
    // START SIGN-OUT
    //===================================================

    setState(() {
      _isSigningOut = true;
    });

    try {
      // FirebaseAuth signOut triggers the authentication
      // listener in main.dart.
      //
      // main.dart will rebuild a session-keyed
      // MaterialApp and display the existing LoginScreen.
      //
      // The previous Navigator stack is discarded.

      await FirebaseAuth.instance.signOut();
    }
    //===================================================
    // FIREBASE SIGN-OUT ERROR
    //===================================================
    on FirebaseAuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to log out. Please retry.'),
        ),
      );
    }
    //===================================================
    // GENERAL SIGN-OUT ERROR
    //===================================================
    catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Unable to log out. Please check your connection and retry.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  //===================================================
  // MENU UI
  //===================================================

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColoredBox(
          color: NubifyMenuColors.background(context),

          child: SafeArea(
            top: false,

            child: ListView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),

              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),

              children: [
                //=====================================
                // MENU TITLE
                //=====================================

                Text(
                  context.tr('Menu'),
                  style: TextStyle(
                    color: NubifyMenuColors.primaryText(context),
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.6,
                  ),
                ),

                const SizedBox(height: 8),

                //=====================================
                // PROFILE CARD
                //=====================================
                _profileCard(),

                const SizedBox(height: 8),

                // Keep the appearance and language controls together as one
                // clear portrait section, matching the menu reference.
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: NubifyMenuColors.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: NubifyMenuColors.stroke(context)),
                  ),
                  child: Column(
                    children: <Widget>[
                      const NubifyAppearanceSelector(compact: true),
                      const SizedBox(height: 3),
                      _languagePreferenceCard(embedded: true),
                    ],
                  ),
                ),

                const SizedBox(height: 11),

                //=====================================
                // SHORTCUTS
                //=====================================
                _sectionDividerHeading('Shortcuts'),

                const SizedBox(height: 7),

                _shortcutGrid(),

                const SizedBox(height: 12),

                //=====================================
                // ABOUT
                //=====================================
                _sectionDividerHeading('About'),

                // Keep the section rhythm consistent with Shortcuts.
                const SizedBox(height: 7),

                _aboutSection(),

                const SizedBox(height: 24),

                //=====================================
                // BRAND FOOTER
                //=====================================
                Center(
                  child: Text(
                    context.tr('Nubify · Campus Social'),
                    style: TextStyle(
                      color: NubifyMenuColors.secondaryText(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        //===========================================
        // LOGOUT LOADING OVERLAY
        //===========================================
        if (_isSigningOut)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: .35),

              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 20),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,

                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),

                        SizedBox(width: 16),

                        Text(context.tr('Signing out…')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  //===================================================
  // PORTRAIT SECTION HEADING
  //===================================================

  Widget _sectionDividerHeading(String title) => Row(
    children: <Widget>[
      Text(
        context.tr(title),
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: NubifyMenuColors.primaryText(context),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Divider(height: 1, color: NubifyMenuColors.stroke(context)),
      ),
    ],
  );

  //===================================================
  // FIREBASE PROFILE CARD
  //===================================================

  Widget _profileCard() {
    final account = FirebaseAuth.instance.currentUser;

    if (account == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,

      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        final List<dynamic> nameCandidates = <dynamic>[
          data?['fullName'],
          data?['name'],
          data?['displayName'],
          account.displayName,
          _emailIdentity(account.email),
        ];
        final String fullName = nameCandidates
            .map((dynamic value) => (value ?? '').toString().trim())
            .firstWhere(
              (String value) =>
                  value.isNotEmpty && value.toLowerCase() != 'nubify member',
              orElse: () => 'Your profile',
            );

        final username =
            <dynamic>[data?['username'], _emailIdentity(account.email)]
                .map((dynamic value) => (value ?? '').toString().trim())
                .firstWhere(
                  (String value) => value.isNotEmpty,
                  orElse: () => '',
                );

        final photoUrl = (data?['photoUrl'] ?? account.photoURL ?? '')
            .toString()
            .trim();

        final verified = data?['isVerified'] == true;

        return _PressScale(
          onTap: () {
            _push(ProfileScreen(userId: account.uid));
          },

          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),

              gradient: NubifyMenuColors.isDark(context)
                  ? const LinearGradient(
                      colors: [Color(0xFF243950), Color(0xFF202D47)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFE5F4FF), Color(0xFFF4EFFF)],
                    ),

              border: Border.all(color: nubifySky.withValues(alpha: .22)),
            ),

            child: Row(
              children: [
                //===================================
                // PROFILE PICTURE
                //===================================

                Container(
                  width: 42,
                  height: 42,
                  clipBehavior: Clip.antiAlias,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NubifyMenuColors.surface(context),
                    border: Border.all(
                      color: nubifySky.withValues(alpha: .75),
                      width: 2.2,
                    ),
                  ),

                  child: photoUrl.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          color: nubifySky,
                          size: 24,
                        )
                      : Image.network(
                          photoUrl,
                          fit: BoxFit.cover,

                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.person_rounded,
                                color: nubifySky,
                                size: 24,
                              ),
                        ),
                ),

                const SizedBox(width: 11),

                //===================================
                // NAME AND USERNAME
                //===================================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              fullName,

                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,

                              style: TextStyle(
                                color: NubifyMenuColors.primaryText(context),
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),

                          if (verified) ...[
                            const SizedBox(width: 6),

                            const Icon(
                              Icons.verified_rounded,
                              color: nubifySky,
                              size: 19,
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 3),

                      Text(
                        username.isNotEmpty
                            ? '@$username'
                            : 'View your profile',

                        style: TextStyle(
                          color: NubifyMenuColors.secondaryText(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: nubifySky,
                  size: 21,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _languagePreferenceCard({bool embedded = false}) {
    final NubifyLanguage selected = LanguagePreference.byCode(_languageCode);

    return _PressScale(
      onTap: _chooseLanguage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: NubifyMenuColors.surface(context),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: embedded
                ? Colors.transparent
                : NubifyMenuColors.stroke(context),
          ),
        ),
        child: Row(
          children: <Widget>[
            const NubifyIconTile(
              icon: Symbols.translate_rounded,
              color: NubifyPalette.teal,
              size: 30,
              iconSize: 16,
              fill: 1,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    LanguagePreference.title,
                    style: TextStyle(
                      color: NubifyMenuColors.primaryText(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    selected.nativeWithEnglish,
                    style: TextStyle(
                      color: NubifyMenuColors.secondaryText(context),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: NubifyMenuColors.secondaryText(context),
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // TEN COLORFUL SHORTCUTS
  //===================================================

  Widget _shortcutGrid() {
    final items = <_MenuItem>[
      _MenuItem(
        'Find Friends & Users',
        Symbols.group_add_rounded,
        nubifySky,
        () => _push(const UserDirectoryScreen()),
      ),

      //===============================================
      // ROW 1
      //===============================================
      _MenuItem(
        'NUB Huddles',
        Symbols.podcasts_rounded,
        NubifyPalette.purple,
        () => _push(const HuddlesScreen()),
        picture: 'assets/menu_icons/studio_microphone_3d.png',
      ),

      _MenuItem(
        'NUB Trend',
        Symbols.insights_rounded,
        NubifyPalette.coral,
        () => _unavailable('NUB Trend'),
        picture: 'assets/menu_icons/rocket_3d.png',
      ),

      // Games will live here later.
      _MenuItem(
        'Game Hub',
        Symbols.stadia_controller_rounded,
        NubifyPalette.sapphire,
        () => _unavailable('Games'),
        picture: 'assets/menu_icons/video_game_3d.png',
      ),

      //===============================================
      // ROW 2
      //===============================================
      _MenuItem(
        'NUB Map',
        Symbols.location_on_rounded,
        NubifyPalette.red,
        () => _unavailable('Live 3D Map'),
      ),

      _MenuItem(
        'Verification Badges',
        Symbols.verified_rounded,
        const Color(0xFFD9A11E),
        () => _unavailable('Verification Badges'),
      ),

      //===============================================
      // ROW 3
      //===============================================
      _MenuItem(
        'Faculties & Programmes',
        Symbols.school_rounded,
        NubifyPalette.amber,
        () => _push(const NubFacultiesScreen()),
      ),

      _MenuItem(
        'Explore NUB',
        Symbols.photo_library_rounded,
        NubifyPalette.teal,
        () => _push(const ExploreNubScreen()),
        picture: 'assets/menu_icons/framed_picture_3d.png',
      ),

      //===============================================
      // ROW 4
      //===============================================
      _MenuItem(
        'The University',
        Symbols.location_city_rounded,
        NubifyPalette.indigo,
        () => _push(const NubUniversityScreen()),
        picture: 'assets/menu_icons/school_3d.png',
      ),

      _MenuItem(
        'Settings',
        Symbols.settings_rounded,
        NubifyPalette.slate,
        () => _push(const NubifySettingsScreen()),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 320 ? 1 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),

          itemCount: items.length,

          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 9,
            mainAxisSpacing: 8,
            mainAxisExtent: 66,
          ),

          itemBuilder: (context, index) {
            final item = items[index];

            final reduceMotion = MediaQuery.of(context).disableAnimations;

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),

              duration: reduceMotion
                  ? Duration.zero
                  : Duration(milliseconds: 210 + index * 35),

              curve: Curves.easeOutCubic,

              builder: (context, progress, child) => Opacity(
                opacity: progress,

                child: Transform.translate(
                  offset: Offset(0, (1 - progress) * 10),
                  child: child,
                ),
              ),

              child: _PressScale(
                onTap: item.onTap,

                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 7, 6),

                  decoration: BoxDecoration(
                    color: NubifyMenuColors.surface(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: NubifyMenuColors.stroke(context)),
                  ),

                  child: Row(
                    children: [
                      NubifyIconTile(
                        icon: item.icon,
                        color: item.color,
                        size: 35,
                        iconSize: 19,
                        image: item.picture,
                        fill: 1,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          context.tr(item.title),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(
                            fontSize: 12.2,
                            height: 1.22,
                            fontWeight: FontWeight.w700,
                            color: NubifyMenuColors.primaryText(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  //===================================================
  // ABOUT SECTION
  //===================================================

  Widget _aboutSection() {
    final items = <_MenuItem>[
      _MenuItem(
        'About the Developer',
        Symbols.person_pin_circle_rounded,
        NubifyPalette.violet,
        () => _push(const AboutDeveloperScreen()),
      ),

      _MenuItem(
        'About the App',
        Symbols.info_rounded,
        nubifySky,
        () => _push(const NubifyAboutAppScreen()),
      ),

      _MenuItem(
        'Honorary Recognition',
        Symbols.workspace_premium_rounded,
        NubifyPalette.amber,
        () => _push(const HonoraryRecognitionScreen()),
      ),

      _MenuItem(
        'Terms and Conditions',
        Symbols.contract_rounded,
        NubifyPalette.teal,
        () => _push(const NubifyLegalScreen(type: NubifyLegalType.terms)),
      ),

      _MenuItem(
        'Privacy Policy',
        Symbols.shield_lock_rounded,
        NubifyPalette.emerald,
        () => _push(const NubifyLegalScreen(type: NubifyLegalType.privacy)),
      ),

      _MenuItem(
        'Support',
        Symbols.support_agent_rounded,
        nubifySky,
        () => _push(const NubifySupportScreen()),
      ),

      _MenuItem(
        'Log Out',
        Symbols.logout_rounded,
        NubifyPalette.crimson,
        _confirmLogout,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: NubifyMenuColors.surface(context),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: NubifyMenuColors.stroke(context)),
      ),

      clipBehavior: Clip.antiAlias,

      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i == items.length - 1)
              Divider(
                height: 14,
                thickness: 1,
                color: NubifyMenuColors.stroke(context),
              ),

            _aboutRow(items[i], isLast: i == items.length - 1),

            if (i < items.length - 2)
              Padding(
                padding: const EdgeInsets.only(left: 73),
                child: Divider(
                  height: 1,
                  color: NubifyMenuColors.stroke(context),
                ),
              ),
          ],
        ],
      ),
    );
  }

  //===================================================
  // ABOUT ROW WITH COLORFUL ICON
  //===================================================

  Widget _aboutRow(_MenuItem item, {required bool isLast}) {
    return _PressScale(
      onTap: _isSigningOut ? null : item.onTap,

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),

        child: Row(
          children: [
            NubifyIconTile(
              icon: item.icon,
              color: item.color,
              size: 44,
              iconSize: 22,
              image: item.picture,
              fill: 1,
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Text(
                context.tr(item.title),

                style: TextStyle(
                  fontWeight: FontWeight.w600,

                  color: isLast
                      ? NubifyPalette.crimson
                      : NubifyMenuColors.primaryText(context),

                  fontSize: 15,
                ),
              ),
            ),

            if (!isLast)
              Icon(
                Icons.chevron_right_rounded,
                size: 21,
                color: NubifyMenuColors.secondaryText(context),
              ),
          ],
        ),
      ),
    );
  }
}

//===================================================
// MENU ITEM DATA
//===================================================

class _MenuItem {
  const _MenuItem(
    this.title,
    this.icon,
    this.color,
    this.onTap, {
    this.picture,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  // 3D picture from assets/menu_icons/, shown instead of the icon.
  final String? picture;
}

//===================================================
// ANIMATED PRESS-SCALE WIDGET
//===================================================

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,

      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onTap: widget.onTap,

        onTapDown: widget.onTap == null
            ? null
            : (_) {
                setState(() {
                  _pressed = true;
                });
              },

        onTapUp: widget.onTap == null
            ? null
            : (_) {
                setState(() {
                  _pressed = false;
                });
              },

        onTapCancel: widget.onTap == null
            ? null
            : () {
                setState(() {
                  _pressed = false;
                });
              },

        child: AnimatedScale(
          scale: _pressed ? .975 : 1,

          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 160),

          curve: Curves.easeOutCubic,

          child: widget.child,
        ),
      ),
    );
  }
}
