import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/marketplace/marketplace_admin_service.dart';
import '../../utils/marketplace/marketplace_theme.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// MARKETPLACE REPORT MODERATION DASHBOARD
//===================================================

class MarketplaceReportsAdminScreen extends StatefulWidget {
  const MarketplaceReportsAdminScreen({super.key});

  @override
  State<MarketplaceReportsAdminScreen> createState() =>
      _MarketplaceReportsAdminScreenState();
}

class _MarketplaceReportsAdminScreenState
    extends State<MarketplaceReportsAdminScreen> {
  final MarketplaceAdminService _admin = MarketplaceAdminService();
  late final Future<MarketplaceAdminAccess> _access = _admin.access(
    forceRefresh: true,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MarketplaceAdminAccess>(
      future: _access,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<MarketplaceAdminAccess> accessSnapshot,
          ) {
            if (accessSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (accessSnapshot.data?.canReview != true) {
              return Scaffold(
                appBar: AppBar(title: Text(context.tr('Listing Reports'))),
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(context.tr('A trusted Marketplace reviewer account is required.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            return DefaultTabController(
              length: 4,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(context.tr('Listing Reports')),
                  bottom: TabBar(
                    isScrollable: true,
                    tabs: <Widget>[
                      Tab(text: context.tr('Submitted')),
                      Tab(text: context.tr('Reviewing')),
                      Tab(text: context.tr('Resolved')),
                      Tab(text: context.tr('Dismissed')),
                    ],
                  ),
                ),
                body: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _admin.watchReports(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                      ) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                context.tr('Unable to load reports: {error}', {
                                  'error': '${snapshot.error}',
                                }),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        final List<Map<String, dynamic>> reports =
                            snapshot.data ?? const <Map<String, dynamic>>[];
                        return TabBarView(
                          children: <Widget>[
                            _ReportList(
                              reports: reports,
                              status: 'submitted',
                              admin: _admin,
                            ),
                            _ReportList(
                              reports: reports,
                              status: 'reviewing',
                              admin: _admin,
                            ),
                            _ReportList(
                              reports: reports,
                              status: 'resolved',
                              admin: _admin,
                            ),
                            _ReportList(
                              reports: reports,
                              status: 'dismissed',
                              admin: _admin,
                            ),
                          ],
                        );
                      },
                ),
              ),
            );
          },
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({
    required this.reports,
    required this.status,
    required this.admin,
  });

  final List<Map<String, dynamic>> reports;
  final String status;
  final MarketplaceAdminService admin;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> filtered = reports
        .where((Map<String, dynamic> item) => item['status'] == status)
        .toList(growable: false);
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.fact_check_outlined,
                size: 58,
                color: MarketplaceTheme.sky,
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('No {status} reports', {
                  'status': context.tr(status),
                }),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) =>
          _ReportCard(report: filtered[index], admin: admin),
    );
  }
}

class _ReportCard extends StatefulWidget {
  const _ReportCard({required this.report, required this.admin});

  final Map<String, dynamic> report;
  final MarketplaceAdminService admin;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _working = false;

  String get _reportId => (widget.report['reportId'] ?? '').toString();
  String get _listingId => (widget.report['listingId'] ?? '').toString();
  String get _sellerId => (widget.report['sellerId'] ?? '').toString();
  String get _status => (widget.report['status'] ?? 'submitted').toString();

  Future<String?> _askForNote(String title) async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: 1000,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: context.tr('Moderator note'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final String note = controller.text.trim();
              if (note.length < 3) {
                return;
              }
              Navigator.pop(dialogContext, note);
            },
            child: Text(context.tr('Confirm')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _review(String decision) async {
    if (_working) {
      return;
    }
    String note = '';
    if (decision != 'reviewing') {
      note =
          await _askForNote(
            decision == 'resolved' ? context.tr('Resolve report') : context.tr('Dismiss report'),
          ) ??
          '';
      if (note.isEmpty) {
        return;
      }
    }
    setState(() => _working = true);
    try {
      await widget.admin.reviewReport(
        reportId: _reportId,
        decision: decision,
        resolutionNote: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Report moved to {status}.', {
                'status': context.tr(decision),
              }),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Could not update report: {error}', {
                'error': '$error',
              }),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dynamic rawCreatedAt = widget.report['createdAt'];
    final String created = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate().toLocal().toString().split('.').first
        : context.tr('Pending timestamp');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: MarketplaceTheme.premiumCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  (widget.report['reason'] ?? context.tr('Report')).toString(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Chip(label: Text(_status.toUpperCase())),
            ],
          ),
          Text(context.tr('Submitted: {date}', {'date': created})),
          const SizedBox(height: 8),
          Text(
            (widget.report['explanation'] ?? '').toString().trim().isEmpty
                ? context.tr('No additional explanation.')
                : (widget.report['explanation'] ?? '').toString(),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Listing: {listing}\nSeller: {seller}', {
              'listing': _listingId,
              'seller': _sellerId,
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _working
                    ? null
                    : () => Navigator.pushNamed<void>(
                        context,
                        '/marketplace/listing',
                        arguments: _listingId,
                      ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(context.tr('Open Listing')),
              ),
              if (_status == 'submitted')
                FilledButton.tonal(
                  onPressed: _working ? null : () => _review('reviewing'),
                  child: Text(context.tr('Start Review')),
                ),
              if (_status == 'submitted' || _status == 'reviewing') ...<Widget>[
                FilledButton(
                  onPressed: _working ? null : () => _review('resolved'),
                  child: Text(context.tr('Resolve')),
                ),
                OutlinedButton(
                  onPressed: _working ? null : () => _review('dismissed'),
                  child: Text(context.tr('Dismiss')),
                ),
              ],
            ],
          ),
          if (_working) ...<Widget>[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
