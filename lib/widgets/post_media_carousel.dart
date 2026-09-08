import 'package:flutter/material.dart';

import '../models/post.dart';
import 'video_post_player.dart';

class PostMediaCarousel extends StatefulWidget {
  final List<PostMedia> media;

  const PostMediaCarousel({
    super.key,
    required this.media,
  });

  @override
  State<PostMediaCarousel> createState() =>
      _PostMediaCarouselState();
}

class _PostMediaCarouselState
    extends State<PostMediaCarousel> {
  final PageController _pageController =
  PageController();

  int _currentPage = 0;

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
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final PostMedia media =
                widget.media[index];

                return _buildMedia(media);
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
                  borderRadius:
                  BorderRadius.circular(20),
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
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: List.generate(
                    widget.media.length,
                        (index) {
                      final bool active =
                          index == _currentPage;

                      return AnimatedContainer(
                        duration:
                        const Duration(
                          milliseconds: 200,
                        ),
                        width: active ? 8 : 6,
                        height: active ? 8 : 6,
                        margin:
                        const EdgeInsets.symmetric(
                          horizontal: 3,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? Colors.white
                              : Colors.white54,
                        ),
                      );
                    },
                  ),
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

  Widget _buildMedia(PostMedia media) {
    // ==========================================================
    // VIDEO
    // ==========================================================

    if (media.isVideo) {
      return VideoPostPlayer(
        videoUrl: media.url,
      );
    }

    // ==========================================================
    // IMAGE
    // ==========================================================

    return Image.network(
      media.url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (
          context,
          child,
          loadingProgress,
          ) {
        if (loadingProgress == null) {
          return child;
        }

        return const Center(
          child: CircularProgressIndicator(),
        );
      },
      errorBuilder: (
          context,
          error,
          stackTrace,
          ) {
        return const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 50,
          ),
        );
      },
    );
  }
}