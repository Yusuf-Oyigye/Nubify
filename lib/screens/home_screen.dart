import 'package:flutter/material.dart';
import 'package:nubify/widgets/feed_post_list.dart';

import '../widgets/story_tray.dart';
import 'create_post_screen.dart';

class HomeScreen
    extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen>
  createState() =>
      HomeScreenState();
}

class HomeScreenState
    extends State<HomeScreen> {
  final GlobalKey<
      FeedPostListState>
  _feedKey =
  GlobalKey<
      FeedPostListState>();

  //===========================================================
  // REFRESH / RESHUFFLE HOME FEED
  // MobileScreenLayout calls this when Home is tapped.
  //===========================================================

  Future<void>
  reshuffleFeed() async {
    await _feedKey
        .currentState
        ?.reshuffleFeed(
      scrollToTop:
      true,
    );
  }

  //===========================================================
  // BUILD
  //===========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      body:
      Column(
        children:
        <Widget>[
          //=====================================================
          // NUBIFY STORIES
          //=====================================================

          const StoryTray(),

          const Divider(
            height:
            1,

            thickness:
            0.6,
          ),

          //=====================================================
          // HOME FEED
          //=====================================================

          Expanded(
            child:
            FeedPostList(
              key:
              _feedKey,
            ),
          ),
        ],
      ),

      //=========================================================
      // CREATE POST BUTTON
      //=========================================================

      floatingActionButton:
      FloatingActionButton(
        backgroundColor:
        const Color(
          0xFF29B6F6,
        ),

        onPressed: () async {
          //==========================
          // CREATE POST
          //==========================

          final String? newPostId =
          await Navigator.push<String>(
            context,
            MaterialPageRoute<String>(
              builder:
                  (_) =>
              const CreatePostScreen(),
            ),
          );

          if (!mounted ||
              newPostId == null ||
              newPostId.trim().isEmpty) {
            return;
          }

          //==========================
          // SHOW NEW POST
          //==========================

          _feedKey.currentState
              ?.showNewPost(
            newPostId,
          );
        },
        child:
        const Icon(
          Icons.add,

          color:
          Colors.white,

          size:
          30,
        ),
      ),
    );
  }
}