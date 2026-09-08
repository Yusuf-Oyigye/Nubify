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

        onPressed: () {
          Navigator.push(
            context,

            MaterialPageRoute(
              builder:
                  (_) =>
              const CreatePostScreen(),
            ),
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