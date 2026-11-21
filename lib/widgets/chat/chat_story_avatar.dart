import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/stories/story.dart';
import '../../screens/stories/story_viewer_screen.dart';
import '../common/full_photo_viewer.dart';
import 'nubify_chat_style.dart';

//===================================================
// STORY RING FOR ONE PERSON
//
// Blue if any of their stories is new to you, grey if
// you watched them all, none if they have no story or
// it is older than 24 hours.
//===================================================

NubifyStoryRing storyRingFor(List<NubifyStory> stories, String uid) {
  final String viewerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool hasStory = false;

  for (final NubifyStory story in stories) {
    if (story.uid != uid || story.isExpired) {
      continue;
    }

    if (!story.viewerIds.contains(viewerUid)) {
      return NubifyStoryRing.unviewed;
    }

    hasStory = true;
  }

  return hasStory ? NubifyStoryRing.viewed : NubifyStoryRing.none;
}

//===================================================
// CHAT STORY AVATAR
//
// The photo in the chat and call lists. Tapping it
// opens their story when they have one, otherwise the
// full-size photo.
//===================================================

class NubifyChatStoryAvatar extends StatelessWidget {
  const NubifyChatStoryAvatar({
    super.key,
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.stories,
    this.radius = 25,
  });

  final String uid;

  final String name;

  final String photoUrl;

  // All active stories, from StoryService.watchActiveStories().
  final List<NubifyStory> stories;

  final double radius;

  void _openStories(BuildContext context) {
    final String viewerUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final List<NubifyStory> theirs =
        stories
            .where((NubifyStory story) => story.uid == uid && !story.isExpired)
            .toList()
          ..sort(
            (NubifyStory a, NubifyStory b) =>
                b.createdAt.compareTo(a.createdAt),
          );

    if (theirs.isEmpty) {
      return;
    }

    // Start at the newest story they have not watched yet.
    final int firstNew = theirs.indexWhere(
      (NubifyStory story) => !story.viewerIds.contains(viewerUid),
    );

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StoryViewerScreen(
          stories: theirs,
          initialIndex: firstNew < 0 ? 0 : firstNew,
        ),
      ),
    );
  }

  void _openPhoto(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FullPhotoViewer(title: name, photoUrl: photoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final NubifyStoryRing ring = storyRingFor(stories, uid);

    return Semantics(
      button: true,
      label: ring == NubifyStoryRing.none
          ? 'Profile photo of $name'
          : 'Story from $name',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (ring == NubifyStoryRing.none) {
            _openPhoto(context);
          } else {
            _openStories(context);
          }
        },
        child: NubifyChatAvatar(
          photoUrl: photoUrl,
          radius: radius,
          story: ring,
        ),
      ),
    );
  }
}
