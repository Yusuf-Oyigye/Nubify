import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/marketplace_listing.dart';
import '../utils/marketplace_theme.dart';

class MarketplaceMediaGallery extends StatefulWidget {
  const MarketplaceMediaGallery({super.key, required this.listing});

  final MarketplaceListing listing;

  @override
  State<MarketplaceMediaGallery> createState() =>
      _MarketplaceMediaGalleryState();
}

class _MarketplaceMediaGalleryState extends State<MarketplaceMediaGallery> {
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final List<MarketplaceMedia> media = widget.listing.media;
    if (media.isEmpty) {
      return ColoredBox(
        color: MarketplaceTheme.softSurface(context),
        child: const Center(
          child: Icon(
            Icons.storefront_rounded,
            size: 72,
            color: MarketplaceTheme.sky,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PageView.builder(
          controller: _pageController,
          itemCount: media.length,
          onPageChanged: (int value) => setState(() => _page = value),
          itemBuilder: (BuildContext context, int index) {
            final MarketplaceMedia item = media[index];
            if (item.isVideo) {
              return _MarketplaceVideo(url: item.url, active: index == _page);
            }
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => _FullImage(url: item.url),
                ),
              ),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 3.5,
                child: CachedNetworkImage(
                  imageUrl: item.url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            );
          },
        ),
        if (media.length > 1)
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_page + 1}/${media.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        if (media.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(media.length, (int index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == _page ? 22 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? MarketplaceTheme.sky
                        : Colors.white60,
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _MarketplaceVideo extends StatefulWidget {
  const _MarketplaceVideo({required this.url, required this.active});

  final String url;
  final bool active;

  @override
  State<_MarketplaceVideo> createState() => _MarketplaceVideoState();
}

class _MarketplaceVideoState extends State<_MarketplaceVideo> {
  VideoPlayerController? _controller;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didUpdateWidget(covariant _MarketplaceVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && _controller?.value.isPlaying == true) {
      _controller?.pause();
    }
  }

  void _toggle() {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  Future<void> _toggleMute() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null) {
      return;
    }
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          IconButton.filled(
            onPressed: _toggle,
            iconSize: 42,
            icon: Icon(
              controller.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: IconButton.filledTonal(
              onPressed: _toggleMute,
              icon: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(controller, allowScrubbing: true),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class _FullImage extends StatelessWidget {
  const _FullImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 5,
        child: Center(child: CachedNetworkImage(imageUrl: url)),
      ),
    );
  }
}
