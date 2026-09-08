import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/story.dart';
import '../screens/create_story_screen.dart';
import '../screens/story_viewer_screen.dart';
import '../services/story_service.dart';

//===================================================
// STORY TRAY
//===================================================

class StoryTray extends StatefulWidget {
  const StoryTray({
    super.key,
  });

  @override
  State<StoryTray> createState() =>
      _StoryTrayState();
}

//===================================================
// STORY TRAY STATE
//===================================================

class _StoryTrayState extends State<StoryTray> {
  //===================================================
  // FIREBASE
  //===================================================

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  //===================================================
  // SERVICE
  //===================================================

  final StoryService _storyService =
  StoryService();

  //===================================================
  // CURRENT USER
  //===================================================

  StoryPerson? _currentUserProfile;

  bool _loadingProfile = true;

  //===================================================
  // COLORS
  //===================================================

  static const Color _unviewedColor =
  Color(
    0xFF29B6F6,
  );

  static const Color _viewedColor =
  Color(
    0xFF666666,
  );

  //===================================================
  // ACTIVE STORY BORDER
  //===================================================

  static const double _storyBorderWidth =
  5.0;

  //===================================================
  // NO STORY BORDER
  //
  // NO ACTIVE STORY:
  // THIN PLAIN NEUTRAL HEART BORDER
  //===================================================

  static const double _emptyStoryBorderWidth =
  1.2;

  static const Color _emptyStoryBorderColor =
  Color(
    0xFF737373,
  );

  //===================================================
  // STORY SIZE
  //===================================================

  static const double _storyWidth =
  76;

  static const double _storyHeight =
  70;

  //===================================================
  // INIT
  //===================================================

  @override
  void initState() {
    super.initState();

    _loadCurrentUser();
  }

  //===================================================
  // LOAD CURRENT USER PROFILE
  //===================================================

  Future<void> _loadCurrentUser() async {
    try {
      final StoryPerson profile =
      await _storyService
          .getCurrentUserProfile();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUserProfile =
            profile;

        _loadingProfile =
        false;
      });
    } catch (error) {
      debugPrint(
        'Story tray profile error: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingProfile =
        false;
      });
    }
  }

  //===================================================
  // CREATE STORY
  //===================================================

  Future<void> _createStory() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder:
            (
            BuildContext context,
            ) {
          return const CreateStoryScreen();
        },
      ),
    );
  }

  //===================================================
  // OPEN STORY GROUP
  //
  // NEWEST STORY OPENS FIRST.
  // AFTER THAT USER MOVES TOWARDS OLDER STORIES.
  //===================================================

  Future<void> _openStoryGroup(
      StoryGroup group,
      ) async {
    if (group.stories.isEmpty) {
      return;
    }

    final String currentUid =
        _auth.currentUser?.uid ??
            '';

    final List<NubifyStory> stories =
    List<NubifyStory>.from(
      group.stories,
    );

    //===================================================
    // NEWEST -> OLDEST
    //===================================================

    stories.sort(
          (
          NubifyStory a,
          NubifyStory b,
          ) {
        return b.createdAt.compareTo(
          a.createdAt,
        );
      },
    );

    //===================================================
    // OPEN FIRST UNREAD STORY
    //
    // BECAUSE LIST IS NEWEST -> OLDEST,
    // THIS MEANS NEWEST UNREAD FIRST.
    //===================================================

    final int initialIndex =
    _firstUnreadIndex(
      stories,
      currentUid,
    );

    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder:
            (
            BuildContext context,
            ) {
          return StoryViewerScreen(
            stories:
            stories,
            initialIndex:
            initialIndex,
          );
        },
      ),
    );
  }

  //===================================================
  // FIRST UNREAD INDEX
  //===================================================

  int _firstUnreadIndex(
      List<NubifyStory> stories,
      String uid,
      ) {
    if (stories.isEmpty) {
      return 0;
    }

    if (uid.trim().isEmpty) {
      return 0;
    }

    for (
    int index = 0;
    index < stories.length;
    index++
    ) {
      if (!stories[index]
          .viewerIds
          .contains(
        uid,
      )) {
        return index;
      }
    }

    //===================================================
    // ALL HAVE BEEN VIEWED
    //
    // OPEN NEWEST AGAIN.
    //===================================================

    return 0;
  }

  //===================================================
  // GROUP STORIES BY USER
  //===================================================

  List<StoryGroup> _groups(
      List<NubifyStory> stories,
      ) {
    final Map<
        String,
        List<NubifyStory>>
    grouped =
    <String, List<NubifyStory>>{};

    //===================================================
    // GROUP ONLY ACTIVE STORIES
    //===================================================

    for (
    final NubifyStory story
    in stories
    ) {
      if (story.isExpired) {
        continue;
      }

      final String uid =
      story.uid.trim();

      if (uid.isEmpty) {
        continue;
      }

      grouped.putIfAbsent(
        uid,
            () =>
        <NubifyStory>[],
      );

      grouped[uid]!.add(
        story,
      );
    }

    final List<StoryGroup> groups =
    <StoryGroup>[];

    grouped.forEach(
          (
          String uid,
          List<NubifyStory> userStories,
          ) {
        if (userStories.isEmpty) {
          return;
        }

        //===================================================
        // EACH USER:
        // NEWEST -> OLDEST
        //===================================================

        userStories.sort(
              (
              NubifyStory a,
              NubifyStory b,
              ) {
            return b.createdAt.compareTo(
              a.createdAt,
            );
          },
        );

        //===================================================
        // IMPORTANT
        //
        // BECAUSE NEWEST IS FIRST,
        // LATEST STORY = FIRST.
        //===================================================

        final NubifyStory latest =
            userStories.first;

        groups.add(
          StoryGroup(
            owner:
            StoryPerson(
              uid:
              latest.uid,
              username:
              latest.username,
              fullName:
              latest.fullName,
              photoUrl:
              latest.photoUrl,
            ),
            stories:
            userStories,
          ),
        );
      },
    );

    //===================================================
    // USER WHO POSTED MOST RECENTLY COMES FIRST
    //===================================================

    groups.sort(
          (
          StoryGroup a,
          StoryGroup b,
          ) {
        final DateTime aTime =
            a.latestStory
                ?.createdAt ??
                DateTime
                    .fromMillisecondsSinceEpoch(
                  0,
                );

        final DateTime bTime =
            b.latestStory
                ?.createdAt ??
                DateTime
                    .fromMillisecondsSinceEpoch(
                  0,
                );

        return bTime.compareTo(
          aTime,
        );
      },
    );

    return groups;
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return StreamBuilder<
        List<NubifyStory>>(
      stream:
      _storyService
          .watchActiveStories(),
      builder:
          (
          BuildContext context,
          AsyncSnapshot<List<NubifyStory>>
          snapshot,
          ) {
        final List<NubifyStory> stories =
            snapshot.data ??
                <NubifyStory>[];

        final List<StoryGroup> groups =
        _groups(
          stories,
        );

        final String currentUid =
            _auth.currentUser?.uid ??
                '';

        StoryGroup? myGroup;

        final List<StoryGroup>
        otherGroups =
        <StoryGroup>[];

        //===================================================
        // KEEP CURRENT USER STORY FIRST IN TRAY
        //===================================================

        for (
        final StoryGroup group
        in groups
        ) {
          if (group.owner.uid ==
              currentUid) {
            myGroup =
                group;
          } else {
            otherGroups.add(
              group,
            );
          }
        }

        return SizedBox(
          height:
          115,
          child:
          ListView(
            scrollDirection:
            Axis.horizontal,
            padding:
            const EdgeInsets
                .symmetric(
              horizontal:
              10,
              vertical:
              7,
            ),
            children:
            <Widget>[
              //===================================================
              // YOUR STORY / ADD STORY
              //===================================================

              _buildMyStory(
                myGroup,
              ),

              //===================================================
              // OTHER USERS' STORIES
              //===================================================

              ...otherGroups.map(
                    (
                    StoryGroup group,
                    ) {
                  return _buildStoryItem(
                    group,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  //===================================================
  // MY STORY
  //===================================================

  Widget _buildMyStory(
      StoryGroup? myGroup,
      ) {
    final bool hasStory =
        myGroup != null &&
            myGroup.stories.isNotEmpty;

    final String currentUid =
        _auth.currentUser?.uid ??
            '';

    //===================================================
    // OWNER ALSO GETS VIEWED/UNVIEWED BORDER
    //
    // BLUE = HAS UNVIEWED OWN STORY
    // GREY = HAS VIEWED ALL OWN STORIES
    //===================================================

    final bool hasUnread =
        hasStory &&
            myGroup!.hasUnreadFor(
              currentUid,
            );

    final StoryPerson? person =
        myGroup?.owner ??
            _currentUserProfile;

    return SizedBox(
      width:
      86,
      child:
      Column(
        children:
        <Widget>[
          GestureDetector(
            behavior:
            HitTestBehavior.opaque,
            onTap:
                () {
              if (hasStory) {
                _openStoryGroup(
                  myGroup!,
                );
              } else {
                _createStory();
              }
            },
            child:
            Stack(
              clipBehavior:
              Clip.none,
              children:
              <Widget>[
                //===================================================
                // HEART PROFILE
                //===================================================

                _buildHeartStory(
                  person:
                  person,
                  hasStory:
                  hasStory,
                  hasUnread:
                  hasUnread,
                ),

                //===================================================
                // ADD BUTTON
                //
                // OWNER CAN ALWAYS ADD ANOTHER STORY.
                //===================================================

                Positioned(
                  right:
                  -1,
                  bottom:
                  0,
                  child:
                  GestureDetector(
                    onTap:
                    _createStory,
                    child:
                    Container(
                      width:
                      25,
                      height:
                      25,
                      decoration:
                      BoxDecoration(
                        color:
                        _unviewedColor,
                        shape:
                        BoxShape.circle,
                        border:
                        Border.all(
                          color:
                          Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          width:
                          2.5,
                        ),
                      ),
                      child:
                      const Icon(
                        Icons.add,
                        size:
                        18,
                        color:
                        Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
            5,
          ),

          //===================================================
          // TEXT
          //===================================================

          Text(
            hasStory
                ? 'Your Story'
                : 'Add Story',
            maxLines:
            1,
            overflow:
            TextOverflow.ellipsis,
            style:
            const TextStyle(
              fontSize:
              11.5,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // OTHER USER STORY
  //===================================================

  Widget _buildStoryItem(
      StoryGroup group,
      ) {
    final String currentUid =
        _auth.currentUser?.uid ??
            '';

    final bool hasUnread =
    group.hasUnreadFor(
      currentUid,
    );

    return SizedBox(
      width:
      86,
      child:
      Column(
        children:
        <Widget>[
          GestureDetector(
            behavior:
            HitTestBehavior.opaque,
            onTap:
                () {
              _openStoryGroup(
                group,
              );
            },
            child:
            _buildHeartStory(
              person:
              group.owner,
              hasStory:
              true,
              hasUnread:
              hasUnread,
            ),
          ),

          const SizedBox(
            height:
            5,
          ),

          Padding(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal:
              3,
            ),
            child:
            Text(
              group.owner.username
                  .trim()
                  .isNotEmpty
                  ? group.owner.username
                  : group.owner.displayName,
              maxLines:
              1,
              overflow:
              TextOverflow.ellipsis,
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                fontSize:
                11.5,
                fontWeight:
                hasUnread
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // HEART STORY
  //
  // ACTIVE UNVIEWED = THICK BLUE
  // ACTIVE VIEWED = THICK GREY
  // NO STORY = PLAIN THIN GREY
  //===================================================

  Widget _buildHeartStory({
    required StoryPerson? person,
    required bool hasStory,
    required bool hasUnread,
  }) {
    final Color borderColor;

    if (!hasStory) {
      borderColor =
          _emptyStoryBorderColor;
    } else if (hasUnread) {
      borderColor =
          _unviewedColor;
    } else {
      borderColor =
          _viewedColor;
    }

    final String photoUrl =
        person?.photoUrl.trim() ??
            '';

    return SizedBox(
      width:
      _storyWidth,
      height:
      _storyHeight,
      child:
      Stack(
        fit:
        StackFit.expand,
        children:
        <Widget>[
          //===================================================
          // PROFILE PHOTO
          //===================================================

          Padding(
            padding:
            const EdgeInsets.all(
              7,
            ),
            child:
            ClipPath(
              clipper:
              _TrayHeartClipper(),
              child:
              Container(
                color:
                Colors.grey
                    .shade800,
                child:
                photoUrl.isNotEmpty
                    ? Image.network(
                  photoUrl,
                  fit:
                  BoxFit.cover,
                  errorBuilder:
                      (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                      ) {
                    return _avatarFallback();
                  },
                )
                    : _avatarFallback(),
              ),
            ),
          ),

          //===================================================
          // HEART BORDER
          //===================================================

          Positioned.fill(
            child:
            IgnorePointer(
              child:
              CustomPaint(
                painter:
                _TrayHeartBorderPainter(
                  color:
                  borderColor,
                  strokeWidth:
                  hasStory
                      ? _storyBorderWidth
                      : _emptyStoryBorderWidth,
                  glow:
                  hasStory &&
                      hasUnread,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // FALLBACK AVATAR
  //===================================================

  Widget _avatarFallback() {
    if (_loadingProfile) {
      return const Center(
        child:
        SizedBox(
          width:
          20,
          height:
          20,
          child:
          CircularProgressIndicator(
            strokeWidth:
            2,
            color:
            Color(
              0xFF29B6F6,
            ),
          ),
        ),
      );
    }

    return const Center(
      child:
      Icon(
        Icons.person,
        size:
        33,
        color:
        Colors.white70,
      ),
    );
  }
}

//===================================================
// HEART CLIPPER
//===================================================

class _TrayHeartClipper
    extends CustomClipper<Path> {
  @override
  Path getClip(
      Size size,
      ) {
    return _trayHeartPath(
      size,
      0,
    );
  }

  @override
  bool shouldReclip(
      covariant CustomClipper<Path>
      oldClipper,
      ) {
    return false;
  }
}

//===================================================
// HEART BORDER PAINTER
//===================================================

class _TrayHeartBorderPainter
    extends CustomPainter {
  const _TrayHeartBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.glow,
  });

  final Color color;

  final double strokeWidth;

  final bool glow;

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final double inset =
        strokeWidth / 2 +
            1;

    final Path path =
    _trayHeartPath(
      size,
      inset,
    );

    //===================================================
    // GLOW ONLY FOR ACTIVE UNVIEWED STORY
    //===================================================

    if (glow) {
      final Paint glowPaint =
      Paint()
        ..color =
        color.withOpacity(
          0.22,
        )
        ..style =
            PaintingStyle.stroke
        ..strokeWidth =
            strokeWidth +
                3
        ..strokeCap =
            StrokeCap.round
        ..strokeJoin =
            StrokeJoin.round
        ..maskFilter =
        const MaskFilter.blur(
          BlurStyle.normal,
          4,
        );

      canvas.drawPath(
        path,
        glowPaint,
      );
    }

    //===================================================
    // MAIN BORDER
    //===================================================

    final Paint borderPaint =
    Paint()
      ..color =
          color
      ..style =
          PaintingStyle.stroke
      ..strokeWidth =
          strokeWidth
      ..strokeCap =
          StrokeCap.round
      ..strokeJoin =
          StrokeJoin.round
      ..isAntiAlias =
      true;

    canvas.drawPath(
      path,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(
      covariant _TrayHeartBorderPainter
      oldDelegate,
      ) {
    return oldDelegate.color !=
        color ||
        oldDelegate.strokeWidth !=
            strokeWidth ||
        oldDelegate.glow !=
            glow;
  }
}

//===================================================
// HEART PATH
//===================================================

Path _trayHeartPath(
    Size size,
    double inset,
    ) {
  final double left =
      inset;

  final double top =
      inset;

  final double width =
      size.width -
          inset * 2;

  final double height =
      size.height -
          inset * 2;

  final double centerX =
      left +
          width / 2;

  final Path path =
  Path();

  path.moveTo(
    centerX,
    top +
        height * 0.96,
  );

  path.cubicTo(
    left +
        width * 0.40,
    top +
        height * 0.82,
    left +
        width * 0.05,
    top +
        height * 0.60,
    left +
        width * 0.05,
    top +
        height * 0.34,
  );

  path.cubicTo(
    left +
        width * 0.05,
    top +
        height * 0.12,
    left +
        width * 0.22,
    top +
        height * 0.03,
    left +
        width * 0.37,
    top +
        height * 0.03,
  );

  path.cubicTo(
    left +
        width * 0.46,
    top +
        height * 0.03,
    centerX,
    top +
        height * 0.12,
    centerX,
    top +
        height * 0.20,
  );

  path.cubicTo(
    centerX,
    top +
        height * 0.12,
    left +
        width * 0.54,
    top +
        height * 0.03,
    left +
        width * 0.63,
    top +
        height * 0.03,
  );

  path.cubicTo(
    left +
        width * 0.78,
    top +
        height * 0.03,
    left +
        width * 0.95,
    top +
        height * 0.12,
    left +
        width * 0.95,
    top +
        height * 0.34,
  );

  path.cubicTo(
    left +
        width * 0.95,
    top +
        height * 0.60,
    left +
        width * 0.60,
    top +
        height * 0.82,
    centerX,
    top +
        height * 0.96,
  );

  path.close();

  return path;
}