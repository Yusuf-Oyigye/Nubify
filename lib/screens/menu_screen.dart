import 'package:flutter/material.dart';

import '../services/marketplace_admin_service.dart';
import '../utils/marketplace_theme.dart';
import 'edit_profile_screen.dart';
import 'marketplace_screen.dart';
import 'my_marketplace_listings_screen.dart';
import 'saved_marketplace_listings_screen.dart';
import 'seller_verification_admin_screen.dart';
import 'seller_verification_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: MarketplaceTheme.heroGradient,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.apps_rounded, color: MarketplaceTheme.sky),
                SizedBox(height: 12),
                Text(
                  'Your Nubify',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Manage your profile, Marketplace activity, and trusted seller access.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _MenuTile(
            icon: Icons.storefront_rounded,
            color: MarketplaceTheme.sky,
            title: 'NUB Marketplace',
            subtitle: 'Discover products and student services',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const MarketplaceScreen(),
              ),
            ),
          ),
          _MenuTile(
            icon: Icons.inventory_2_outlined,
            color: MarketplaceTheme.copper,
            title: 'My Listings',
            subtitle: 'Manage available, sold, drafts and archived items',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const MyMarketplaceListingsScreen(),
              ),
            ),
          ),
          _MenuTile(
            icon: Icons.favorite_border_rounded,
            color: Colors.redAccent,
            title: 'Saved Listings',
            subtitle: 'Items and services you want to revisit',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SavedMarketplaceListingsScreen(),
              ),
            ),
          ),
          _MenuTile(
            icon: Icons.verified_user_outlined,
            color: MarketplaceTheme.emerald,
            title: 'Seller Verification',
            subtitle: 'Apply once or check your approval status',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SellerVerificationScreen(),
              ),
            ),
          ),
          FutureBuilder<MarketplaceAdminAccess>(
            future: MarketplaceAdminService().access(),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<MarketplaceAdminAccess> snapshot,
                ) {
                  if (snapshot.data?.canReview != true) {
                    return const SizedBox.shrink();
                  }
                  return _MenuTile(
                    icon: Icons.admin_panel_settings_rounded,
                    color: MarketplaceTheme.gold,
                    title: 'Marketplace Admin Dashboard',
                    subtitle:
                        'Review IDs, approve sellers, and manage trusted staff',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const SellerVerificationAdminScreen(),
                      ),
                    ),
                  );
                },
          ),
          const Divider(height: 30),
          _MenuTile(
            icon: Icons.manage_accounts_outlined,
            color: MarketplaceTheme.plum,
            title: 'Edit Profile & Contact',
            subtitle: 'Update your profile and private seller phone settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const EditProfileScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: MarketplaceTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.13),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
