import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/marketplace_admin_service.dart';
import '../utils/marketplace_theme.dart';

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
                appBar: AppBar(title: const Text('Listing Reports')),
                body: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'A trusted Marketplace reviewer account is required.',
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
                  title: const Text('Listing Reports'),
                  bottom: const TabBar(
                    isScrollable: true,
                    tabs: <Widget>[
                      Tab(text: 'Submitted'),
                      Tab(text: 'Reviewing'),
                      Tab(text: 'Resolved'),
                      Tab(text: 'Dismissed'),
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
                                'Unable to load reports: ${snapshot.error}',
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
                'No $status reports',
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
          decoration: const InputDecoration(
            labelText: 'Moderator note',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final String note = controller.text.trim();
              if (note.length < 3) {
                return;
              }
              Navigator.pop(dialogContext, note);
            },
            child: const Text('Confirm'),
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
            decision == 'resolved' ? 'Resolve report' : 'Dismiss report',
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
        ).showSnackBar(SnackBar(content: Text('Report moved to $decision.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update report: $error')),
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
        : 'Pending timestamp';
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
                  (widget.report['reason'] ?? 'Report').toString(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Chip(label: Text(_status.toUpperCase())),
            ],
          ),
          Text('Submitted: $created'),
          const SizedBox(height: 8),
          Text(
            (widget.report['explanation'] ?? '').toString().trim().isEmpty
                ? 'No additional explanation.'
                : (widget.report['explanation'] ?? '').toString(),
          ),
          const SizedBox(height: 8),
          Text(
            'Listing: $_listingId\nSeller: $_sellerId',
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
                label: const Text('Open Listing'),
              ),
              if (_status == 'submitted')
                FilledButton.tonal(
                  onPressed: _working ? null : () => _review('reviewing'),
                  child: const Text('Start Review'),
                ),
              if (_status == 'submitted' || _status == 'reviewing') ...<Widget>[
                FilledButton(
                  onPressed: _working ? null : () => _review('resolved'),
                  child: const Text('Resolve'),
                ),
                OutlinedButton(
                  onPressed: _working ? null : () => _review('dismissed'),
                  child: const Text('Dismiss'),
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
