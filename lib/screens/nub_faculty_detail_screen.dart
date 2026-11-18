import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/nub_faculty.dart';
import '../widgets/nubify_menu_components.dart';

//===================================================
// NUB — SINGLE FACULTY SCREEN
//===================================================

class NubFacultyDetailScreen extends StatelessWidget {
  const NubFacultyDetailScreen({super.key, required this.faculty});

  final NubFaculty faculty;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final headerHeight = math.min(screenWidth, 520.0) * .96;

    final index = nubFaculties.indexOf(faculty);

    final next = nubFaculties[(index + 1) % nubFaculties.length];

    return Scaffold(
      backgroundColor: NubifyMenuColors.background(context),

      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),

        slivers: [
          //=========================================
          // COLLAPSING POSTER HEADER
          //=========================================
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: headerHeight,
            backgroundColor: faculty.deepColor,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,

            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                end: 20,
                bottom: 16,
              ),
              expandedTitleScale: 1.45,

              title: Text(
                faculty.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),

              background: Stack(
                fit: StackFit.expand,

                children: [
                  Hero(
                    tag: 'nub-faculty-${faculty.id}',

                    child: Image.asset(
                      faculty.image,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),

                  // Dark fade at the top (status bar) and bottom (title)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, .22, .55, 1],
                        colors: [
                          Colors.black.withValues(alpha: .35),
                          Colors.transparent,
                          Colors.transparent,
                          faculty.deepColor.withValues(alpha: .96),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          //=========================================
          // PAGE CONTENT
          //=========================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,

                    children: [
                      _Pill(
                        icon: faculty.field.icon,
                        label: faculty.field.label,
                        color: faculty.color,
                      ),
                      _Pill(
                        icon: faculty.icon,
                        label: 'Faculty ${faculty.number} of ${nubFaculties.length}',
                        color: NubifyPalette.slate,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(
                    faculty.arabicName,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: faculty.color,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    faculty.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: NubifyMenuColors.primaryText(context),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    faculty.tagline,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: NubifyMenuColors.secondaryText(context),
                    ),
                  ),

                  const SizedBox(height: 22),

                  //=================================
                  // ABOUT
                  //=================================
                  _Section(
                    icon: Icons.auto_stories_outlined,
                    title: 'About the faculty',
                    color: faculty.color,

                    child: Text(
                      faculty.about,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.75,
                        color: NubifyMenuColors.primaryText(context),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  //=================================
                  // SUBJECTS
                  //=================================
                  _Section(
                    icon: Icons.menu_book_rounded,
                    title: "What you'll study",
                    color: faculty.color,

                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,

                      children: [
                        for (final subject in faculty.subjects)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),

                            decoration: BoxDecoration(
                              color: NubifyMenuColors.tint(
                                context,
                                faculty.color,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: faculty.color.withValues(alpha: .22),
                              ),
                            ),

                            child: Text(
                              subject,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: NubifyMenuColors.primaryText(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  //=================================
                  // GRADUATE PATHWAYS
                  //=================================
                  _Section(
                    icon: Icons.rocket_launch_outlined,
                    title: 'Graduate pathways',
                    color: faculty.color,

                    child: Column(
                      children: [
                        for (final pathway in faculty.pathways)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),

                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 19,
                                  color: faculty.color,
                                ),

                                const SizedBox(width: 11),

                                Expanded(
                                  child: Text(
                                    pathway,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: NubifyMenuColors.primaryText(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  //=================================
                  // NEXT FACULTY
                  //=================================
                  _NextFacultyCard(faculty: next),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// SMALL ROUNDED LABEL
//===================================================

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),

      decoration: BoxDecoration(
        color: NubifyMenuColors.tint(context, color),
        borderRadius: BorderRadius.circular(30),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// CONTENT SECTION CARD
//===================================================

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: NubifyMenuColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NubifyMenuColors.stroke(context)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              NubifyIconTile(icon: icon, color: color, size: 40, iconSize: 20),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: NubifyMenuColors.primaryText(context),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          child,
        ],
      ),
    );
  }
}

//===================================================
// "NEXT FACULTY" CARD
//===================================================

class _NextFacultyCard extends StatelessWidget {
  const _NextFacultyCard({required this.faculty});

  final NubFaculty faculty;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,

      child: InkWell(
        borderRadius: BorderRadius.circular(24),

        // Replace this screen so the back button returns to the list.
        onTap: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NubFacultyDetailScreen(faculty: faculty),
          ),
        ),

        child: Ink(
          padding: const EdgeInsets.all(14),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [faculty.color, faculty.deepColor],
            ),
          ),

          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),

                child: Image.asset(
                  faculty.image,
                  width: 62,
                  height: 62,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'NEXT FACULTY',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .75),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      faculty.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 38,
                height: 38,

                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}