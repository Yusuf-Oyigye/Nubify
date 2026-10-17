import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/seller_verification.dart';
import '../services/seller_verification_service.dart';
import '../utils/marketplace_motion.dart';
import '../utils/marketplace_theme.dart';

//===================================================
// ONE-TIME SELLER VERIFICATION
//===================================================

class SellerVerificationScreen extends StatefulWidget {
  const SellerVerificationScreen({super.key});

  @override
  State<SellerVerificationScreen> createState() =>
      _SellerVerificationScreenState();
}

class _SellerVerificationScreenState extends State<SellerVerificationScreen> {
  final SellerVerificationService _service = SellerVerificationService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();

  Uint8List? _image;
  String _extension = 'jpg';
  bool _submitting = false;
  double _progress = 0;
  String _progressLabel = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    final DocumentSnapshot<Map<String, dynamic>> profile =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted || _fullNameController.text.trim().isNotEmpty) {
      return;
    }
    _fullNameController.text = (profile.data()?['fullName'] ?? '').toString();
  }

  Future<void> _pick(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 2200,
    );
    if (file == null) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _image = bytes;
      _extension = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    });
  }

  Future<void> _chooseImage() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a clear photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (_image == null) {
      _message('Add a clear photo of your university student ID.');
      return;
    }
    setState(() {
      _submitting = true;
      _progress = 0;
      _progressLabel = 'Preparing private upload';
    });
    try {
      await _service.submit(
        fullName: _fullNameController.text,
        studentIdNumber: _studentIdController.text,
        studentIdImage: _image!,
        fileExtension: _extension,
        onProgress: (double value) {
          if (mounted) {
            setState(() {
              _progress = value;
              _progressLabel = value >= 1
                  ? 'Submitting for review'
                  : 'Securely uploading ID';
            });
          }
        },
      );
      if (mounted) {
        _message('Your seller verification is now under review.');
      }
    } catch (error) {
      if (mounted) {
        _message(_friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Verification')),
      body: StreamBuilder<SellerVerification>(
        stream: _service.watchMine(),
        builder:
            (BuildContext context, AsyncSnapshot<SellerVerification> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final SellerVerification verification =
                  snapshot.data ??
                  SellerVerification.notSubmitted(
                    FirebaseAuth.instance.currentUser?.uid ?? '',
                  );
              if (!verification.canResubmit) {
                return _StatusBody(verification: verification);
              }
              return _buildForm(verification);
            },
      ),
    );
  }

  Widget _buildForm(SellerVerification verification) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
              Icon(Icons.verified_user_rounded, color: MarketplaceTheme.sky),
              SizedBox(height: 16),
              Text(
                'Sell with trust',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Submit your Nahda University ID once. An authorized Nubify reviewer must approve it before you can publish listings.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
        if (verification.status == 'rejected') ...<Widget>[
          const SizedBox(height: 16),
          _NoticeCard(
            icon: Icons.info_outline_rounded,
            color: Colors.orange,
            title: 'Please correct and resubmit',
            message: verification.rejectionReason,
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _fullNameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full name',
            prefixIcon: Icon(Icons.person_outline_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _studentIdController,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'University student ID number',
            helperText: 'It is stored privately and never shown publicly.',
            prefixIcon: Icon(Icons.badge_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: _submitting ? null : _chooseImage,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: MarketplaceMotion.duration(
              context,
              MarketplaceMotion.standard,
            ),
            height: 220,
            decoration: BoxDecoration(
              color: MarketplaceTheme.softSurface(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _image == null
                    ? MarketplaceTheme.sky.withValues(alpha: 0.45)
                    : MarketplaceTheme.emerald,
                width: 1.5,
              ),
            ),
            child: _image == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 44,
                        color: MarketplaceTheme.sky,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Add student ID card image',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 5),
                      Text('Use a clear, readable photo'),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Image.memory(_image!, fit: BoxFit.cover),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: _chooseImage,
                              icon: const Icon(Icons.edit_rounded),
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        const _NoticeCard(
          icon: Icons.lock_outline_rounded,
          color: MarketplaceTheme.emerald,
          title: 'Your document stays private',
          message:
              'Only you and authorized Nubify reviewers can access this image. It is never placed in your profile or Marketplace listing.',
        ),
        if (_submitting) ...<Widget>[
          const SizedBox(height: 18),
          LinearProgressIndicator(value: _progress == 0 ? null : _progress),
          const SizedBox(height: 8),
          Text(_progressLabel, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(_submitting ? 'Submitting…' : 'Submit for Verification'),
          style: FilledButton.styleFrom(
            backgroundColor: MarketplaceTheme.sky,
            foregroundColor: MarketplaceTheme.midnight,
            minimumSize: const Size.fromHeight(54),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _friendlyError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('FormatException: ', '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.verification});

  final SellerVerification verification;

  @override
  Widget build(BuildContext context) {
    final bool approved = verification.status == 'approved';
    final bool suspended = verification.status == 'suspended';
    final Color accent = approved
        ? MarketplaceTheme.emerald
        : suspended
        ? Colors.redAccent
        : MarketplaceTheme.gold;
    final IconData icon = approved
        ? Icons.verified_rounded
        : suspended
        ? Icons.block_rounded
        : Icons.hourglass_top_rounded;
    final String title = approved
        ? "You're Verified!"
        : suspended
        ? 'Selling access suspended'
        : 'Verification Under Review';
    final String message = approved
        ? 'Your seller account is approved. You can now create and publish listings without verifying again.'
        : suspended
        ? verification.suspensionReason
        : 'Your student ID was submitted successfully. A Nubify administrator or moderator will review it.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: MarketplaceTheme.premiumCard(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TweenAnimationBuilder<double>(
                duration: MarketplaceMotion.duration(
                  context,
                  MarketplaceMotion.success,
                ),
                tween: Tween<double>(begin: 0.72, end: 1),
                curve: MarketplaceMotion.springCurve,
                builder: (BuildContext context, double value, Widget? child) =>
                    Transform.scale(scale: value, child: child),
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Icon(icon, color: accent, size: 46),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MarketplaceTheme.mutedText(context),
                  height: 1.45,
                ),
              ),
              if (verification.submittedAt != null) ...<Widget>[
                const SizedBox(height: 18),
                Text(
                  'Submitted ${MaterialLocalizations.of(context).formatMediumDate(verification.submittedAt!)}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
              if (approved) ...<Widget>[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/marketplace/create'),
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('Start Selling'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MarketplaceTheme.sky,
                    foregroundColor: MarketplaceTheme.midnight,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
