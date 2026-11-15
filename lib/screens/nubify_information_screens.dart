import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/marketplace_brand_icon.dart';
import '../widgets/nubify_menu_components.dart';

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
      title: 'About the App',

      subtitle:
          'Nubify · Campus Social\nBuilt for the Nahda University student community.',

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

            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),

                SizedBox(height: 18),

                Text(
                  'One campus. More connections.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                SizedBox(height: 9),

                Text(
                  'A social space designed to bring the NUB community together.',
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
      title: 'About the Developer',
      subtitle: 'Meet the person behind the Nubify experience.',

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
            return const _EmptyPublishedPage(
              icon: Icons.wifi_off_rounded,
              title: 'Developer profile unavailable',
              message:
                  'Unable to load the developer information. Please try again.',
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
            return const _EmptyPublishedPage(
              icon: Icons.person_outline_rounded,
              title: 'Developer details coming soon',
              message:
                  'The verified developer biography has not been published yet.',
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

                _TextPanel(title: 'Biography', content: biography),
              ],

              //=====================================
              // VISION
              //=====================================
              if (vision.trim().isNotEmpty) ...[
                const SizedBox(height: 14),

                _TextPanel(title: 'Vision', content: vision),
              ],

              //=====================================
              // COMMUNITY APPRECIATION
              //=====================================
              if (thanks.trim().isNotEmpty) ...[
                const SizedBox(height: 14),

                _TextPanel(title: 'To the Nubify community', content: thanks),
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
                              const SnackBar(content: Text('Link copied')),
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

    return NubifyMenuPage(
      title: title,

      subtitle: isTerms
          ? 'The official Nubify terms, when published.'
          : 'The official Nubify privacy policy, when published.',

      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('nubify_public_pages')
            .doc(isTerms ? 'terms' : 'privacy')
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _EmptyPublishedPage(
              icon: Icons.wifi_off_rounded,
              title: 'Document unavailable',
              message:
                  'We could not load this page right now. Please retry later.',
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data();

          final text = (data?['body'] ?? '').toString().trim();

          if (data?['published'] != true || text.isEmpty) {
            return _EmptyPublishedPage(
              icon: isTerms ? Icons.gavel_rounded : Icons.shield_outlined,

              title: 'Official document not yet published',

              message:
                  'No approved $title is configured. Do not treat this as a legal policy.',
            );
          }

          return _TextPanel(
            title: (data?['title'] ?? title).toString(),

            content: text,
          );
        },
      ),
    );
  }
}

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
                tintColor: color,
                fallbackColor: color,
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
                  title,

                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: NubifyMenuColors.primaryText(context),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  description,

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
  const _TextPanel({required this.title, required this.content});

  final String title;
  final String content;

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

          SelectableText(
            content,

            style: TextStyle(
              fontSize: 14.5,
              height: 1.7,
              color: NubifyMenuColors.primaryText(context),
            ),
          ),
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
