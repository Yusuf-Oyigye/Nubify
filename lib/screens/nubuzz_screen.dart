import 'package:flutter/material.dart';

import '../models/nubuzz_post.dart';
import '../services/nubuzz_service.dart';
import '../widgets/nubuzz_card.dart';

class NubuzzScreen
    extends StatefulWidget {
  final VoidCallback?
  onBackToHome;

  const NubuzzScreen({
    super.key,
    this.onBackToHome,
    this.initialPostId = '',
  });
  final String initialPostId;

  @override
  NubuzzScreenState createState() =>
      NubuzzScreenState();
}

class NubuzzScreenState
    extends State<NubuzzScreen>
    with WidgetsBindingObserver {
  final PageController _pageController =
  PageController();

  List<NubuzzVideo> _videos =
  <NubuzzVideo>[];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isMuted = false;
  bool _appIsActive = true;

  String? _errorMessage;

  int _currentIndex = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    _loadVideos();
  }

  // ============================================================
  // REFRESH
  //
  // MobileScreenLayout can call this when user taps
  // the NUBuzz bottom icon again.
  // ============================================================

  Future<void> refreshFeed() async {
    await _loadVideos(
      showFullLoader: false,
      jumpToFirstVideo: true,
    );
  }

  // ============================================================
  // LOAD NUBUZZ
  // ============================================================

  Future<void> _loadVideos({
    bool showFullLoader = true,
    bool jumpToFirstVideo = false,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      if (showFullLoader) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }

      _errorMessage = null;
    });

    try {
      final List<NubuzzVideo> videos =
      await NubuzzService
          .instance
          .getNubuzzVideos();

      if (!mounted) {
        return;
      }

      setState(() {
        _videos = videos;

        //===================================================
// OPEN EXACT NUBUZZ VIDEO
//===================================================

        int targetIndex =
        0;

        if (widget.initialPostId
            .trim()
            .isNotEmpty) {
          final int foundIndex =
          videos.indexWhere(
                (
                video,
                ) =>
            video.postId ==
                widget.initialPostId,
          );

          if (foundIndex >=
              0) {
            targetIndex =
                foundIndex;
          }
        }

        _currentIndex =
            targetIndex;

        _isLoading = false;

        _isRefreshing = false;

        _errorMessage = null;
      });
      WidgetsBinding.instance
          .addPostFrameCallback(
            (_) {
          if (!mounted ||
              !_pageController.hasClients) {
            return;
          }

          _pageController.jumpToPage(
            _currentIndex,
          );
        },
      );

      if (jumpToFirstVideo &&
          _pageController.hasClients) {
        _pageController.jumpToPage(
          0,
        );
      }
    } catch (e) {
      debugPrint(
        'NUBuzz load error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        _isRefreshing = false;

        _errorMessage =
        'Unable to load NUBuzz videos.';
      });
    }
  }

  // ============================================================
  // REMOVE HIDDEN / DELETED VIDEO
  // ============================================================

  void _removeVideo(
      String postId,
      ) {
    if (!mounted) {
      return;
    }

    final int oldIndex =
        _currentIndex;

    setState(() {
      _videos.removeWhere(
            (
            NubuzzVideo video,
            ) =>
        video.postId ==
            postId,
      );

      if (_videos.isEmpty) {
        _currentIndex = 0;
      } else if (oldIndex >=
          _videos.length) {
        _currentIndex =
            _videos.length - 1;
      } else {
        _currentIndex =
            oldIndex;
      }
    });
  }

  // ============================================================
  // BACK TO HOME
  // ============================================================

  void _goBackToHome() {
    if (widget.onBackToHome !=
        null) {
      widget.onBackToHome!();

      return;
    }

    if (Navigator.of(context)
        .canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // SOUND
  // ============================================================

  void _toggleMute() {
    if (!mounted) {
      return;
    }

    setState(() {
      _isMuted =
      !_isMuted;
    });
  }

  // ============================================================
  // PAGE CHANGED
  //
  // TikTok / Reels behaviour:
  //
  // swipe up/down manually.
  // The visible video becomes active and plays.
  // The previous video becomes inactive and pauses.
  // ============================================================

  void _onPageChanged(
      int index,
      ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex =
          index;
    });
  }

  // ============================================================
  // APP LIFECYCLE
  //
  // If app goes to background:
  // current video pauses.
  //
  // When app resumes:
  // visible video can play again.
  // ============================================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _appIsActive =
          state ==
              AppLifecycleState.resumed;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      Colors.black,

      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child:
            _buildBody(),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child:
            _buildTopBar(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,

      child: Container(
        height: 58,

        padding:
        const EdgeInsets.symmetric(
          horizontal: 4,
        ),

        child: Row(
          children: <Widget>[
            // ==================================================
            // BACK
            // ==================================================

            IconButton(
              onPressed:
              _goBackToHome,

              icon:
              const Icon(
                Icons
                    .arrow_back_ios_new_rounded,

                color:
                Colors.white,

                size: 22,
              ),
            ),

            // ==================================================
            // TITLE
            // ==================================================

            const Text(
              'NUBuzz',

              style: TextStyle(
                color:
                Colors.white,

                fontSize: 22,

                fontWeight:
                FontWeight.bold,

                letterSpacing:
                0.2,
              ),
            ),

            const Spacer(),

            // ==================================================
            // REFRESH
            // ==================================================

            if (_isRefreshing)
              const Padding(
                padding:
                EdgeInsets.symmetric(
                  horizontal: 12,
                ),

                child: SizedBox(
                  width: 20,
                  height: 20,

                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,

                    color:
                    Colors.white,
                  ),
                ),
              )
            else
              IconButton(
                tooltip:
                'Refresh NUBuzz',

                onPressed:
                refreshFeed,

                icon:
                const Icon(
                  Icons
                      .refresh_rounded,

                  color:
                  Colors.white,

                  size: 26,
                ),
              ),

            // ==================================================
            // VOLUME
            // ==================================================

            IconButton(
              tooltip:
              _isMuted
                  ? 'Turn sound on'
                  : 'Mute',

              onPressed:
              _toggleMute,

              icon: Icon(
                _isMuted
                    ? Icons
                    .volume_off_rounded
                    : Icons
                    .volume_up_rounded,

                color:
                Colors.white,

                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
        CircularProgressIndicator(
          color:
          Color(
            0xFF29B6F6,
          ),
        ),
      );
    }

    if (_errorMessage != null &&
        _videos.isEmpty) {
      return _buildErrorState();
    }

    if (_videos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color:
      const Color(
        0xFF29B6F6,
      ),

      backgroundColor:
      Colors.black,

      onRefresh:
      refreshFeed,

      child:
      PageView.builder(
        controller:
        _pageController,

        scrollDirection:
        Axis.vertical,

        physics:
        const AlwaysScrollableScrollPhysics(
          parent:
          ClampingScrollPhysics(),
        ),

        itemCount:
        _videos.length,

        onPageChanged:
        _onPageChanged,

        itemBuilder:
            (
            BuildContext context,
            int index,
            ) {
          final NubuzzVideo video =
          _videos[index];

          return NubuzzCard(
            key:
            ValueKey<String>(
              video.postId,
            ),

            video:
            video,

            // ==================================================
            // ONLY THE CURRENT VIDEO PLAYS
            // ==================================================

            isActive:
            _appIsActive &&
                index ==
                    _currentIndex,

            // ==================================================
            // GLOBAL NUBUZZ SOUND
            // ==================================================

            isMuted:
            _isMuted,

            // ==================================================
            // HIDE / DELETE / BLOCK
            // REMOVE THE VIDEO FROM CURRENT FEED
            // ==================================================

            onRemoved:
                () =>
                _removeVideo(
                  video.postId,
                ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return RefreshIndicator(
      color:
      const Color(
        0xFF29B6F6,
      ),

      backgroundColor:
      Colors.black,

      onRefresh:
      refreshFeed,

      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),

        children: <Widget>[
          const SizedBox(
            height: 220,
          ),

          const Icon(
            Icons.wifi_off_rounded,

            color:
            Colors.white70,

            size: 55,
          ),

          const SizedBox(
            height: 15,
          ),

          const Center(
            child: Text(
              'Could not load NUBuzz',

              style:
              TextStyle(
                color:
                Colors.white,

                fontSize:
                18,

                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 30,
            ),

            child: Text(
              _errorMessage ??
                  'Something went wrong.',

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                Colors.white60,

                fontSize:
                14,
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          Center(
            child:
            ElevatedButton(
              onPressed:
                  () =>
                  _loadVideos(),

              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFF29B6F6,
                ),

                foregroundColor:
                Colors.white,
              ),

              child:
              const Text(
                'Try Again',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color:
      const Color(
        0xFF29B6F6,
      ),

      backgroundColor:
      Colors.black,

      onRefresh:
      refreshFeed,

      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),

        children:
        const <Widget>[
          SizedBox(
            height: 230,
          ),

          Icon(
            Icons
                .video_library_outlined,

            color:
            Colors.white70,

            size: 65,
          ),

          SizedBox(
            height: 18,
          ),

          Center(
            child: Text(
              'No NUBuzz videos yet',

              style:
              TextStyle(
                color:
                Colors.white,

                fontSize:
                19,

                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          SizedBox(
            height: 8,
          ),

          Padding(
            padding:
            EdgeInsets.symmetric(
              horizontal: 30,
            ),

            child: Text(
              'Single-video posts from NUB students will appear here.',

              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                color:
                Colors.white60,

                fontSize:
                14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    );

    _pageController.dispose();

    super.dispose();
  }
}