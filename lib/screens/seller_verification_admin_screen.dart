import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/seller_verification.dart';
import '../services/marketplace_admin_service.dart';
import '../services/seller_verification_service.dart';
import '../utils/marketplace_theme.dart';
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

class _ApplicationsTab extends StatelessWidget {
  const _ApplicationsTab({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final MarketplaceAdminService admin = MarketplaceAdminService();
    return StreamBuilder<List<SellerVerification>>(
      stream: admin.watchApplications(status),
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
                snapshot.data ?? const <SellerVerification>[];
            if (applications.isEmpty) {
              return _AdminState(
                icon: status == 'pending'
                    ? Icons.task_alt_rounded
                    : Icons.inbox_outlined,
                title: status == 'pending'
                    ? 'No applications waiting'
                    : 'No $status applications',
                message: status == 'pending'
                    ? 'New student seller applications will appear here.'
                    : 'There is nothing in this section yet.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: applications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final SellerVerification application = applications[index];
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
                        status,
                      ).withValues(alpha: 0.15),
                      child: Icon(
                        Icons.badge_outlined,
                        color: _statusColor(status),
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
    );
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
            _DetailRow(label: 'Submitted', value: item.submittedAt.toString()),
          if (item.rejectionReason.isNotEmpty)
            _DetailRow(label: 'Rejection reason', value: item.rejectionReason),
          if (item.suspensionReason.isNotEmpty)
            _DetailRow(
              label: 'Suspension reason',
              value: item.suspensionReason,
            ),
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
