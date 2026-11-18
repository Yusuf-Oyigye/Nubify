import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.nubifyUid = '',
    this.tribute = 'Thank you for being part of the Nubify journey.',
  });

  final String name;
  final String faculty;
  final String role;

  // An https link, an asset path like 'assets/team/umar.jpg',
  // or '' to show initials.
  final String photo;

  // Their Nubify user id. When filled, their card gets a
  // "View Nubify profile" button.
  final String nubifyUid;

  // The thank-you message shown when their card is tapped.
  final String tribute;
}

// The first person whose role contains "Patron" gets the
// big featured card. Everyone else is grouped by role, in
// the order they appear here.
const List<_Honoree> _honorees = [
  _Honoree(
    name: 'Umar Harun',
    faculty: 'Faculty of Physical Therapy',
    role: 'Grand Patron of Nubify',
    photo: '',
    nubifyUid: '',
    tribute: 'Thank you for standing behind Nubify as its Grand Patron.',
  ),
  _Honoree(
    name: "Mubarak Rabi'u",
    faculty: 'Faculty of Medicine',
    role: 'Moderator',
    photo: '',
    nubifyUid: '',
  ),
  _Honoree(
    name: 'Abdulsalam Modu',
    faculty: 'Faculty of Medicine',
    role: 'Moderator',
    photo: '',
    nubifyUid: '',
  ),
  _Honoree(
    name: 'Abdulrahman Buhari',
    faculty: 'Faculty of Medicine',
    role: 'Moderator',
    photo: '',
    nubifyUid: '',
  ),
  _Honoree(
    name: 'Yakub (Badoo)',
    faculty: 'Faculty of Computer Science',
    role: 'Member',
    photo: '',
    nubifyUid: '',
  ),
  _Honoree(
    name: 'Hindatu Zakari',
    faculty: 'Faculty of Oral and Dental Medicine',
    role: 'Member',
    photo: '',
    nubifyUid: '',
  ),
];

//===================================================
// NUBIFY — HONORARY RECOGNITION SCREEN
//===================================================

class HonoraryRecognitionScreen extends StatelessWidget {
  const HonoraryRecognitionScreen({super.key});

  void _showHonoree(BuildContext context, _Honoree honoree) {
    HapticFeedback.lightImpact();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HonoreeSheet(honoree: honoree),
    );
  }

  @override
  Widget build(BuildContext context) {
    //=========================================
    // SPLIT INTO PATRON + ROLE GROUPS
    //=========================================

    final _Honoree? patron = _honorees
        .where((h) => h.role.toLowerCase().contains('patron'))
        .firstOrNull;

    final Map<String, List<_Honoree>> groups = {};

    for (final _Honoree honoree in _honorees) {
      if (!identical(honoree, patron)) {
        groups.putIfAbsent(honoree.role, () => []).add(honoree);
      }
    }

    // Each card fades in a little after the one before it.
    int revealIndex = 0;

    Duration nextDelay() =>
        Duration(milliseconds: 200 + 70 * revealIndex++);

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
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    //=================================
                    // FEATURED PATRON
                    //=================================
                    if (patron != null) ...[
                      const NubifySectionLabel(
                        text: 'Patron',
                        accent: NubifyHonorColors.emerald,
                      ),
                      NubifyReveal(
                        delay: nextDelay(),
                        child: _FeaturedCard(
                          honoree: patron,
                          onTap: () => _showHonoree(context, patron),
                        ),
                      ),
                    ],

                    //=================================
                    // ROLE GROUPS
                    //=================================
                    for (final MapEntry<String, List<_Honoree>> group
                    in groups.entries) ...[
                      NubifySectionLabel(
                        text: group.key.endsWith('s')
                            ? group.key
                            : '${group.key}s',
                        accent: NubifyHonorColors.emerald,
                      ),
                      for (final _Honoree honoree in group.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: NubifyReveal(
                            delay: nextDelay(),
                            child: _HonoreeCard(
                              honoree: honoree,
                              onTap: () => _showHonoree(context, honoree),
                            ),
                          ),
                        ),
                    ],

                    //=================================
                    // DISCLAIMER
                    //=================================
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
              Color(0xFF04140F),
              NubifyHonorColors.forest,
              NubifyHonorColors.forestSoft,
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -90,
              right: -70,
              child: NubifyGlow(color: NubifyHonorColors.emerald, size: 270),
            ),
            const Positioned(
              bottom: -120,
              left: -80,
              child: NubifyGlow(
                color: NubifyHonorColors.emeraldLight,
                size: 240,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 18, 30),
                child: Column(
                  children: [
                    const NubifyHeaderBar(title: 'Honorary Recognition'),
                    const SizedBox(height: 20),
                    NubifyReveal(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: NubifyHonorColors.emeraldGradient,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: NubifyHonorColors.emerald.withValues(
                                alpha: .45,
                              ),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    NubifyReveal(
                      delay: const Duration(milliseconds: 80),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            const Text(
                              'Wall of Honour',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Celebrating the people who inspired, '
                                  'supported and contributed to the Nubify '
                                  'journey.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14.5,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: NubifyHonorColors.emeraldLight
                                      .withValues(alpha: .35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const NubifyVerifiedSeal(
                                    tone: NubifySealTone.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${_honorees.length} honourees · '
                                          'verified by Nubify',
                                      style: const TextStyle(
                                        color: NubifyHonorColors.emeraldLight,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
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
// FEATURED PATRON CARD
//===================================================

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.honoree, required this.onTap});

  final _Honoree honoree;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color card = NubifyHonorColors.card(context);

    // A 1.5px gradient border: an emerald box with the card
    // painted on top of it, slightly smaller.
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: NubifyHonorColors.emeraldGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: NubifyHonorColors.emerald.withValues(alpha: .18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(24.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(24.5),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [
                        NubifyHonorColors.emerald,
                        NubifyHonorColors.emeraldDeep,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          honoree.role.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    NubifyHonorAvatar(
                      name: honoree.name,
                      photo: honoree.photo,
                      ringColors: NubifyHonorColors.emeraldGradient,
                      size: 76,
                      gapColor: card,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NameWithSeal(name: honoree.name, fontSize: 19),
                          const SizedBox(height: 6),
                          _FacultyLine(faculty: honoree.faculty),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  honoree.tribute,
                  style: TextStyle(
                    color: NubifyHonorColors.muted(context),
                    fontSize: 14,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//===================================================
// HONOREE CARD
//===================================================

class _HonoreeCard extends StatelessWidget {
  const _HonoreeCard({required this.honoree, required this.onTap});

  final _Honoree honoree;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color card = NubifyHonorColors.card(context);

    return Material(
      color: card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: NubifyHonorColors.line(context)),
          ),
          child: Row(
            children: [
              NubifyHonorAvatar(
                name: honoree.name,
                photo: honoree.photo,
                ringColors: NubifyHonorColors.emeraldGradient,
                size: 58,
                gapColor: card,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NameWithSeal(name: honoree.name, fontSize: 16),
                    const SizedBox(height: 4),
                    _FacultyLine(faculty: honoree.faculty),
                    const SizedBox(height: 8),
                    _GreenRolePill(role: honoree.role),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: NubifyHonorColors.muted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//===================================================
// HONOREE DETAIL SHEET (opens when a card is tapped)
//===================================================

class _HonoreeSheet extends StatelessWidget {
  const _HonoreeSheet({required this.honoree});

  final _Honoree honoree;

  @override
  Widget build(BuildContext context) {
    final Color card = NubifyHonorColors.card(context);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NubifyHonorColors.line(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 22),
            NubifyHonorAvatar(
              name: honoree.name,
              photo: honoree.photo,
              ringColors: NubifyHonorColors.emeraldGradient,
              size: 104,
              spinRing: true,
              gapColor: card,
            ),
            const SizedBox(height: 16),
            _NameWithSeal(
              name: honoree.name,
              fontSize: 22,
              centered: true,
              shimmer: true,
            ),
            const SizedBox(height: 6),
            _FacultyLine(faculty: honoree.faculty, centered: true),
            const SizedBox(height: 12),
            _GreenRolePill(role: honoree.role),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: NubifyHonorColors.emerald.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: NubifyHonorColors.emerald.withValues(alpha: .22),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    color: NubifyHonorColors.emerald,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    honoree.tribute,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NubifyHonorColors.text(context),
                      fontSize: 15.5,
                      height: 1.55,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            if (honoree.nubifyUid.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: NubifyHonorColors.emerald,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.person_rounded),
                  label: const Text(
                    'View Nubify profile',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    final NavigatorState navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.pushNamed(
                      '/profile',
                      arguments: honoree.nubifyUid,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

//===================================================
// SMALL PIECES
//===================================================

class _NameWithSeal extends StatelessWidget {
  const _NameWithSeal({
    required this.name,
    required this.fontSize,
    this.centered = false,
    this.shimmer = false,
  });

  final String name;
  final double fontSize;
  final bool centered;
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: NubifyHonorColors.text(context),
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        NubifyVerifiedSeal(
          tone: NubifySealTone.green,
          size: fontSize + 2,
          shimmer: shimmer,
          message: 'Honorary recognition by Nubify',
        ),
      ],
    );
  }
}

class _FacultyLine extends StatelessWidget {
  const _FacultyLine({required this.faculty, this.centered = false});

  final String faculty;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final Color muted = NubifyHonorColors.muted(context);

    return Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Icon(Icons.school_outlined, size: 15, color: muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            faculty,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: muted, fontSize: 13),
          ),
        ),
      ],
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