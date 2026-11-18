import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/faculty_catalog.dart';
import '../widgets/nubify_honor_widgets.dart';

//===================================================
// HONOREES — EDIT ONLY THIS LIST
//===================================================

class _Honoree {
  const _Honoree({
    required this.name,
    required this.faculty,
    required this.role,
    this.photo = '',
  });

  final String name;

  // Must match a faculty name from sign up, so the same
  // faculty icon and colour appear here as on profiles.
  final String faculty;

  final String role;

  // An https link, an asset path like 'assets/team/umar.jpg',
  // or '' to show initials. Tapping a photo shows it in full.
  final String photo;
}

// Shown in this order.
const List<_Honoree> _honorees = [
  _Honoree(
    name: 'Umar Harun',
    faculty: 'Faculty of Physical Therapy',
    role: 'Grand Patron of Nubify',
    photo: '',
  ),
  _Honoree(
    name: "Mubarak Rabi'u",
    faculty: 'Faculty of Medicine',
    role: 'Moderator',
    photo: '',
  ),
  _Honoree(
    name: 'Abdulsalam Modu',
    faculty: 'Faculty of Medicine',
    role: 'Moderator',
    photo: '',
  ),
  _Honoree(
    name: 'Abdulrahman Buhari',
    faculty: 'Faculty of Medicine',
    role: 'Moderator',
    photo: '',
  ),
  _Honoree(
    name: 'Yakub (Badoo)',
    faculty: 'Faculty of Computer Science',
    role: 'Member',
    photo: '',
  ),
  _Honoree(
    name: 'Hindatu Zakari',
    faculty: 'Faculty of Oral and Dental Medicine',
    role: 'Member',
    photo: '',
  ),
];

//===================================================
// NUBIFY — HONORARY RECOGNITION SCREEN
//===================================================

class HonoraryRecognitionScreen extends StatelessWidget {
  const HonoraryRecognitionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                    // Each card fades in a little after the one before it.
                    for (int i = 0; i < _honorees.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NubifyReveal(
                          delay: Duration(milliseconds: 150 + 60 * i),
                          child: _HonoreeCard(honoree: _honorees[i]),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'Recognitions are expressions of gratitude, not '
                          'university appointments or endorsements.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: NubifyHonorColors.muted(context),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
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
  // COMPACT HEADER
  //===================================================

  Widget _buildHero(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF04140F),
              NubifyHonorColors.forest,
              NubifyHonorColors.forestSoft,
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -80,
              right: -60,
              child: NubifyGlow(color: NubifyHonorColors.emerald, size: 210),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 18, 22),
                child: Column(
                  children: [
                    const NubifyHeaderBar(title: 'Honorary Recognition'),
                    const SizedBox(height: 14),
                    NubifyReveal(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: NubifyHonorColors.emeraldGradient,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: NubifyHonorColors.emerald
                                        .withValues(alpha: .45),
                                    blurRadius: 22,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                color: Colors.white,
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Wall of Honour',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .3,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Celebrating the people who inspired, '
                                        'supported and contributed to the '
                                        'Nubify journey.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13.5,
                                      height: 1.45,
                                    ),
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }
}

//===================================================
// HONOREE CARD
//===================================================

class _HonoreeCard extends StatelessWidget {
  const _HonoreeCard({required this.honoree});

  final _Honoree honoree;

  @override
  Widget build(BuildContext context) {
    final Color card = NubifyHonorColors.card(context);
    final bool hasPhoto = honoree.photo.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NubifyHonorColors.line(context)),
      ),
      child: Row(
        children: [
          Semantics(
            button: hasPhoto,
            label: hasPhoto ? 'View photo of ${honoree.name}' : null,
            child: GestureDetector(
              onTap: hasPhoto ? () => _viewPhoto(context, honoree) : null,
              child: NubifyHonorAvatar(
                name: honoree.name,
                photo: honoree.photo,
                ringColors: NubifyHonorColors.emeraldGradient,
                size: 62,
                gapColor: card,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NameWithSeal(name: honoree.name),
                const SizedBox(height: 7),
                _FacultyChip(faculty: honoree.faculty),
                const SizedBox(height: 7),
                _GreenRolePill(role: honoree.role),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// FULL PHOTO VIEW (tap a photo)
//===================================================

void _viewPhoto(BuildContext context, _Honoree honoree) {
  final String photo = honoree.photo.trim();
  final ImageProvider<Object> image = photo.startsWith('http')
      ? CachedNetworkImageProvider(photo)
      : AssetImage(photo);

  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .88),
    builder: (dialogContext) => GestureDetector(
      onTap: () => Navigator.pop(dialogContext),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InteractiveViewer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image(image: image, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Material(
                type: MaterialType.transparency,
                child: Text(
                  honoree.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

//===================================================
// SMALL PIECES
//===================================================

class _NameWithSeal extends StatelessWidget {
  const _NameWithSeal({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: NubifyHonorColors.text(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const NubifyVerifiedSeal(
          tone: NubifySealTone.green,
          size: 18,
          message: 'Honorary recognition by Nubify',
        ),
      ],
    );
  }
}

// Same faculty icon and colour users get at sign up.
class _FacultyChip extends StatelessWidget {
  const _FacultyChip({required this.faculty});

  final String faculty;

  @override
  Widget build(BuildContext context) {
    final NubifyFaculty style = NubifyFacultyCatalog.displayFor(faculty);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.color.withValues(alpha: .32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 15, color: style.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              faculty,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: NubifyHonorColors.text(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GreenRolePill extends StatelessWidget {
  const _GreenRolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final bool dark = NubifyHonorColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NubifyHonorColors.emerald.withValues(alpha: dark ? .2 : .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: dark
              ? NubifyHonorColors.emeraldLight
              : NubifyHonorColors.emeraldDeep,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: .3,
        ),
      ),
    );
  }
}
