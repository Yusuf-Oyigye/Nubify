import 'package:flutter/material.dart';

import '../models/post.dart';
import 'video_post_player.dart';

class PostMediaCarousel extends StatefulWidget {
  final List<PostMedia> media;

  //============================
  // STORY VIDEO CONTROL
  //============================

  final bool storyPlayback;

  final bool forcePaused;

  final ValueChanged<double>? onVideoProgress;

  final VoidCallback? onVideoCompleted;
  //============================
  // MEDIA READY
  //============================

  final VoidCallback? onContentReady;

  const PostMediaCarousel({
    super.key,
    required this.media,
    this.storyPlayback = false,
    this.forcePaused = false,
    this.onVideoProgress,
    this.onVideoCompleted,
    this.onContentReady,
  });

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  final PageController _pageController = PageController();

  int _currentPage = 0;
  //============================
  // CONTENT READY
  //============================

  bool _contentReadySent = false;
  //============================
  // REPORT CURRENT MEDIA READY
  //============================

  void _reportContentReady(int index) {
    if (_contentReadySent || index != _currentPage) {
      return;
    }

    _contentReadySent = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.onContentReady?.call();
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) {
      return const SizedBox.shrink();
    }

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // ==================================================
            // SWIPEABLE MEDIA
            // ==================================================

            PageView.builder(
              controller: _pageController,
              itemCount: widget.media.length,
              onPageChanged: (int index) {
                setState(() {
                  _currentPage = index;

                  //===================================================
                  // NEW MEDIA PAGE MUST REPORT ITS OWN READY STATE
                  //===================================================

                  _contentReadySent = false;
                });
              },
              itemBuilder: (context, index) {
                final PostMedia media = widget.media[index];

                return _buildMedia(media, index);
              },
            ),

            // ==================================================
            // PAGE COUNTER
            // ==================================================
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentPage + 1}/${widget.media.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // ==================================================
            // PAGE DOTS
            // ==================================================
            if (widget.media.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.media.length, (index) {
                    final bool active = index == _currentPage;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: active ? 8 : 6,
                      height: active ? 8 : 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? Colors.white : Colors.white54,
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD MEDIA
  // ============================================================

  Widget _buildMedia(PostMedia media, int index) {
    // ==========================================================
    // VIDEO
    // ==========================================================
    if (media.isVideo) {
      return VideoPostPlayer(
        videoUrl: media.url,

        //============================
        // NORMAL FEED = LOOP
        // STORY = PLAY ONCE
        //============================
        loop: !widget.storyPlayback,

        forcePaused: widget.forcePaused,

        //============================
        // ONLY CURRENT PAGE CONTROLS
        // STORY PROGRESS
        //============================
        onProgressChanged: index == _currentPage
            ? widget.onVideoProgress
            : null,

        onCompleted: index == _currentPage ? widget.onVideoCompleted : null,

        onReady: () {
          if (index != _currentPage) {
            return;
          }

          //============================
          // VIDEO READY.
          //
          // DO NOT START NORMAL TIMER.
          // ACTUAL VIDEO POSITION WILL
          // CONTROL STORY PROGRESS.
          //============================

          widget.onVideoProgress?.call(0.0);
        },
      );
    }
    //===================================================
    // IMAGE
    //===================================================

    return Image.network(
      media.url,

      width: double.infinity,

      height: double.infinity,

      fit: BoxFit.cover,

      //===================================================
      // NETWORK-AWARE IMAGE LOADING
      //===================================================
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              //===================================================
              // IMAGE HAS FINISHED LOADING
              //===================================================

              _reportContentReady(index);

              return child;
            }

            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF29B6F6)),
            );
          },

      //===================================================
      // IMAGE LOAD ERROR
      //
      // DON'T LEAVE STORY PROGRESS AT 0 FOREVER.
      //===================================================
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            _reportContentReady(index);

            return const Center(
              child: Icon(Icons.broken_image_outlined, size: 50),
            );
          },
    );
  }
}
