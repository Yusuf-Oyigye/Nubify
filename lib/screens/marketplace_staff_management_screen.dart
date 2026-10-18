import 'package:flutter/material.dart';

import '../services/marketplace_admin_service.dart';
import '../utils/marketplace_theme.dart';

//===================================================
// MARKETPLACE OWNER: STAFF AND OWNERSHIP MANAGEMENT
//===================================================

class MarketplaceStaffManagementScreen extends StatefulWidget {
  const MarketplaceStaffManagementScreen({super.key});

  @override
  State<MarketplaceStaffManagementScreen> createState() =>
      _MarketplaceStaffManagementScreenState();
}

class _MarketplaceStaffManagementScreenState
    extends State<MarketplaceStaffManagementScreen> {
  final MarketplaceAdminService _service = MarketplaceAdminService();
  final TextEditingController _emailController = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;

  Future<void> _search() async {
    if (_emailController.text.trim().isEmpty || _loading) {
      return;
    }
    setState(() => _loading = true);
    try {
      final Map<String, dynamic> result = await _service.findUserByEmail(
        _emailController.text,
      );
      if (mounted) {
        setState(() => _result = result);
      }
    } catch (error) {
      if (mounted) {
        _message(_friendly(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _setRole(String role, bool enabled) async {
    final String uid = (_result?['uid'] ?? '').toString();
    if (uid.isEmpty || _loading) {
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.setStaffRole(uid: uid, role: role, enabled: enabled);
      await _search();
      if (mounted) {
        _message(enabled ? 'Role granted.' : 'Role removed.');
      }
    } catch (error) {
      if (mounted) {
        _message(_friendly(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _transferOwnership() async {
    final String uid = (_result?['uid'] ?? '').toString();
    if (uid.isEmpty || _loading) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Transfer Marketplace ownership?'),
        content: const Text(
          'The selected account becomes the new Marketplace owner. Your account keeps its other staff roles but loses the power to manage ownership.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.transferOwnership(uid);
      if (!mounted) {
        return;
      }
      _message('Ownership transferred. Sign in again to refresh access.');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        _message(_friendly(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace Staff')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: MarketplaceTheme.heroGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.admin_panel_settings_rounded,
                  color: MarketplaceTheme.gold,
                ),
                SizedBox(height: 12),
                Text(
                  'Trusted access only',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Find an existing Nubify account by email, assign review roles, or securely transfer Marketplace ownership to your main account.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Nubify account email',
              prefixIcon: const Icon(Icons.manage_search_rounded),
              suffixIcon: IconButton(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search_rounded),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_loading) ...<Widget>[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_result != null) ...<Widget>[
            const SizedBox(height: 20),
            _UserRoleCard(
              user: _result!,
              disabled: _loading,
              onRoleChanged: _setRole,
              onTransferOwnership: _transferOwnership,
            ),
          ],
        ],
      ),
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _friendly(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}

class _UserRoleCard extends StatelessWidget {
  const _UserRoleCard({
    required this.user,
    required this.disabled,
    required this.onRoleChanged,
    required this.onTransferOwnership,
  });

  final Map<String, dynamic> user;
  final bool disabled;
  final Future<void> Function(String role, bool enabled) onRoleChanged;
  final VoidCallback onTransferOwnership;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> roles = user['roles'] is Map
        ? Map<String, dynamic>.from(user['roles'] as Map)
        : <String, dynamic>{};
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: MarketplaceTheme.premiumCard(context),
      child: Column(
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 28,
              backgroundImage: (user['photoUrl'] ?? '').toString().isEmpty
                  ? null
                  : NetworkImage(user['photoUrl'].toString()),
              child: (user['photoUrl'] ?? '').toString().isEmpty
                  ? const Icon(Icons.person_rounded)
                  : null,
            ),
            title: Text(
              (user['fullName'] ?? user['email'] ?? 'Nubify user').toString(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text((user['email'] ?? '').toString()),
          ),
          const Divider(),
          SwitchListTile.adaptive(
            value: roles['marketplaceReviewer'] == true,
            onChanged: disabled
                ? null
                : (bool value) => onRoleChanged('marketplaceReviewer', value),
            title: const Text('Marketplace report reviewer'),
            subtitle: const Text(
              'Can inspect private applications and decide them.',
            ),
          ),
          SwitchListTile.adaptive(
            value: roles['moderator'] == true,
            onChanged: disabled
                ? null
                : (bool value) => onRoleChanged('moderator', value),
            title: const Text('Moderator'),
            subtitle: const Text(
              'Can review sellers and moderate Marketplace activity.',
            ),
          ),
          SwitchListTile.adaptive(
            value: roles['admin'] == true,
            onChanged: disabled
                ? null
                : (bool value) => onRoleChanged('admin', value),
            title: const Text('Administrator'),
            subtitle: const Text('Broad Marketplace administrative access.'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: disabled ? null : onTransferOwnership,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Make this account the Marketplace owner'),
            style: OutlinedButton.styleFrom(
              foregroundColor: MarketplaceTheme.gold,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }
}
