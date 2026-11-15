import 'package:flutter/material.dart';

import '../utils/faculty_catalog.dart';

class FacultyIconBadge extends StatelessWidget {
  const FacultyIconBadge({
    super.key,
    required this.faculty,
    this.size = 42,
    this.iconSize = 22,
  });

  final NubifyFaculty faculty;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: faculty.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: faculty.color.withValues(alpha: 0.32)),
      ),
      child: Icon(faculty.icon, size: iconSize, color: faculty.color),
    );
  }
}

class FacultySelectionField extends StatelessWidget {
  const FacultySelectionField({
    super.key,
    required this.selectedId,
    required this.otherController,
    required this.onSelected,
  });

  final String? selectedId;
  final TextEditingController otherController;
  final ValueChanged<NubifyFaculty> onSelected;

  @override
  Widget build(BuildContext context) {
    final NubifyFaculty? selected = NubifyFacultyCatalog.byId(selectedId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Faculty',
            border: const OutlineInputBorder(),
            prefixIcon: selected == null
                ? const Icon(Icons.school_outlined)
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: FacultyIconBadge(
                      faculty: selected,
                      size: 38,
                      iconSize: 20,
                    ),
                  ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected?.id,
              isExpanded: true,
              hint: const Text('Choose your faculty'),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: NubifyFacultyCatalog.all.map((NubifyFaculty faculty) {
                return DropdownMenuItem<String>(
                  value: faculty.id,
                  child: Row(
                    children: <Widget>[
                      FacultyIconBadge(
                        faculty: faculty,
                        size: 36,
                        iconSize: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          faculty.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              selectedItemBuilder: (BuildContext context) {
                return NubifyFacultyCatalog.all.map((NubifyFaculty faculty) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      faculty.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: faculty.color,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }).toList();
              },
              onChanged: (String? id) {
                final NubifyFaculty? faculty = NubifyFacultyCatalog.byId(id);
                if (faculty != null) {
                  onSelected(faculty);
                }
              },
            ),
          ),
        ),
        if (selected?.isOther == true) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: otherController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Type your faculty',
              hintText: 'Enter your faculty name',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(8),
                child: FacultyIconBadge(
                  faculty: NubifyFacultyCatalog.other,
                  size: 38,
                  iconSize: 20,
                ),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}
