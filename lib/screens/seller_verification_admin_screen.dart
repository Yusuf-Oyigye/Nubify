import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/seller_verification.dart';
import '../models/seller_verification_history.dart';
import '../services/marketplace_admin_service.dart';
import '../services/seller_verification_service.dart';
import '../utils/marketplace_theme.dart';
import 'marketplace_admin_audit_screen.dart';
import 'marketplace_reports_admin_screen.dart';
import 'marketplace_staff_management_screen.dart';

//===================================================
// SELLER VERIFICATION ADMIN DASHBOARD
//===================================================

class SellerVerificationAdminScreen extends StatefulWidget {
  const SellerVerificationAdminScreen({super.key});

  @override
  State<SellerVerificationAdminScreen> createState() =>
      _SellerVerificationAdminScreenState();
}

class _SellerVerificationAdminScreenState
    extends State<SellerVerificationAdminScreen> {
  final MarketplaceAdminService _admin = MarketplaceAdminService();
  late Future<MarketplaceAdminAccess> _access;

  @override
  void initState() {
    super.initState();
    _access = _admin.access(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MarketplaceAdminAccess>(
      future: _access,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<MarketplaceAdminAccess> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final MarketplaceAdminAccess access =
                snapshot.data ??
                const MarketplaceAdminAccess(
                  isOwner: false,
                  isAdmin: false,
                  isModerator: false,
                  isReviewer: false,
                );
            if (!access.canReview) {
              return Scaffold(
                appBar: AppBar(title: const Text('Marketplace Admin')),
                body: const _AccessDenied(),
              );
            }
            return DefaultTabController(
              length: 4,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Seller Approvals'),
                  actions: <Widget>[
                    IconButton(
                      tooltip: 'View secure audit log',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const MarketplaceAdminAuditScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.history_rounded),
                    ),
                    IconButton(
                      tooltip: 'Review listing reports',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const MarketplaceReportsAdminScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.report_gmailerrorred_rounded),
                    ),
                    if (access.canManageStaff)
                      IconButton(
                        tooltip: 'Manage Marketplace staff',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const MarketplaceStaffManagementScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.admin_panel_settings_rounded),
                      ),
                  ],
                  bottom: const TabBar(
                    isScrollable: true,
                    tabs: <Widget>[
                      Tab(text: 'Pending'),
                      Tab(text: 'Approved'),
                      Tab(text: 'Rejected'),
                      Tab(text: 'Suspended'),
                    ],
                  ),
                ),
                body: const TabBarView(
                  children: <Widget>[
                    _ApplicationsTab(status: 'pending'),
                    _ApplicationsTab(status: 'approved'),
                    _ApplicationsTab(status: 'rejected'),
                    _ApplicationsTab(status: 'suspended'),
                  ],
                ),
              ),
            );
          },
    );
  }
}

class _ApplicationsTab extends StatefulWidget {
  const _ApplicationsTab({required this.status});

  final String status;

  @override
  State<_ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<_ApplicationsTab> {
  final MarketplaceAdminService _admin = MarketplaceAdminService();
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (String value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search name, student ID, or account ID…',
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
          child: StreamBuilder<List<SellerVerification>>(
            stream: _admin.watchApplications(widget.status),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<SellerVerification>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _AdminState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load applications',
                      message: snapshot.error.toString(),
                    );
                  }
                  final List<SellerVerification> applications =
                      (snapshot.data ?? const <SellerVerification>[])
                          .where(_matchesSearch)
                          .toList(growable: false);
                  if (applications.isEmpty) {
                    return _AdminState(
                      icon: widget.status == 'pending'
                          ? Icons.task_alt_rounded
                          : Icons.inbox_outlined,
                      title: _query.isNotEmpty
                          ? 'No matching applications'
                          : widget.status == 'pending'
                          ? 'No applications waiting'
                          : 'No ${widget.status} applications',
                      message: _query.isNotEmpty
                          ? 'Try another name, student ID, or account ID.'
                          : widget.status == 'pending'
                          ? 'New student seller applications will appear here.'
                          : 'There is nothing in this section yet.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: applications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final SellerVerification application =
                          applications[index];
                      return Material(
                        color: MarketplaceTheme.surface(context),
                        borderRadius: BorderRadius.circular(18),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.3),
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(
                              widget.status,
                            ).withValues(alpha: 0.15),
                            child: Icon(
                              Icons.badge_outlined,
                              color: _statusColor(widget.status),
                            ),
                          ),
                          title: Text(
                            application.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Student ID: ${application.studentIdNumber}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => _VerificationReviewScreen(
                                verification: application,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
          ),
        ),
      ],
    );
  }

  bool _matchesSearch(SellerVerification application) {
    if (_query.isEmpty) {
      return true;
    }
    return application.fullName.toLowerCase().contains(_query) ||
        application.studentIdNumber.toLowerCase().contains(_query) ||
        application.uid.toLowerCase().contains(_query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'approved':
        return MarketplaceTheme.emerald;
      case 'rejected':
        return Colors.orange;
      case 'suspended':
        return Colors.redAccent;
      default:
        return MarketplaceTheme.sky;
    }
  }
}

class _VerificationReviewScreen extends StatefulWidget {
  const _VerificationReviewScreen({required this.verification});

  final SellerVerification verification;

  @override
  State<_VerificationReviewScreen> createState() =>
      _VerificationReviewScreenState();
}

class _VerificationReviewScreenState extends State<_VerificationReviewScreen> {
  final MarketplaceAdminService _admin = MarketplaceAdminService();
  final SellerVerificationService _verification = SellerVerificationService();
  bool _working = false;

  Future<void> _decide(String decision) async {
    String reason = '';
    if (decision != 'approved') {
      final TextEditingController controller = TextEditingController();
      final String? entered = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(
            decision == 'rejected' ? 'Reject application' : 'Suspend seller',
          ),
          content: TextField(
            controller: controller,
            maxLength: 500,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Clear reason',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (entered == null || entered.trim().length < 3) {
        return;
      }
      reason = entered.trim();
    }

    setState(() => _working = true);
    try {
      await _admin.review(
        applicantUid: widget.verification.uid,
        decision: decision,
        reason: reason,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Seller verification $decision.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SellerVerification item = widget.verification;
    return Scaffold(
      appBar: AppBar(title: const Text('Review Student Seller')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          FutureBuilder<Uint8List?>(
            future: _verification.loadPrivateIdImage(item.studentIdStoragePath),
            builder:
                (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
                  return AspectRatio(
                    aspectRatio: 1.6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: ColoredBox(
                        color: MarketplaceTheme.softSurface(context),
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                            ? const Center(child: CircularProgressIndicator())
                            : snapshot.data == null
                            ? const Center(
                                child: Text('Private ID image unavailable'),
                              )
                            : InteractiveViewer(
                                child: Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                      ),
                    ),
                  );
                },
          ),
          const SizedBox(height: 18),
          _DetailRow(label: 'Full name', value: item.fullName),
          _DetailRow(label: 'Student ID number', value: item.studentIdNumber),
          _DetailRow(label: 'Status', value: item.status),
          if (item.submittedAt != null)
            _DetailRow(
              label: 'Submitted',
              value: _formatAdminDateTime(context, item.submittedAt!),
            ),
          if (item.reviewedAt != null)
            _DetailRow(
              label: 'Last reviewed',
              value: _formatAdminDateTime(context, item.reviewedAt!),
            ),
          if (item.reviewedBy.isNotEmpty)
            FutureBuilder<String>(
              future: _admin.userLabel(item.reviewedBy),
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) =>
                  _DetailRow(
                    label: 'Reviewed by',
                    value: snapshot.data ?? item.reviewedBy,
                  ),
            ),
          if (item.rejectionReason.isNotEmpty)
            _DetailRow(label: 'Rejection reason', value: item.rejectionReason),
          if (item.suspensionReason.isNotEmpty)
            _DetailRow(
              label: 'Suspension reason',
              value: item.suspensionReason,
            ),
          const SizedBox(height: 12),
          Text(
            'Decision History',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _VerificationHistory(applicantUid: item.uid, admin: _admin),
          const SizedBox(height: 20),
          if (_working) const LinearProgressIndicator(),
          if (item.status == 'pending') ...<Widget>[
            FilledButton.icon(
              onPressed: _working ? null : () => _decide('approved'),
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Approve Seller'),
              style: FilledButton.styleFrom(
                backgroundColor: MarketplaceTheme.emerald,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _working ? null : () => _decide('rejected'),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Reject with Reason'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
          if (item.status == 'approved')
            OutlinedButton.icon(
              onPressed: _working ? null : () => _decide('suspended'),
              icon: const Icon(Icons.block_rounded),
              label: const Text('Suspend Selling Access'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: MarketplaceTheme.mutedText(context)),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationHistory extends StatelessWidget {
  const _VerificationHistory({required this.applicantUid, required this.admin});

  final String applicantUid;
  final MarketplaceAdminService admin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SellerVerificationHistory>>(
      stream: admin.watchVerificationHistory(applicantUid),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<SellerVerificationHistory>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (snapshot.hasError) {
              return Text(
                'History could not load: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              );
            }
            final List<SellerVerificationHistory> events =
                snapshot.data ?? const <SellerVerificationHistory>[];
            if (events.isEmpty) {
              return const Text('No decision history has been recorded yet.');
            }
            return Column(
              children: events
                  .map(
                    (SellerVerificationHistory event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: MarketplaceTheme.softSurface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  _historyIcon(event.action),
                                  color: _historyColor(event.action),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _historyActionLabel(event.action),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (event.createdAt != null)
                                  Text(
                                    _formatAdminDateTime(
                                      context,
                                      event.createdAt!,
                                    ),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: MarketplaceTheme.mutedText(
                                        context,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            FutureBuilder<String>(
                              future: admin.userLabel(event.actorUid),
                              builder:
                                  (
                                    BuildContext context,
                                    AsyncSnapshot<String> actor,
                                  ) => Text(
                                    'By: ${actor.data ?? event.actorUid}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                            ),
                            if (event.reason.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 5),
                              Text(
                                'Reason: ${event.reason}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
    );
  }
}

String _historyActionLabel(String action) {
  switch (action) {
    case 'submitted':
      return 'Application Submitted';
    case 'approved':
      return 'Seller Approved';
    case 'rejected':
      return 'Application Rejected';
    case 'suspended':
      return 'Seller Suspended';
    default:
      return action;
  }
}

IconData _historyIcon(String action) {
  switch (action) {
    case 'approved':
      return Icons.verified_rounded;
    case 'rejected':
      return Icons.cancel_outlined;
    case 'suspended':
      return Icons.block_rounded;
    default:
      return Icons.upload_file_rounded;
  }
}

Color _historyColor(String action) {
  switch (action) {
    case 'approved':
      return MarketplaceTheme.emerald;
    case 'rejected':
      return Colors.orange;
    case 'suspended':
      return Colors.redAccent;
    default:
      return MarketplaceTheme.sky;
  }
}

String _formatAdminDateTime(BuildContext context, DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  final MaterialLocalizations localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(local)} · '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return const _AdminState(
      icon: Icons.lock_outline_rounded,
      title: 'Authorized staff only',
      message:
          'This dashboard reads private student identity documents. A Marketplace owner must grant your account a trusted Firebase role.',
    );
  }
}

class _AdminState extends StatelessWidget {
  const _AdminState({
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
            Icon(icon, size: 60, color: MarketplaceTheme.sky),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
