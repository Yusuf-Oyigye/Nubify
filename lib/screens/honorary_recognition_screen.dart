import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/nubify_menu_components.dart';

//===================================================
// NUBIFY — HONORARY RECOGNITION SCREEN
//===================================================

class HonoraryRecognitionScreen extends StatelessWidget {
  const HonoraryRecognitionScreen({
    super.key,
  });

  //===================================================
  // RECOGNITION CATEGORIES
  //===================================================

  static const List<String> _categories = [
    'Founding Supporters',
    'Special Contributors',
    'Creative Contributors',
    'Technical Contributors',
    'Special Thanks',
    'Honorary Recognition',
  ];

  //===================================================
  // BUILD SCREEN
  //===================================================

  @override
  Widget build(BuildContext context) {
    return NubifyMenuPage(
      title: 'Honorary Recognition',

      subtitle:
      'Celebrating the people who inspired, supported, and contributed to the Nubify journey.',

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,

        children: [
          //=========================================
          // PREMIUM RECOGNITION HEADER
          //=========================================

          Container(
            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(
              borderRadius:
              BorderRadius.circular(25),

              gradient:
              NubifyMenuColors.isDark(context)
                  ? const LinearGradient(
                colors: [
                  Color(0xFF4A3C2B),
                  Color(0xFF272D3A),
                ],
              )
                  : const LinearGradient(
                colors: [
                  Color(0xFFFFF0CD),
                  Color(0xFFFFFAEE),
                ],
              ),

              border: Border.all(
                color:
                NubifyPalette.amber.withValues(
                  alpha: .25,
                ),
              ),
            ),

            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                const NubifyIconTile(
                  icon:
                  Icons.workspace_premium_rounded,
                  color: NubifyPalette.amber,
                  size: 58,
                  iconSize: 32,
                ),

                const SizedBox(height: 17),

                Text(
                  'People who made a difference',

                  style: TextStyle(
                    color:
                    NubifyMenuColors.primaryText(
                      context,
                    ),
                    fontSize: 22,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Our gratitude, shared with the community.',

                  style: TextStyle(
                    color:
                    NubifyMenuColors.secondaryText(
                      context,
                    ),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          //=========================================
          // FIRESTORE RECOGNITION ENTRIES
          //=========================================

          StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('nubify_recognitions')
                .where(
              'approved',
              isEqualTo: true,
            )
                .snapshots(),

            builder: (context, snapshot) {
              //===================================
              // ERROR
              //===================================

              if (snapshot.hasError) {
                return _status(
                  context,
                  Icons.wifi_off_rounded,
                  'Unable to load recognition entries',
                  'Check your connection or Firestore read permissions.',
                );
              }

              //===================================
              // LOADING
              //===================================

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(36),

                  child: Center(
                    child:
                    CircularProgressIndicator(),
                  ),
                );
              }

              //===================================
              // VALID APPROVED RECORDS
              //===================================

              final docs = snapshot.data!.docs
                  .where((doc) {
                final data = doc.data();

                return (data['fullName'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty &&
                    _categories.contains(
                      (data['category'] ?? '')
                          .toString(),
                    );
              }).toList();

              //===================================
              // SORT RECORDS
              //===================================

              docs.sort((a, b) {
                final aOrder =
                    (a.data()['sortOrder'] as num?)
                        ?.toInt() ??
                        99999;

                final bOrder =
                    (b.data()['sortOrder'] as num?)
                        ?.toInt() ??
                        99999;

                final byOrder =
                aOrder.compareTo(bOrder);

                if (byOrder != 0) {
                  return byOrder;
                }

                return a.id.compareTo(b.id);
              });

              //===================================
              // NO RECORDS
              //===================================

              if (docs.isEmpty) {
                return _status(
                  context,
                  Icons.favorite_border_rounded,
                  'Recognition wall is being prepared',
                  'Approved recognition entries will appear here once published.',
                );
              }

              //===================================
              // RECOGNITION CATEGORIES AND CARDS
              //===================================

              return Column(
                crossAxisAlignment:
                CrossAxisAlignment.stretch,

                children: [
                  for (final category in _categories)
                    if (docs.any(
                          (doc) =>
                      doc.data()['category'] ==
                          category,
                    )) ...[
                      Padding(
                        padding:
                        const EdgeInsets.fromLTRB(
                          3,
                          19,
                          3,
                          13,
                        ),

                        child: Text(
                          category,

                          style: TextStyle(
                            color:
                            NubifyMenuColors.primaryText(
                              context,
                            ),
                            fontSize: 18,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ),

                      for (final doc in docs.where(
                            (d) =>
                        d.data()['category'] ==
                            category,
                      ))
                        Padding(
                          padding:
                          const EdgeInsets.only(
                            bottom: 11,
                          ),

                          child: _RecognitionCard(
                            data: doc.data(),
                          ),
                        ),
                    ],

                  const SizedBox(height: 14),

                  Text(
                    'Recognitions are expressions of gratitude, not university appointments or endorsements.',

                    textAlign: TextAlign.center,

                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color:
                      NubifyMenuColors.secondaryText(
                        context,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  //===================================================
  // ERROR OR EMPTY STATE
  //===================================================

  Widget _status(
      BuildContext context,
      IconData icon,
      String title,
      String message,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        10,
        34,
        10,
        28,
      ),

      child: Column(
        children: [
          Icon(
            icon,
            size: 46,
            color: NubifyPalette.amber,
          ),

          const SizedBox(height: 13),

          Text(
            title,
            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color:
              NubifyMenuColors.primaryText(
                context,
              ),
            ),
          ),

          const SizedBox(height: 9),

          Text(
            message,
            textAlign: TextAlign.center,

            style: TextStyle(
              color:
              NubifyMenuColors.secondaryText(
                context,
              ),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// RECOGNITION PERSON CARD
//===================================================

class _RecognitionCard extends StatelessWidget {
  const _RecognitionCard({
    required this.data,
  });

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name =
    (data['fullName'] ?? '')
        .toString()
        .trim();

    final title =
    (data['honoraryTitle'] ?? '')
        .toString()
        .trim();

    final contribution =
    (data['contribution'] ?? '')
        .toString()
        .trim();

    final message =
    (data['message'] ?? '')
        .toString()
        .trim();

    final photo =
    (data['photoUrl'] ?? '')
        .toString()
        .trim();

    return Container(
      decoration: BoxDecoration(
        color: NubifyMenuColors.surface(context),
        borderRadius:
        BorderRadius.circular(21),
        border: Border.all(
          color: NubifyMenuColors.stroke(context),
        ),
      ),

      padding: const EdgeInsets.all(17),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          //=========================================
          // PERSON PROFILE
          //=========================================

          Row(
            children: [
              CircleAvatar(
                radius: 27,

                backgroundColor:
                NubifyMenuColors.tint(
                  context,
                  NubifyPalette.amber,
                ),

                backgroundImage:
                photo.isEmpty
                    ? null
                    : NetworkImage(photo),

                child: photo.isEmpty
                    ? const Icon(
                  Icons.person_outline_rounded,
                  color: NubifyPalette.amber,
                  size: 27,
                )
                    : null,
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      name,

                      style: TextStyle(
                        fontWeight:
                        FontWeight.w800,
                        color:
                        NubifyMenuColors.primaryText(
                          context,
                        ),
                        fontSize: 16,
                      ),
                    ),

                    if (title.isNotEmpty) ...[
                      const SizedBox(height: 3),

                      Text(
                        title,

                        style: const TextStyle(
                          color:
                          NubifyPalette.amber,
                          fontSize: 12.8,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Icon(
                Icons.workspace_premium_outlined,
                color: NubifyPalette.amber,
                size: 27,
              ),
            ],
          ),

          //=========================================
          // CONTRIBUTION
          //=========================================

          if (contribution.isNotEmpty) ...[
            const SizedBox(height: 14),

            Text(
              contribution,

              style: TextStyle(
                color:
                NubifyMenuColors.primaryText(
                  context,
                ),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],

          //=========================================
          // APPRECIATION MESSAGE
          //=========================================

          if (message.isNotEmpty) ...[
            const SizedBox(height: 9),

            Text(
              message,

              style: TextStyle(
                color:
                NubifyMenuColors.secondaryText(
                  context,
                ),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}