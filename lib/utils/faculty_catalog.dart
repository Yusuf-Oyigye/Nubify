import 'package:flutter/material.dart';

@immutable
class NubifyFaculty {
  const NubifyFaculty({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isOther = false,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isOther;
}

abstract final class NubifyFacultyCatalog {
  static const NubifyFaculty medicine = NubifyFaculty(
    id: 'medicine',
    name: 'Faculty of Medicine',
    icon: Icons.medical_services_rounded,
    color: Color(0xFFE05252),
  );

  static const NubifyFaculty dentalMedicine = NubifyFaculty(
    id: 'oral_dental_medicine',
    name: 'Faculty of Oral and Dental Medicine',
    icon: Icons.health_and_safety_rounded,
    color: Color(0xFF12A7B8),
  );

  static const NubifyFaculty pharmacy = NubifyFaculty(
    id: 'pharmacy',
    name: 'Faculty of Pharmacy',
    icon: Icons.local_pharmacy_rounded,
    color: Color(0xFF2EAD70),
  );

  static const NubifyFaculty engineering = NubifyFaculty(
    id: 'engineering',
    name: 'Faculty of Engineering',
    icon: Icons.engineering_rounded,
    color: Color(0xFFF28C28),
  );

  static const NubifyFaculty computerScience = NubifyFaculty(
    id: 'computer_science',
    name: 'Faculty of Computer Science',
    icon: Icons.computer_rounded,
    color: Color(0xFF536DFE),
  );

  static const NubifyFaculty businessAdministration = NubifyFaculty(
    id: 'business_administration',
    name: 'Faculty of Business Administration',
    icon: Icons.business_center_rounded,
    color: Color(0xFFD59B18),
  );

  static const NubifyFaculty massCommunication = NubifyFaculty(
    id: 'mass_communication_languages',
    name: 'Faculty of Mass Communication and Applied Languages',
    icon: Icons.record_voice_over_rounded,
    color: Color(0xFFC6539B),
  );

  static const NubifyFaculty physicalTherapy = NubifyFaculty(
    id: 'physical_therapy',
    name: 'Faculty of Physical Therapy',
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFF00897B),
  );

  static const NubifyFaculty fineArts = NubifyFaculty(
    id: 'fine_arts',
    name: 'Faculty of Fine Arts',
    icon: Icons.palette_rounded,
    color: Color(0xFF8E5AD7),
  );

  static const NubifyFaculty nursing = NubifyFaculty(
    id: 'nursing',
    name: 'Faculty of Nursing',
    icon: Icons.volunteer_activism_rounded,
    color: Color(0xFFE76F8A),
  );

  static const NubifyFaculty other = NubifyFaculty(
    id: 'other',
    name: 'Others',
    icon: Icons.school_outlined,
    color: Color(0xFF607D8B),
    isOther: true,
  );

  static const List<NubifyFaculty> all = <NubifyFaculty>[
    medicine,
    dentalMedicine,
    pharmacy,
    engineering,
    computerScience,
    businessAdministration,
    massCommunication,
    physicalTherapy,
    fineArts,
    nursing,
    other,
  ];

  static NubifyFaculty? byId(String? id) {
    if (id == null || id.trim().isEmpty) {
      return null;
    }

    for (final NubifyFaculty faculty in all) {
      if (faculty.id == id) {
        return faculty;
      }
    }
    return null;
  }

  static NubifyFaculty? exactMatch(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    for (final NubifyFaculty faculty in all) {
      if (!faculty.isOther && faculty.name.toLowerCase() == normalized) {
        return faculty;
      }
    }
    return null;
  }

  static String? selectionIdFor(String value) {
    final String cleanValue = value.trim();
    if (cleanValue.isEmpty) {
      return null;
    }
    return exactMatch(cleanValue)?.id ?? other.id;
  }

  static NubifyFaculty displayFor(String value) {
    return exactMatch(value) ?? other;
  }
}
