import 'package:flutter/material.dart';

import '../../models/faculties/nub_faculty.dart';
import '../../widgets/menu/nubify_menu_components.dart';
import 'nub_faculty_detail_screen.dart';

//===================================================
// NUB — FACULTIES & PROGRAMMES
//===================================================

class NubFacultiesScreen extends StatefulWidget {
  const NubFacultiesScreen({super.key});

  @override
  State<NubFacultiesScreen> createState() => _NubFacultiesScreenState();
}

class _NubFacultiesScreenState extends State<NubFacultiesScreen> {
  // null means the "All" chip is selected.
  NubFacultyField? _field;

  @override
  Widget build(BuildContext context) {
    final faculties = _field == null
        ? nubFaculties
        : nubFaculties.where((f) => f.field == _field).toList();

    return NubifyMenuPage(
      title: 'Faculties & Programmes',

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          const _FacultiesHeader(),

          const SizedBox(height: 22),

          _FieldFilter(
            selected: _field,
            onChanged: (field) => setState(() => _field = field),
          ),

          const SizedBox(height: 18),

          //=========================================
          // FACULTY GRID
          //=========================================
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),

            child: LayoutBuilder(
              key: ValueKey(_field),

              builder: (context, constraints) {
                final columns = constraints.maxWidth < 330 ? 1 : 2;

                final cardWidth =
                    (constraints.maxWidth - 14 * (columns - 1)) / columns;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: faculties.length,

                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                    mainAxisExtent:
                    cardWidth +
                        MediaQuery.textScalerOf(context).scale(76),
                  ),

                  itemBuilder: (context, index) =>
                      _FacultyCard(faculty: faculties[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// PREMIUM NAVY HEADER
//===================================================

class _FacultiesHeader extends StatelessWidget {
  const _FacultiesHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),

        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1F45), Color(0xFF103A75), Color(0xFF2560B8)],
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF103A75).withValues(alpha: .30),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),

      child: Stack(
        children: [
          // Soft decorative glow circles
          const Positioned(top: -50, right: -40, child: _GlowCircle(size: 170)),
          const Positioned(bottom: -70, right: 70, child: _GlowCircle(size: 130)),

          Padding(
            padding: const EdgeInsets.all(22),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .18),
                    ),
                  ),

                  child: const Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Icon(Icons.school_rounded, color: Colors.white, size: 15),
                      SizedBox(width: 6),
                      Text(
                        'NAHDA UNIVERSITY · NUB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Find your faculty',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Explore programmes in health, technology, business, media and the arts.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .80),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 20),

                const Row(
                  children: [
                    Expanded(child: _HeaderStat(value: '10', label: 'Faculties')),
                    SizedBox(width: 10),
                    Expanded(child: _HeaderStat(value: '4', label: 'Fields')),
                    SizedBox(width: 10),
                    Expanded(child: _HeaderStat(value: '2006', label: 'Founded')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .07),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .72),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// FIELD FILTER CHIPS
//===================================================

class _FieldFilter extends StatelessWidget {
  const _FieldFilter({required this.selected, required this.onChanged});

  final NubFacultyField? selected;
  final ValueChanged<NubFacultyField?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,

      child: ListView(
        scrollDirection: Axis.horizontal,

        children: [
          _FilterChip(
            label: 'All',
            icon: Icons.apps_rounded,
            selected: selected == null,
            onTap: () => onChanged(null),
          ),

          for (final field in NubFacultyField.values)
            _FilterChip(
              label: field.label,
              icon: field.icon,
              selected: selected == field,
              onTap: () => onChanged(field),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = selected
        ? Colors.white
        : NubifyMenuColors.primaryText(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),

      child: GestureDetector(
        onTap: onTap,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,

          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
              colors: [Color(0xFF103A75), Color(0xFF2560B8)],
            )
                : null,
            color: selected ? null : NubifyMenuColors.surface(context),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : NubifyMenuColors.stroke(context),
            ),
          ),

          child: Row(
            mainAxisSize: MainAxisSize.min,

            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//===================================================
// FACULTY CARD
//===================================================

class _FacultyCard extends StatelessWidget {
  const _FacultyCard({required this.faculty});

  final NubFaculty faculty;

  @override
  Widget build(BuildContext context) {
    final dark = NubifyMenuColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: NubifyMenuColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NubifyMenuColors.stroke(context)),

        boxShadow: [
          BoxShadow(
            color: faculty.color.withValues(alpha: dark ? .06 : .10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Material(
        type: MaterialType.transparency,

        child: InkWell(
          borderRadius: BorderRadius.circular(24),

          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NubFacultyDetailScreen(faculty: faculty),
            ),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              //=====================================
              // POSTER IMAGE + NUMBER BADGE
              //=====================================
              Padding(
                padding: const EdgeInsets.all(6),

                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),

                  child: Stack(
                    children: [
                      AspectRatio(
                        // Slightly wider than tall, so the white label
                        // strip at the bottom of each poster is cut off.
                        aspectRatio: 1.03,

                        child: Hero(
                          tag: 'nub-faculty-${faculty.id}',

                          child: Image.asset(
                            faculty.image,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                      ),

                      Positioned(
                        top: 8,
                        left: 8,

                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),

                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .38),
                            borderRadius: BorderRadius.circular(20),
                          ),

                          child: Text(
                            faculty.number,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              //=====================================
              // NAME + ARROW
              //=====================================
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 10, 10),

                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [
                            Text(
                              faculty.shortName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: NubifyMenuColors.primaryText(context),
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              faculty.field.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: faculty.color,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 6),

                      Container(
                        width: 30,
                        height: 30,

                        decoration: BoxDecoration(
                          color: NubifyMenuColors.tint(context, faculty.color),
                          shape: BoxShape.circle,
                        ),

                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: faculty.color,
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
    );
  }
}