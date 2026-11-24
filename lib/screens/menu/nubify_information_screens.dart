import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/marketplace/marketplace_brand_icon.dart';
import '../../widgets/menu/nubify_menu_components.dart';
import '../../widgets/common/translatable_text.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// NUBIFY — ABOUT THE APP
//===================================================

class NubifyAboutAppScreen extends StatelessWidget {
  const NubifyAboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const entries = <(IconData?, String, String, Color)>[
      (
        Icons.people_alt_outlined,
        'Campus social',
        'Connect with your university community through profiles, posts and stories.',
        NubifyPalette.purple,
      ),
      (
        Icons.chat_bubble_outline_rounded,
        'Messages & groups',
        'Keep in touch with students using the existing messaging tools.',
        NubifyPalette.teal,
      ),
      (
        null,
        'NUB Marketplace',
        'Discover and share available campus listings.',
        NubifyPalette.emerald,
      ),
      (
        Icons.smart_toy_outlined,
        'NUB AI Tutor',
        'Access the learning assistant available inside Nubify.',
        NubifyPalette.sapphire,
      ),
      (
        Icons.play_circle_outline_rounded,
        'NUBuzz',
        'Explore the video experience inside Nubify.',
        NubifyPalette.coral,
      ),
      (
        Icons.language_rounded,
        'Egyptian Arabic',
        'Study Egyptian Arabic with Nubify.',
        NubifyPalette.amber,
      ),
    ];

    return NubifyMenuPage(
      title: context.tr('About the App'),

      subtitle:
          context.tr('Nubify · Campus Social\nBuilt for the Nahda University student community.'),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          Container(
            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF218DCE), Color(0xFF7272CC)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),

                SizedBox(height: 18),

                Text(context.tr('One campus. More connections.'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                SizedBox(height: 9),

                Text(context.tr('A social space designed to bring the NUB community together.'),
                  style: TextStyle(color: Colors.white, height: 1.45),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          ...entries.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),

              child: _InfoRow(
                icon: item.$1,
                title: item.$2,
                description: item.$3,
                color: item.$4,
              ),
            ),
          ),

          const SizedBox(height: 12),

          //=========================================
          // CREDITS (required by the CC-BY 4.0 licence)
          //=========================================
          Text(context.tr('Marketplace cart icon: Twemoji by Twitter, Inc. and other '
            'contributors, licensed under CC-BY 4.0.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: NubifyMenuColors.secondaryText(context),
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// NUBIFY — ABOUT THE DEVELOPER
//===================================================

class NubifyDeveloperScreen extends StatelessWidget {
  const NubifyDeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NubifyMenuPage(
      title: context.tr('About the Developer'),
      subtitle: context.tr('Meet the person behind the Nubify experience.'),

      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('nubify_public_pages')
            .doc('developer')
            .snapshots(),

        builder: (context, snapshot) {
          //=========================================
          // ERROR
          //=========================================

          if (snapshot.hasError) {
            return _EmptyPublishedPage(
              icon: Icons.wifi_off_rounded,
              title: context.tr('Developer profile unavailable'),
              message:
                  context.tr('Unable to load the developer information. Please try again.'),
            );
          }

          //=========================================
          // LOADING
          //=========================================

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data();

          //=========================================
          // NO PUBLISHED DEVELOPER PROFILE
          //=========================================

          if (data == null ||
              data['published'] != true ||
              (data['name'] ?? '').toString().trim().isEmpty) {
            return _EmptyPublishedPage(
              icon: Icons.person_outline_rounded,
              title: context.tr('Developer details coming soon'),
              message:
                  context.tr('The verified developer biography has not been published yet.'),
            );
          }

          //=========================================
          // FIRESTORE DATA
          //=========================================

          final name = data['name'].toString().trim();

          final role = (data['role'] ?? 'Developer').toString();

          final photo = (data['photoUrl'] ?? '').toString();

          final biography = (data['biography'] ?? '').toString();

          final vision = (data['vision'] ?? '').toString();

          final thanks = (data['appreciation'] ?? '').toString();

          final links = data['links'] is Map
              ? Map<String, dynamic>.from(data['links'] as Map)
              : <String, dynamic>{};

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              //=====================================
              // DEVELOPER PROFILE CARD
              //=====================================

              Container(
                padding: const EdgeInsets.all(26),

                decoration: BoxDecoration(
                  color: NubifyMenuColors.surface(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: NubifyMenuColors.stroke(context)),
                ),

                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: NubifyMenuColors.tint(
                        context,
                        NubifyPalette.violet,
                      ),
                      radius: 45,

                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo)
                          : null,

                      child: photo.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              color: NubifyPalette.violet,
                              size: 43,
                            )
                          : null,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      name,
                      textAlign: TextAlign.center,

                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: NubifyMenuColors.primaryText(context),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      role,
                      style: const TextStyle(
                        color: NubifyPalette.violet,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              //=====================================
              // BIOGRAPHY
              //=====================================
              if (biography.trim().isNotEmpty) ...[
                const SizedBox(height: 14),

                _TextPanel(title: context.tr('Biography'), content: biography),
              ],

              //=====================================
              // VISION
              //=====================================
              if (vision.trim().isNotEmpty) ...[
                const SizedBox(height: 14),

                _TextPanel(title: context.tr('Vision'), content: vision),
              ],

              //=====================================
              // COMMUNITY APPRECIATION
              //=====================================
              if (thanks.trim().isNotEmpty) ...[
                const SizedBox(height: 14),

                _TextPanel(title: context.tr('To the Nubify community'), content: thanks),
              ],

              //=====================================
              // DEVELOPER LINKS
              //=====================================
              if (links.isNotEmpty) ...[
                const SizedBox(height: 14),

                ...links.entries
                    .where((e) => e.value.toString().trim().isNotEmpty)
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),

                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.link_rounded),

                          label: Text('Copy ${e.key} link'),

                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: e.value.toString()),
                            );

                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.tr('Link copied'))),
                            );
                          },
                        ),
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}

//===================================================
// LEGAL DOCUMENT TYPES
//===================================================

enum NubifyLegalType { terms, privacy }

//===================================================
// NUBIFY — TERMS AND PRIVACY POLICY
//===================================================

class NubifyLegalScreen extends StatelessWidget {
  const NubifyLegalScreen({super.key, required this.type});

  final NubifyLegalType type;

  @override
  Widget build(BuildContext context) {
    final isTerms = type == NubifyLegalType.terms;

    final title = isTerms ? 'Terms and Conditions' : 'Privacy Policy';

    // The owner can publish a translation next to the
    // English (body_ar, title_ar ...); otherwise readers
    // get the English with a Translate link.
    final String language = Localizations.localeOf(context).languageCode;

    return NubifyMenuPage(
      title: context.tr(title),

      subtitle: isTerms
          ? context.tr('The official Nubify terms, when published.')
          : context.tr('The official Nubify privacy policy, when published.'),

      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('nubify_public_pages')
            .doc(isTerms ? 'terms' : 'privacy')
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _EmptyPublishedPage(
              icon: Icons.wifi_off_rounded,
              title: context.tr('Document unavailable'),
              message:
                  context.tr('We could not load this page right now. Please retry later.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data();

          final String translated =
              (data?['body_$language'] ?? '').toString().trim();

          final text = translated.isNotEmpty
              ? translated
              : (data?['body'] ?? '').toString().trim();

          if (data?['published'] != true || text.isEmpty) {
            return _EmptyPublishedPage(
              icon: isTerms ? Icons.gavel_rounded : Icons.shield_outlined,

              title: context.tr('Official document not yet published'),

              message: context.tr(
                'No approved {title} is configured. Do not treat this as a legal policy.',
                {'title': context.tr(title)},
              ),
            );
          }

          return _TextPanel(
            title: (data?['title_$language'] ??
                    data?['title'] ??
                    context.tr(title))
                .toString(),

            content: text,

            translatable: translated.isEmpty,
          );
        },
      ),
    );
  }
}
//===================================================
// NUB — THE UNIVERSITY
//===================================================

class NubUniversityScreen extends StatelessWidget {
  const NubUniversityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NubifyMenuPage(
      title: context.tr('The University'),
      subtitle: context.tr('Nahda University in Beni Suef · Est. 2006'),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          //=========================================
          // UNIVERSITY LOGO
          //=========================================
          Container(
            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(
              color: const Color(0xFF103A75),
              borderRadius: BorderRadius.circular(25),
            ),

            child: Image.asset(
              'assets/images/nub_logo.png',
              height: 200,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 14),

          //=========================================
          // ABOUT THE UNIVERSITY
          //=========================================
          _TextPanel(
            title: context.tr('About Nahda University'),
            content: _nubAboutText,
          ),

        ],
      ),
    );
  }
}

const _nubAboutText = '''Nahda University in Beni Suef (NUB) is a leading private Egyptian university established in 2006 and located in New Beni Suef, Beni Suef Governorate, Egypt. As one of the pioneers of private higher education in Upper Egypt, the university is dedicated to providing quality education, advancing scientific research, encouraging innovation, and preparing students to become competent professionals and future leaders.

The university comprises ten faculties: Medicine, Oral and Dental Medicine, Pharmacy, Physical Therapy, Nursing, Engineering, Computer Science, Business Administration, Mass Communication and Applied Languages, and Fine Arts. Through its diverse academic programmes, NUB provides students with opportunities to pursue their educational and professional ambitions across various disciplines.

Nahda University emphasizes academic excellence, practical learning, critical thinking, research, entrepreneurship, and community engagement. Its educational environment combines theoretical knowledge with practical and professional training, supported by laboratories, libraries, digital learning resources, specialized facilities, and clinical training opportunities through its university hospital.

The university also promotes international academic collaboration, faculty development, scientific conferences, student activities, and professional development opportunities to broaden students' academic and cultural experiences.

Beyond the classroom, NUB encourages students to participate in extracurricular activities, sports, cultural events, scientific initiatives, and community service. It aims to create an inclusive and supportive university environment where students can develop their knowledge, talents, leadership abilities, creativity, and interpersonal skills.

With its commitment to education, research, innovation, and societal development, Nahda University continues to contribute to the advancement of higher education in Egypt, particularly in Upper Egypt, while preparing graduates to meet the challenges and opportunities of an increasingly connected world.''';

//===================================================
// REUSABLE INFORMATION ROW
//===================================================

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData? icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: NubifyMenuColors.surface(context),

        border: Border.all(color: NubifyMenuColors.stroke(context)),

        borderRadius: BorderRadius.circular(19),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          if (icon == null)
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: NubifyMenuColors.tint(context, color),
                borderRadius: BorderRadius.circular(15),
              ),
              child: MarketplaceBrandIcon(
                size: 23,
              ),
            )
          else
            NubifyIconTile(icon: icon!, color: color),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  context.tr(title),

                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: NubifyMenuColors.primaryText(context),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  context.tr(description),

                  style: TextStyle(
                    fontSize: 13.3,
                    height: 1.4,

                    color: NubifyMenuColors.secondaryText(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// REUSABLE TEXT CONTENT PANEL
//===================================================

class _TextPanel extends StatelessWidget {
  const _TextPanel({
    required this.title,
    required this.content,
    this.translatable = false,
  });

  final String title;
  final String content;

  // Shows the Translate link under the text (published
  // documents only in English).
  final bool translatable;

  TextStyle _contentStyle(BuildContext context) => TextStyle(
    fontSize: 14.5,
    height: 1.7,
    color: NubifyMenuColors.primaryText(context),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(21),

      decoration: BoxDecoration(
        color: NubifyMenuColors.surface(context),

        border: Border.all(color: NubifyMenuColors.stroke(context)),

        borderRadius: BorderRadius.circular(22),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: NubifyMenuColors.primaryText(context),
            ),
          ),

          const SizedBox(height: 14),

          if (translatable)
            TranslatableText(
              text: content,
              builder: (String shown) =>
                  SelectableText(shown, style: _contentStyle(context)),
            )
          else
            SelectableText(content, style: _contentStyle(context)),
        ],
      ),
    );
  }
}

//===================================================
// EMPTY OR UNPUBLISHED CONTENT STATE
//===================================================

class _EmptyPublishedPage extends StatelessWidget {
  const _EmptyPublishedPage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 38),

      child: Column(
        children: [
          Icon(icon, color: NubifyPalette.slate, size: 47),

          const SizedBox(height: 18),

          Text(
            title,
            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: NubifyMenuColors.primaryText(context),
            ),
          ),

          const SizedBox(height: 9),

          Text(
            message,
            textAlign: TextAlign.center,

            style: TextStyle(
              color: NubifyMenuColors.secondaryText(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
