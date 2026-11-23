import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/common/nubify_contact.dart';
import '../../utils/faculties/faculty_catalog.dart';
import '../../widgets/menu/nubify_honor_widgets.dart';

//===================================================
// YOUR DETAILS — EDIT ONLY THIS PART
//===================================================

class _Developer {
  static const String name = 'Yusuf Oyigye';
  static const String handle = '@Digitaldoc';

  // Must match a faculty name from sign up, so the same
  // faculty icon and colour appear here as on profiles.
  static const String faculty = 'Faculty of Medicine';

  static const String roleLine = 'Founder / Developer / Super-Admin of Nubify';

  // Shown until you pick a new photo inside the app. The
  // square frame shows the top part; tapping shows it all.
  static const String photoAsset = 'assets/images/my_pic.jpg';
  static const Alignment photoFocus = Alignment(0, -.7);

  // Your Nubify user id. When filled, a "View my Nubify
  // profile" button appears at the bottom.
  static const String nubifyUid = '';

  // The story, one paragraph per item.
  static const List<String> story = [
    'Yusuf Muhammad Oyigye, also known as Digitaldoc, is a Nigerian student '
        'of the Faculty of Medicine and Surgery with a strong interest in tech '
        'and a passion for learning new things.',
    'The idea behind Nubify came from different life experiences, personal '
        'observations and challenges encountered around campus. As a student, '
        'I started imagining how university life could become more connected, '
        'engaging and convenient if there was a platform where students could '
        'interact beyond the classroom, share experiences, exchange ideas and '
        'build meaningful connections.',
    'My vision was never simply to build another application or social media '
        'platform. I wanted to create something meaningful, something that '
        'could bring students together and strengthen the bond within our '
        'university.',
    'My goal is to unite and connect NUB students digitally, regardless of '
        'their faculty, nationality, race, religion or cultural background. I '
        'believe that despite our differences, we all share something in '
        'common: we are part of the same university community.',
    'Building Nubify while pursuing Medicine and Surgery has not always been '
        'easy. Balancing academics with learning and working on tech '
        'comes with its own challenges. There have been moments of '
        'uncertainty, mistakes and plenty of things to figure out along the '
        'way. But through consistency, determination and a willingness to keep '
        'learning, I have continued moving forward.',
    "I don't claim to know everything, and I'm still learning every day. But "
        'one thing I have come to believe is that you don\'t have to know '
        "everything before you start working towards something you've always "
        'imagined.',
    'What started as a delusion, imagination, an idea that sometimes seemed like a '
        'distant dream, has gradually become a reality.',
    'Nubify is more than just an application to me. It represents an idea, a '
        'passion, a personal journey and my little contribution to the '
        'community I belong to.',
    'I know there is still a long way to go, and Nubify has plenty of room to '
        'grow and improve.',
  ];

  static const String motto =
      'One university. Different backgrounds. One connected community.';
  static const String welcome = 'Welcome to Nubify — Campus Social.';
  static const String signOff =
      'Built with passion. Driven by consistency. Inspired by community.';

  // WhatsApp and Gmail come from NubifyContact
  // (lib/utils/common/nubify_contact.dart).
  static final String whatsapp = NubifyContact.whatsapp(
    'Hello Digitaldoc 👋 I am reaching out from Nubify.',
  ).toString();
  static final String gmail = NubifyContact.email;
}

//===================================================
// NUBIFY — ABOUT THE DEVELOPER
//===================================================

class AboutDeveloperScreen extends StatelessWidget {
  const AboutDeveloperScreen({super.key});

  //===================================================
  // ACTIONS
  //===================================================

  Future<void> _openLink(
      BuildContext context,
      String link,
      String label,
      ) async {
    if (link.trim().isEmpty) {
      _snack(context, '$label link coming soon');
      return;
    }

    bool opened = false;

    try {
      final Uri? uri = Uri.tryParse(link.trim());

      if (uri != null) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      opened = false;
    }

    if (!opened && context.mounted) {
      _snack(context, 'Could not open $label');
    }
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status-bar icons over the dark header.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: NubifyHonorColors.page(context),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NubifyReveal(
                      delay: const Duration(milliseconds: 250),
                      child: _buildStory(context),
                    ),
                    NubifyReveal(
                      delay: const Duration(milliseconds: 330),
                      child: _buildSocials(context),
                    ),
                    if (_Developer.nubifyUid.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _buildProfileButton(context),
                    ],
                    const SizedBox(height: 32),
                    _buildFooter(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //===================================================
  // HERO HEADER
  //===================================================

  Widget _buildHero(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NubifyHonorColors.ink,
              NubifyHonorColors.inkSoft,
              Color(0xFF2A2210),
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -90,
              right: -70,
              child: NubifyGlow(color: NubifyHonorColors.gold, size: 270),
            ),
            const Positioned(
              bottom: -110,
              left: -80,
              child: NubifyGlow(color: NubifyHonorColors.goldDeep, size: 250),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 18, 30),
                child: Column(
                  children: [
                    const NubifyHeaderBar(title: 'About the Developer'),
                    const SizedBox(height: 16),
                    const NubifyReveal(child: _DeveloperPhoto(size: 136)),
                    const SizedBox(height: 20),
                    NubifyReveal(
                      delay: const Duration(milliseconds: 80),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _Developer.name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .3,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              NubifyVerifiedSeal(
                                tone: NubifySealTone.gold,
                                size: 24,
                                shimmer: true,
                                message: 'Verified founder of Nubify',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            _Developer.handle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: NubifyHonorColors.goldLight,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _FacultyChip(faculty: _Developer.faculty),
                          const SizedBox(height: 16),
                          const _RoleLine(text: _Developer.roleLine),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // THE STORY BEHIND NUBIFY
  //===================================================

  Widget _buildStory(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: NubifyHonorColors.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NubifyHonorColors.line(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _Developer.story.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Text(
              _Developer.story[i],
              style: TextStyle(
                color: NubifyHonorColors.text(context),
                fontSize: i == 0 ? 16.5 : 15,
                height: 1.7,
                fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(height: 22),
          const _ClosingPanel(),
        ],
      ),
    );
  }

  //===================================================
  // CONTACT — WHATSAPP AND GMAIL
  //===================================================

  Widget _buildSocials(BuildContext context) {
    final List<_SocialLink> links = [
      _SocialLink(
        label: 'WhatsApp',
        action: NubifyContact.whatsappDisplay,
        logo: const FaIcon(
          FontAwesomeIcons.whatsapp,
          color: Colors.white,
          size: 20,
        ),
        link: _Developer.whatsapp,
        colors: const [Color(0xFF25D366), Color(0xFF128C7E)],
      ),
      _SocialLink(
        label: 'Gmail',
        action: _Developer.gmail,
        logo: const Icon(Icons.mail_rounded, color: Colors.white, size: 21),
        link: NubifyContact.gmail(subject: 'Nubify').toString(),
        colors: const [Color(0xFFEA4335), Color(0xFFB31412)],
      ),
    ];

    Widget tile(_SocialLink item) {
      return Material(
        color: NubifyHonorColors.card(context),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openLink(context, item.link, item.label),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NubifyHonorColors.line(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: item.colors,
                    ),
                  ),
                  child: Center(child: item.logo),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: NubifyHonorColors.text(context),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.link.isEmpty ? 'Coming soon' : item.action,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: NubifyHonorColors.muted(context),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: NubifyHonorColors.muted(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'For technical support, reports or suggestions, contact me via:',
              style: TextStyle(
                color: NubifyHonorColors.text(context),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // One under the other so the number and email show in full.
          tile(links[0]),
          const SizedBox(height: 10),
          tile(links[1]),
        ],
      ),
    );
  }

  //===================================================
  // VIEW MY NUBIFY PROFILE
  //===================================================

  Widget _buildProfileButton(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: NubifyHonorColors.ink,
        foregroundColor: NubifyHonorColors.goldLight,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: NubifyHonorColors.gold.withValues(alpha: .5),
          ),
        ),
      ),
      icon: const Icon(Icons.person_rounded),
      label: const Text(
        'View my Nubify profile',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      onPressed: () => Navigator.of(
        context,
      ).pushNamed('/profile', arguments: _Developer.nubifyUid),
    );
  }

  //===================================================
  // FOOTER
  //===================================================

  Widget _buildFooter(BuildContext context) {
    final Color muted = NubifyHonorColors.muted(context);

    return Column(
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(color: muted, fontSize: 12.5),
            children: const [
              TextSpan(text: 'Made with '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: NubifyHonorColors.gold,
                ),
              ),
              TextSpan(text: ' for the NUB community'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'NUBIFY · CAMPUS SOCIAL',
          style: TextStyle(
            color: muted.withValues(alpha: .7),
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

//===================================================
// DEVELOPER PHOTO — STORED ONLINE
//
// The photo picked inside the app is saved in Firebase,
// so every user sees it. Until one is picked, the photo
// in assets/images is shown.
//===================================================

class _DeveloperPhotoStore {
  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance
          .collection('nubify_public_pages')
          .doc('developer');

  // The uploaded photo link, or '' to use the asset photo.
  static Stream<String> watchPhotoUrl() {
    try {
      return _doc
          .snapshots()
          .map((snapshot) => (snapshot.data()?['photoUrl'] ?? '').toString())
          .handleError((Object _) {});
    } catch (_) {
      return Stream<String>.value('');
    }
  }

  // Only the Nubify owner account can change the photo.
  static Future<bool> canEdit() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return false;
      }

      final IdTokenResult token = await user.getIdTokenResult();
      return token.claims?['marketplaceOwner'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> upload(XFile photo, String oldUrl) async {
    final String extension = photo.name.split('.').last.toLowerCase();
    final String contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final Reference ref = FirebaseStorage.instance.ref(
      'nubifyPublicPages/developer/'
          'photo_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );

    await ref.putData(
      await photo.readAsBytes(),
      SettableMetadata(contentType: contentType),
    );

    await _savePhotoUrl(await ref.getDownloadURL());
    await _deleteOld(oldUrl);
  }

  static Future<void> useDefault(String oldUrl) async {
    await _savePhotoUrl('');
    await _deleteOld(oldUrl);
  }

  static Future<void> _savePhotoUrl(String url) {
    return _doc.set({
      'photoUrl': url,
      'photoUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _deleteOld(String oldUrl) async {
    if (oldUrl.isEmpty) {
      return;
    }

    try {
      await FirebaseStorage.instance.refFromURL(oldUrl).delete();
    } catch (_) {
      // The old file is already gone; nothing to clean up.
    }
  }
}

//===================================================
// SQUARE PHOTO WITH A MOVING GOLD FRAME
//===================================================

class _DeveloperPhoto extends StatefulWidget {
  const _DeveloperPhoto({required this.size});

  final double size;

  @override
  State<_DeveloperPhoto> createState() => _DeveloperPhotoState();
}

class _DeveloperPhotoState extends State<_DeveloperPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  late final Stream<String> _photoUrl = _DeveloperPhotoStore.watchPhotoUrl();
  late final Future<bool> _canEdit = _DeveloperPhotoStore.canEdit();

  String _currentUrl = '';
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (MediaQuery.of(context).disableAnimations) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  //===================================================
  // PHOTO ACTIONS
  //===================================================

  Future<void> _openEditor() async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose a new photo'),
              subtitle: const Text('Everyone on Nubify will see it'),
              onTap: () => Navigator.pop(sheetContext, 'pick'),
            ),
            if (_currentUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded),
                title: const Text('Use the original photo'),
                onTap: () => Navigator.pop(sheetContext, 'default'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == 'pick') {
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1200,
      );

      if (photo != null) {
        await _run(
          () => _DeveloperPhotoStore.upload(photo, _currentUrl),
          'Photo updated',
        );
      }
    } else if (choice == 'default') {
      await _run(
        () => _DeveloperPhotoStore.useDefault(_currentUrl),
        'Original photo restored',
      );
    }
  }

  Future<void> _run(Future<void> Function() task, String success) async {
    setState(() => _busy = true);

    String message = success;

    try {
      await task();
    } on FirebaseException catch (error) {
      message = error.code == 'permission-denied' ||
          error.code == 'unauthorized'
          ? 'Photo changes are not switched on yet. '
          'Deploy the new Firebase rules first.'
          : 'Could not update the photo. Please try again.';
    } catch (_) {
      message = 'Could not update the photo. Please try again.';
    }

    if (!mounted) {
      return;
    }

    setState(() => _busy = false);
    _snack(context, message);
  }

  // Shows the whole photo, not the square crop.
  void _viewLarge() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .88),
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.pop(dialogContext),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _photo(_currentUrl, BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  //===================================================
  // BUILD
  //===================================================

  Widget _photo(String url, BoxFit fit) {
    final Widget asset = Image(
      image: const AssetImage(_Developer.photoAsset),
      fit: fit,
      alignment: _Developer.photoFocus,
    );

    if (!url.startsWith('http')) {
      return asset;
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      alignment: _Developer.photoFocus,
      placeholder: (_, _) => asset,
      errorWidget: (_, _, _) => asset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    final double radius = size * .24;
    const double frame = 3.5;
    const double gap = 3;

    return StreamBuilder<String>(
      stream: _photoUrl,
      initialData: '',
      builder: (context, snapshot) {
        _currentUrl = snapshot.data ?? '';

        return SizedBox.square(
          dimension: size + 10,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _sweep,
                builder: (context, child) => Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(frame),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: SweepGradient(
                      colors: const [
                        NubifyHonorColors.goldLight,
                        NubifyHonorColors.gold,
                        NubifyHonorColors.goldDeep,
                        NubifyHonorColors.gold,
                        NubifyHonorColors.goldLight,
                      ],
                      transform: GradientRotation(_sweep.value * 2 * math.pi),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: NubifyHonorColors.gold.withValues(alpha: .28),
                        blurRadius: 30,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.all(gap),
                  decoration: BoxDecoration(
                    color: NubifyHonorColors.ink,
                    borderRadius: BorderRadius.circular(radius - frame),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius - frame - gap),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Semantics(
                          image: true,
                          label: 'Photo of ${_Developer.name}',
                          child: GestureDetector(
                            onTap: _viewLarge,
                            child: _photo(_currentUrl, BoxFit.cover),
                          ),
                        ),
                        if (_busy)
                          const ColoredBox(
                            color: Colors.black45,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: NubifyHonorColors.goldLight,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              FutureBuilder<bool>(
                future: _canEdit,
                builder: (context, owner) {
                  if (owner.data != true) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: NubifyHonorColors.gold,
                      shape: const CircleBorder(
                        side: BorderSide(
                          color: NubifyHonorColors.ink,
                          width: 3,
                        ),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _busy ? null : _openEditor,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.photo_camera_rounded,
                            size: 18,
                            color: NubifyHonorColors.ink,
                            semanticLabel: 'Change photo',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

//===================================================
// FACULTY CHIP — SAME ICON AND COLOUR AS PROFILES
//===================================================

class _FacultyChip extends StatelessWidget {
  const _FacultyChip({required this.faculty});

  final String faculty;

  @override
  Widget build(BuildContext context) {
    final NubifyFaculty style = NubifyFacultyCatalog.displayFor(faculty);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: .5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 17, color: style.color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              faculty,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// ROLE LINE
//===================================================

class _RoleLine extends StatelessWidget {
  const _RoleLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: NubifyHonorColors.gold.withValues(alpha: .1),
        border: Border.all(
          color: NubifyHonorColors.gold.withValues(alpha: .55),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: NubifyHonorColors.goldLight,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

//===================================================
// CLOSING PANEL — MOTTO, WELCOME AND SIGNATURE
//===================================================

class _ClosingPanel extends StatelessWidget {
  const _ClosingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NubifyHonorColors.ink,
            NubifyHonorColors.inkSoft,
            Color(0xFF2A2210),
          ],
        ),
        border: Border.all(
          color: NubifyHonorColors.gold.withValues(alpha: .35),
        ),
      ),
      child: Column(
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: NubifyHonorColors.goldGradient,
            ).createShader(bounds),
            child: const Text(
              _Developer.motto,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                height: 1.45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            _Developer.welcome,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 46,
            height: 1.5,
            color: NubifyHonorColors.gold.withValues(alpha: .6),
          ),
          const SizedBox(height: 14),
          Text(
            _Developer.signOff,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .72),
              fontSize: 13,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// SOCIAL LINK DATA
//===================================================

class _SocialLink {
  const _SocialLink({
    required this.label,
    required this.action,
    required this.logo,
    required this.link,
    required this.colors,
  });

  final String label;
  final String action;
  final Widget logo;
  final String link;
  final List<Color> colors;
}
