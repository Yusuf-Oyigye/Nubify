import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/huddles/huddle.dart';
import '../../services/huddles/huddle_service.dart';
import '../../widgets/huddles/huddle_mini_bar.dart';
import '../../widgets/huddles/huddle_ui.dart';
import 'create_huddle_screen.dart';
import 'huddle_launcher.dart';
import '../../l10n/nubify_text.dart';

//===================================================
// NUB HUDDLES — HOME (live now)
//===================================================

class HuddlesScreen extends StatefulWidget {
  const HuddlesScreen({super.key});

  @override
  State<HuddlesScreen> createState() => _HuddlesScreenState();
}

class _HuddlesScreenState extends State<HuddlesScreen> {
  final HuddleService _service = HuddleService.instance;

  late final Stream<List<Huddle>> _live = _service.watchLive();

  // Who you follow / who follows you, for "Followers" Huddles.
  Set<String> _connected = <String>{};

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> me = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(_service.uid)
          .get();
      final Map<String, dynamic> data = me.data() ?? <String, dynamic>{};
      if (mounted) {
        setState(() {
          _connected = {
            ...List<String>.from(data['following'] ?? const <String>[]),
            ...List<String>.from(data['followers'] ?? const <String>[]),
          };
        });
      }
    } catch (_) {}
  }

  bool _visible(Huddle huddle) {
    if (huddle.hostId == _service.uid) {
      return true;
    }
    return switch (huddle.privacy) {
      HuddlePrivacy.everyone => true,
      HuddlePrivacy.followers => _connected.contains(huddle.hostId),
      HuddlePrivacy.inviteOnly => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: StreamBuilder<List<Huddle>>(
          stream: _live,
          builder: (context, snapshot) {
            final List<Huddle> huddles = (snapshot.data ?? const <Huddle>[])
                .where(_visible)
                .toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _hero(context)),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: HuddleMiniBar(inline: true),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      children: [
                        const HuddleLivePill(),
                        const SizedBox(width: 8),
                        Text(context.tr('Live now'),
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Empty(
                      icon: Icons.cloud_off_rounded,
                      title: context.tr('Could not load Huddles'),
                      text: context.tr('Check your connection and try again.'),
                    ),
                  )
                else if (!snapshot.hasData)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (huddles.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _Empty(
                        icon: Icons.graphic_eq_rounded,
                        title: context.tr('No live Huddles right now'),
                        text:
                        context.tr('Start one for a study session, a club meeting or just to hang out.'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList.separated(
                        itemCount: huddles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => HuddleCard(
                          huddle: huddles[index],
                          onTap: () => openHuddle(context, huddles[index].id),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              HuddleColors.stage,
              Color(0xFF0E2A47),
              HuddleColors.skyDeep,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: context.tr('Back'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('NUB Huddles'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(context.tr('Talk, listen, present and learn together, live.'),
                        style: TextStyle(color: Colors.white70, fontSize: 14.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: HuddleColors.sky,
                      foregroundColor: HuddleColors.stage,
                      minimumSize: const Size(0, 50),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateHuddleScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.tr('Start a Huddle'),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//===================================================
// HUDDLE CARD
//===================================================

class HuddleCard extends StatelessWidget {
  const HuddleCard({super.key, required this.huddle, required this.onTap});

  final Huddle huddle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: dark ? const Color(0xFF141D2B) : Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: HuddleColors.sky.withValues(alpha: .25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const HuddleLivePill(small: true),
                  const SizedBox(width: 8),
                  Text(
                    formatHuddleDuration(huddle.elapsed),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  if (huddle.topic.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '#${context.tr(huddle.topic)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HuddleColors.sky,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (huddle.mode == 'video')
                    Icon(
                      Icons.videocam_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                huddle.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  HuddleAvatar(
                    name: huddle.hostName,
                    photoUrl: huddle.hostPhotoUrl,
                    size: 28,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      huddle.hostName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _AvatarStack(photos: huddle.previewPhotos),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  huddle.speakerCount == 1
                      ? '🎙️ {listeners} listening · {speakers} speaker'
                      : '🎙️ {listeners} listening · {speakers} speakers',
                  {
                    'listeners': huddle.listenerCount,
                    'speakers': huddle.speakerCount,
                  },
                ),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final List<String> shown = photos.take(4).toList();
    if (shown.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 22.0 * shown.length + 8,
      height: 30,
      child: Stack(
        children: [
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * 22.0,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: CircleAvatar(
                  radius: 13,
                  backgroundImage: CachedNetworkImageProvider(shown[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 46, color: HuddleColors.sky),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }
}