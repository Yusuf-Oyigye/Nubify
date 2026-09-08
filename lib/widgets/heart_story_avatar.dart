import 'package:flutter/material.dart';

//===========================================================
// HEART STORY AVATAR
//===========================================================

class HeartStoryAvatar
    extends StatelessWidget {
  const HeartStoryAvatar({
    super.key,
    required this.photoUrl,
    required this.borderColor,
    this.size = 64,
    this.borderWidth = 3.2,
    this.onTap,
    this.onAddTap,
    this.showAddBadge = false,
  });

  final String photoUrl;

  final Color borderColor;

  final double size;

  final double borderWidth;

  final VoidCallback? onTap;

  final VoidCallback? onAddTap;

  final bool showAddBadge;

  @override
  Widget build(
      BuildContext context,
      ) {
    return GestureDetector(
      onTap: onTap,

      child: SizedBox(
        width: size + 8,
        height: size + 8,

        child: Stack(
          clipBehavior:
          Clip.none,

          alignment:
          Alignment.center,

          children:
          <Widget>[
            //=================================================
            // HEART BORDER
            //=================================================

            CustomPaint(
              size:
              Size.square(
                size + 6,
              ),

              painter:
              HeartBorderPainter(
                color:
                borderColor,

                strokeWidth:
                borderWidth,
              ),
            ),

            //=================================================
            // PROFILE IMAGE
            //=================================================

            SizedBox(
              width:
              size,

              height:
              size,

              child:
              ClipPath(
                clipper:
                HeartClipper(),

                child:
                _buildImage(),
              ),
            ),

            //=================================================
            // ADD STORY BADGE
            //=================================================

            if (showAddBadge)
              Positioned(
                right: -1,
                bottom: 2,

                child:
                GestureDetector(
                  onTap:
                  onAddTap ??
                      onTap,

                  behavior:
                  HitTestBehavior
                      .opaque,

                  child:
                  Container(
                    width: 23,
                    height: 23,

                    decoration:
                    BoxDecoration(
                      color:
                      const Color(
                        0xFF29B6F6,
                      ),

                      shape:
                      BoxShape
                          .circle,

                      border:
                      Border.all(
                        color:
                        Theme.of(
                          context,
                        )
                            .scaffoldBackgroundColor,

                        width:
                        2,
                      ),
                    ),

                    child:
                    const Icon(
                      Icons.add,

                      color:
                      Colors.white,

                      size:
                      16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  //===========================================================
  // AVATAR IMAGE
  //===========================================================

  Widget _buildImage() {
    if (photoUrl
        .trim()
        .isEmpty) {
      return Container(
        color:
        Colors
            .grey
            .shade800,

        alignment:
        Alignment.center,

        child:
        const Icon(
          Icons.person,

          color:
          Colors.white70,

          size:
          30,
        ),
      );
    }

    return Image.network(
      photoUrl,

      fit:
      BoxFit.cover,

      errorBuilder:
          (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
          ) {
        return Container(
          color:
          Colors
              .grey
              .shade800,

          alignment:
          Alignment.center,

          child:
          const Icon(
            Icons.person,

            color:
            Colors.white70,

            size:
            30,
          ),
        );
      },
    );
  }
}

//===========================================================
// HEART CLIPPER
//===========================================================

class HeartClipper
    extends CustomClipper<Path> {
  @override
  Path getClip(
      Size size,
      ) {
    return buildHeartPath(
      size,
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

//===========================================================
// HEART BORDER PAINTER
//===========================================================

class HeartBorderPainter
    extends CustomPainter {
  const HeartBorderPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;

  final double strokeWidth;

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final Paint paint =
    Paint()
      ..color =
          color
      ..style =
          PaintingStyle
              .stroke
      ..strokeWidth =
          strokeWidth
      ..strokeCap =
          StrokeCap
              .round
      ..strokeJoin =
          StrokeJoin
              .round;

    final Rect safeRect =
    Rect.fromLTWH(
      strokeWidth,
      strokeWidth,

      size.width -
          (strokeWidth * 2),

      size.height -
          (strokeWidth * 2),
    );

    canvas.save();

    canvas.translate(
      safeRect.left,
      safeRect.top,
    );

    canvas.drawPath(
      buildHeartPath(
        safeRect.size,
      ),
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(
      covariant HeartBorderPainter
      oldDelegate,
      ) {
    return oldDelegate.color !=
        color ||
        oldDelegate.strokeWidth !=
            strokeWidth;
  }
}

//===========================================================
// HEART PATH
//===========================================================

Path buildHeartPath(
    Size size,
    ) {
  final double width =
      size.width;

  final double height =
      size.height;

  final Path path =
  Path();

  path.moveTo(
    width * 0.50,
    height * 0.92,
  );

  path.cubicTo(
    width * 0.42,
    height * 0.84,
    width * 0.08,
    height * 0.64,
    width * 0.08,
    height * 0.34,
  );

  path.cubicTo(
    width * 0.08,
    height * 0.12,
    width * 0.24,
    height * 0.04,
    width * 0.38,
    height * 0.04,
  );

  path.cubicTo(
    width * 0.46,
    height * 0.04,
    width * 0.50,
    height * 0.11,
    width * 0.50,
    height * 0.18,
  );

  path.cubicTo(
    width * 0.50,
    height * 0.11,
    width * 0.54,
    height * 0.04,
    width * 0.62,
    height * 0.04,
  );

  path.cubicTo(
    width * 0.76,
    height * 0.04,
    width * 0.92,
    height * 0.12,
    width * 0.92,
    height * 0.34,
  );

  path.cubicTo(
    width * 0.92,
    height * 0.64,
    width * 0.58,
    height * 0.84,
    width * 0.50,
    height * 0.92,
  );

  path.close();

  return path;
}