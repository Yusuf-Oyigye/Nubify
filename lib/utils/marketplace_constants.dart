import 'package:flutter/material.dart';

//===================================================
// NUB MARKETPLACE DOMAIN CONSTANTS
//===================================================

class MarketplaceCategory {
  const MarketplaceCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

abstract final class MarketplaceConstants {
  static const int maxMediaCount = 5;
  static const int pageSize = 20;
  static const String currency = 'EGP';

  static const List<MarketplaceCategory> categories = <MarketplaceCategory>[
    MarketplaceCategory(
      id: 'textbooks_books',
      label: 'Textbooks & Books',
      icon: Icons.menu_book_rounded,
    ),
    MarketplaceCategory(
      id: 'food_snacks',
      label: 'Food & Snacks',
      icon: Icons.restaurant_rounded,
    ),
    MarketplaceCategory(
      id: 'printing_photocopying',
      label: 'Printing & Photocopying',
      icon: Icons.print_rounded,
    ),
    MarketplaceCategory(
      id: 'medical_laboratory',
      label: 'Medical & Laboratory Items',
      icon: Icons.biotech_rounded,
    ),
    MarketplaceCategory(
      id: 'rent_housing',
      label: 'Rent & Housing',
      icon: Icons.apartment_rounded,
    ),
    MarketplaceCategory(
      id: 'electrical_gadgets',
      label: 'Electrical Gadgets',
      icon: Icons.devices_other_rounded,
    ),
    MarketplaceCategory(
      id: 'clothes_fashion',
      label: 'Clothes & Fashion',
      icon: Icons.checkroom_rounded,
    ),
    MarketplaceCategory(
      id: 'furniture_room',
      label: 'Furniture & Room Essentials',
      icon: Icons.chair_rounded,
    ),
    MarketplaceCategory(
      id: 'watches_accessories',
      label: 'Watches & Accessories',
      icon: Icons.watch_rounded,
    ),
    MarketplaceCategory(
      id: 'student_services',
      label: 'Student Services',
      icon: Icons.design_services_rounded,
    ),
    MarketplaceCategory(
      id: 'beauty_personal_care',
      label: 'Beauty & Personal Care',
      icon: Icons.spa_rounded,
    ),
    MarketplaceCategory(
      id: 'other',
      label: 'Other',
      icon: Icons.category_rounded,
    ),
  ];

  static const List<String> conditions = <String>['new', 'used', 'service'];

  static const List<String> listingStatuses = <String>[
    'draft',
    'available',
    'sold',
    'unavailable',
    'archived',
  ];

  static const List<String> reportReasons = <String>[
    'Scam or Fraud',
    'Misleading Information',
    'Prohibited Item',
    'Inappropriate Content',
    'Duplicate Listing',
    'Other',
  ];

  static String categoryLabel(String id) {
    for (final MarketplaceCategory category in categories) {
      if (category.id == id) {
        return category.label;
      }
    }
    return 'Other';
  }

  static String conditionLabel(String value) {
    switch (value) {
      case 'new':
        return 'New';
      case 'used':
        return 'Used';
      case 'service':
        return 'Service';
      default:
        return 'Used';
    }
  }

  static List<String> buildSearchPrefixes(Iterable<String> parts) {
    final List<String> words = parts
        .join(' ')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .take(30)
        .toList(growable: false);
    final Set<String> prefixes = <String>{};
    for (final String word in words) {
      final int maximum = word.length > 30 ? 30 : word.length;
      for (int size = 1; size <= maximum; size++) {
        prefixes.add(word.substring(0, size));
        if (prefixes.length >= 20) {
          return prefixes.toList(growable: false);
        }
      }
    }
    return prefixes.toList(growable: false);
  }
}
