import 'package:flutter/material.dart';

import '../models/story.dart';

//===================================================
// DRAGGABLE STORY TAGS
//===================================================

class DraggableStoryTags
    extends StatelessWidget {
  const DraggableStoryTags({
    super.key,
    required this.people,
    this.editable = false,
    this.onChanged,
    this.onPersonTap,
  });

  final List<StoryPerson> people;

  final bool editable;

  final ValueChanged<List<StoryPerson>>?
  onChanged;

  final ValueChanged<StoryPerson>?
  onPersonTap;

  @override
  Widget build(
      BuildContext context,
      ) {
    if (people.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder:
          (
          BuildContext context,
          BoxConstraints constraints,
          ) {
        final double width =
            constraints.maxWidth;

        final double height =
            constraints.maxHeight;

        return IgnorePointer(
          ignoring:
          !editable &&
              onPersonTap == null,

          child:
          Stack(
            clipBehavior:
            Clip.none,

            children:
            List<Widget>.generate(
              people.length,

                  (
                  int index,
                  ) {
                final StoryPerson person =
                people[index];

                final double x =
                person.tagX
                    .clamp(
                  0.06,
                  0.94,
                )
                    .toDouble();

                final double y =
                person.tagY
                    .clamp(
                  0.08,
                  0.90,
                )
                    .toDouble();

                return Positioned(
                  left:
                  x * width,

                  top:
                  y * height,

                  child:
                  Transform.translate(
                    offset:
                    const Offset(
                      -50,
                      -18,
                    ),

                    child:
                    GestureDetector(
                      behavior:
                      HitTestBehavior.opaque,

                      //===================================================
                      // OPEN TAGGED USER PROFILE
                      //===================================================

                      onTap:
                      onPersonTap == null
                          ? null
                          : () {
                        onPersonTap!(
                          person,
                        );
                      },

                      //===================================================
                      // MOVE TAG
                      //===================================================

                      onPanUpdate:
                      !editable ||
                          onChanged == null
                          ? null
                          : (
                          DragUpdateDetails
                          details,
                          ) {
                        if (width <= 0 ||
                            height <= 0) {
                          return;
                        }

                        final double newX =
                        (
                            person.tagX +
                                details.delta.dx /
                                    width
                        )
                            .clamp(
                          0.06,
                          0.94,
                        )
                            .toDouble();

                        final double newY =
                        (
                            person.tagY +
                                details.delta.dy /
                                    height
                        )
                            .clamp(
                          0.08,
                          0.90,
                        )
                            .toDouble();

                        final List<StoryPerson>
                        updated =
                        List<StoryPerson>.from(
                          people,
                        );

                        updated[index] =
                            person.copyWith(
                              tagX:
                              newX,

                              tagY:
                              newY,
                            );

                        onChanged!(
                          updated,
                        );
                      },

                      child:
                      Container(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal:
                          10,

                          vertical:
                          6,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          Colors.black54,

                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),

                          border:
                          Border.all(
                            color:
                            Colors.white24,
                          ),
                        ),

                        child:
                        Text(
                          '@${person.username}',

                          style:
                          const TextStyle(
                            color:
                            Colors.white,

                            fontWeight:
                            FontWeight.w700,

                            fontSize:
                            12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}