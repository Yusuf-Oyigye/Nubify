import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/story.dart';

import '../screens/comment_screen.dart';
import '../screens/group_chat_screen.dart';
import '../screens/marketplace_screen.dart';
import '../screens/marketplace_listing_details_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/nubuzz_screen.dart';

import '../services/group_chat_service.dart';

import '../utils/link_detector.dart';

//===================================================
// NUBIFY LINK ROUTER
//===================================================

class NubifyLinkRouter {
  NubifyLinkRouter._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final GroupChatService _groupService = GroupChatService();

  //===================================================
  // OPEN
  //===================================================

  static Future<void> open(BuildContext context, String rawUrl) async {
    final String url = LinkDetector.cleanUrl(rawUrl);

    final Uri? uri = Uri.tryParse(url);

    if (uri == null) {
      return;
    }

    if (!LinkDetector.isNubifyUrl(url)) {
      await _openExternal(uri);

      return;
    }

    final List<String> parts = uri.pathSegments
        .where((String item) => item.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return;
    }

    final String type = parts.first.toLowerCase();

    //===================================================
    // POST
    //===================================================

    if (type == 'post' && parts.length >= 2) {
      await Navigator.push<void>(
        context,

        MaterialPageRoute<void>(
          builder: (_) => CommentsScreen(postId: parts[1]),
        ),
      );

      return;
    }

    //===================================================
    // NUBUZZ
    //===================================================

    if (type == 'nubuzz' && parts.length >= 2) {
      await Navigator.push<void>(
        context,

        MaterialPageRoute<void>(
          builder: (_) => NubuzzScreen(initialPostId: parts[1]),
        ),
      );

      return;
    }
    //===================================================
    // PROFILE
    //===================================================

    if (type == 'profile' && parts.length >= 2) {
      await Navigator.push<void>(
        context,

        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(userId: parts[1]),
        ),
      );

      return;
    }

    //===================================================
    // STORY
    //===================================================

    if (type == 'story' && parts.length >= 2) {
      await _openStory(context, parts[1]);

      return;
    }

    //===================================================
    // GROUP INVITE
    //===================================================

    if (type == 'group' && parts.length >= 3 && parts[1] == 'join') {
      await _openGroupInvite(context, parts[2]);

      return;
    }

    //===================================================
    // GROUP
    //===================================================

    if (type == 'group' && parts.length >= 2) {
      await Navigator.push<void>(
        context,

        MaterialPageRoute<void>(
          builder: (_) => GroupChatScreen(groupId: parts[1]),
        ),
      );

      return;
    }

    //===================================================
    // MARKETPLACE
    //===================================================

    if ((type == 'marketplace' || type == 'product')) {
      if (parts.length >= 2) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                MarketplaceListingDetailsScreen(listingId: parts[1]),
          ),
        );
        return;
      }

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const MarketplaceScreen()),
      );
      return;
    }

    await _openExternal(uri);
  }

  //===================================================
  // OPEN STORY
  //===================================================

  static Future<void> _openStory(BuildContext context, String storyId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> document = await _firestore
          .collection('stories')
          .doc(storyId)
          .get();

      if (!context.mounted) {
        return;
      }

      if (!document.exists || document.data() == null) {
        _message(context, 'This Story is no longer available.');

        return;
      }

      final NubifyStory story = NubifyStory.fromFirestore(document);

      await Navigator.push<void>(
        context,

        MaterialPageRoute<void>(
          builder: (_) => StoryViewerScreen(
            stories: <NubifyStory>[story],

            allowExpiredStories: true,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      _message(context, 'Unable to open this Story.');
    }
  }

  //===================================================
  // OPEN GROUP INVITATION
  //===================================================

  static Future<void> _openGroupInvite(
    BuildContext context,
    String token,
  ) async {
    try {
      //===================================================
      // JOIN GROUP THROUGH CLOUD FUNCTION
      //===================================================

      final String groupId = await _groupService.joinUsingToken(token);

      if (!context.mounted) {
        return;
      }

      //===================================================
      // WAITING FOR ADMIN APPROVAL
      //===================================================

      if (groupId.isEmpty) {
        _message(
          context,
          'Your join request has been sent. '
          'Please wait for a group admin to approve it.',
        );

        return;
      }

      //===================================================
      // MEMBERSHIP CONFIRMED
      //===================================================

      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GroupChatScreen(groupId: groupId),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      //===================================================
      // DISPLAY JOIN ERROR
      //===================================================

      _message(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  //===================================================
  // EXTERNAL LINK
  //===================================================

  static Future<void> _openExternal(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  //===================================================
  // MESSAGE
  //===================================================

  static void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
