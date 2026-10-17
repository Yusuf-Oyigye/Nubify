import 'package:flutter/material.dart';

import '../models/marketplace_admin_audit.dart';
import '../services/marketplace_admin_service.dart';
import '../utils/marketplace_theme.dart';

//===================================================
// TRUSTED MARKETPLACE ADMIN AUDIT LOG
//===================================================

class MarketplaceAdminAuditScreen extends StatefulWidget {
  const MarketplaceAdminAuditScreen({super.key});

  @override
  State<MarketplaceAdminAuditScreen> createState() =>
      _MarketplaceAdminAuditScreenState();
}

class _MarketplaceAdminAuditScreenState
    extends State<MarketplaceAdminAuditScreen> {
  final MarketplaceAdminService _admin = MarketplaceAdminService();
  final TextEditingController _search = TextEditingController();
  late final Future<MarketplaceAdminAccess> _access;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _access = _admin.access(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace Audit Log')),
      body: FutureBuilder<MarketplaceAdminAccess>(
        future: _access,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<MarketplaceAdminAccess> accessSnapshot,
            ) {
              if (accessSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (accessSnapshot.data?.canReview != true) {
                return const _AuditState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Reviewer access required',
                  message:
                      'Only authorized Marketplace reviewers can read the server audit log.',
                );
              }
              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextField(
                      controller: _search,
                      onChanged: (String value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search action or account ID…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: MarketplaceTheme.softSurface(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<MarketplaceAdminAudit>>(
                      stream: _admin.watchAuditLog(),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<MarketplaceAdminAudit>> snapshot,
                          ) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return _AuditState(
                                icon: Icons.cloud_off_rounded,
                                title: 'Audit log could not load',
                                message: snapshot.error.toString(),
                              );
                            }
                            final List<MarketplaceAdminAudit> events =
                                (snapshot.data ??
                                        const <MarketplaceAdminAudit>[])
                                    .where(_matchesSearch)
                                    .toList(growable: false);
                            if (events.isEmpty) {
                              return _AuditState(
                                icon: Icons.history_rounded,
                                title: _query.isEmpty
                                    ? 'No administrative actions yet'
                                    : 'No matching audit records',
                                message: _query.isEmpty
                                    ? 'Trusted Marketplace actions will appear here automatically.'
                                    : 'Try a different action or account ID.',
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                              itemCount: events.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (BuildContext context, int index) =>
                                  _AuditCard(
                                    event: events[index],
                                    admin: _admin,
                                  ),
                            );
                          },
                    ),
                  ),
                ],
              );
            },
      ),
    );
  }

  bool _matchesSearch(MarketplaceAdminAudit event) {
    if (_query.isEmpty) {
      return true;
    }
    return event.action.toLowerCase().contains(_query) ||
        event.actorUid.toLowerCase().contains(_query) ||
        event.targetUid.toLowerCase().contains(_query) ||
        event.details.values.any(
          (dynamic value) => value.toString().toLowerCase().contains(_query),
        );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.event, required this.admin});

  final MarketplaceAdminAudit event;
  final MarketplaceAdminService admin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MarketplaceTheme.surface(context),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: _actionColor().withValues(alpha: 0.14),
                  child: Icon(_actionIcon(), color: _actionColor()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _actionLabel(event.action),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (event.createdAt != null)
                        Text(
                          _formatDateTime(context, event.createdAt!),
                          style: TextStyle(
                            fontSize: 11,
                            color: MarketplaceTheme.mutedText(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _IdentityLine(
              label: 'Performed by',
              uid: event.actorUid,
              admin: admin,
            ),
            _IdentityLine(
              label: 'Affected account',
              uid: event.targetUid,
              admin: admin,
            ),
            if (event.details.isNotEmpty) ...<Widget>[
              const Divider(height: 24),
              ...event.details.entries.map(
                (MapEntry<String, dynamic> detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '${_fieldLabel(detail.key)}: ${detail.value}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _actionColor() {
    if (event.action.contains('approved')) {
      return MarketplaceTheme.emerald;
    }
    if (event.action.contains('rejected')) {
      return Colors.orange;
    }
    if (event.action.contains('suspended') ||
        event.action.contains('removed')) {
      return Colors.redAccent;
    }
    return MarketplaceTheme.sky;
  }

  IconData _actionIcon() {
    if (event.action.contains('ownership')) {
      return Icons.workspace_premium_rounded;
    }
    if (event.action.contains('staff')) {
      return Icons.admin_panel_settings_rounded;
    }
    if (event.action.contains('report')) {
      return Icons.report_gmailerrorred_rounded;
    }
    return Icons.verified_user_outlined;
  }
}

class _IdentityLine extends StatelessWidget {
  const _IdentityLine({
    required this.label,
    required this.uid,
    required this.admin,
  });

  final String label;
  final String uid;
  final MarketplaceAdminService admin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: TextStyle(color: MarketplaceTheme.mutedText(context)),
            ),
          ),
          Expanded(
            child: FutureBuilder<String>(
              future: admin.userLabel(uid),
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                return SelectableText(
                  snapshot.data ?? uid,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditState extends StatelessWidget {
  const _AuditState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: MarketplaceTheme.sky, size: 58),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _actionLabel(String action) {
  return action
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

String _fieldLabel(String field) {
  final String spaced = field.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (Match match) => '${match.group(1)} ${match.group(2)}',
  );
  return _actionLabel(spaced.replaceAll(' ', '_'));
}

String _formatDateTime(BuildContext context, DateTime dateTime) {
  final MaterialLocalizations localizations = MaterialLocalizations.of(context);
  return '${localizations.formatFullDate(dateTime.toLocal())} · '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime.toLocal()))}';
}
