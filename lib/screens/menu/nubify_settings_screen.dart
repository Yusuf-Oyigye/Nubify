import 'package:flutter/material.dart';

import '../../widgets/profile/delete_account_dialog.dart';
import '../../widgets/menu/nubify_menu_components.dart';
import 'nubify_information_screens.dart';
//===================================================
// NUBIFY — PREMIUM SETTINGS SCREEN
//===================================================

class NubifySettingsScreen extends StatelessWidget {
  const NubifySettingsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return NubifyMenuPage(
      title: 'Settings',

      subtitle:
      'Personalize your Nubify experience.',

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,

        children: [
          //=========================================
          // APPEARANCE
          //=========================================

          Text(
            'Appearance',

            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color:
              NubifyMenuColors.primaryText(
                context,
              ),
            ),
          ),

          const SizedBox(height: 13),

          const NubifyAppearanceSelector(),

          const SizedBox(height: 25),

          //=========================================
          // INFORMATION
          //=========================================

          Text(
            'Information',

            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color:
              NubifyMenuColors.primaryText(
                context,
              ),
            ),
          ),

          const SizedBox(height: 13),

          //=========================================
          // ABOUT THE APP
          //=========================================

          _SettingsLink(
            label: 'About the App',
            icon: Icons.info_outline_rounded,
            color: nubifySky,

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                  const NubifyAboutAppScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 11),

          //=========================================
          // TERMS AND CONDITIONS
          //=========================================

          _SettingsLink(
            label: 'Terms and Conditions',
            icon: Icons.gavel_outlined,
            color: NubifyPalette.teal,

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                  const NubifyLegalScreen(
                    type: NubifyLegalType.terms,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 11),

          //=========================================
          // PRIVACY POLICY
          //=========================================

          _SettingsLink(
            label: 'Privacy Policy',
            icon: Icons.shield_outlined,
            color: NubifyPalette.emerald,

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                  const NubifyLegalScreen(
                    type: NubifyLegalType.privacy,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 25),

          //=========================================
          // ACCOUNT
          //=========================================

          Text(
            'Account',

            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color:
              NubifyMenuColors.primaryText(
                context,
              ),
            ),
          ),

          const SizedBox(height: 13),

          //=========================================
          // DELETE ACCOUNT
          //=========================================

          _SettingsLink(
            label: 'Delete Account',
            icon: Icons.delete_forever_outlined,
            color: NubifyPalette.crimson,

            onTap: () {
              confirmDeleteAccount(context);
            },
          ),
        ],
      ),
    );
  }
}

//===================================================
// SETTINGS ROW
//===================================================

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NubifyMenuColors.surface(context),

      borderRadius:
      BorderRadius.circular(19),

      child: InkWell(
        onTap: onTap,

        borderRadius:
        BorderRadius.circular(19),

        child: Padding(
          padding: const EdgeInsets.all(13),

          child: Row(
            children: [
              NubifyIconTile(
                icon: icon,
                color: color,
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Text(
                  label,

                  style: TextStyle(
                    color:
                    NubifyMenuColors.primaryText(
                      context,
                    ),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                color:
                NubifyMenuColors.secondaryText(
                  context,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}