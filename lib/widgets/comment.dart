import 'package:flutter/material.dart';

class CommentWidget extends StatelessWidget {
  final String username;
  final String fullName;
  final String photoUrl;
  final String text;
  final String time;
  final int likeCount;
  final int replyCount;
  final bool isLiked;

  final VoidCallback? onLike;
  final VoidCallback? onReply;
  final VoidCallback? onViewReplies;

  const CommentWidget({
    super.key,
    required this.username,
    required this.fullName,
    required this.photoUrl,
    required this.text,
    required this.time,
    required this.likeCount,
    required this.replyCount,
    required this.isLiked,
    this.onLike,
    this.onReply,
    this.onViewReplies,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================================
          // PROFILE PHOTO
          // ==========================================================

          CircleAvatar(
            radius: 21,
            backgroundImage: photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl.isEmpty
                ? const Icon(Icons.person)
                : null,
          ),

          const SizedBox(width: 10),

          // ==========================================================
          // COMMENT CONTENT
          // ==========================================================

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ====================================================
                // NAME + USERNAME
                // ====================================================

                Row(
                  children: [
                    Flexible(
                      child: Text(
                        fullName.isNotEmpty
                            ? fullName
                            : username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(width: 5),

                    Flexible(
                      child: Text(
                        '@$username',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // ====================================================
                // COMMENT TEXT
                // ====================================================

                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 6),

                // ====================================================
                // TIME + LIKE + REPLY
                // ====================================================

                Row(
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(width: 15),

                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        children: [
                          Icon(
                            isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 17,
                            color: isLiked
                                ? Colors.blue
                                : Colors.grey.shade700,
                          ),

                          const SizedBox(width: 4),

                          Text(
                            '$likeCount',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 18),

                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                // ====================================================
                // VIEW REPLIES
                // ====================================================

                if (replyCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 8,
                    ),
                    child: GestureDetector(
                      onTap: onViewReplies,
                      child: Text(
                        replyCount == 1
                            ? 'View 1 reply'
                            : 'View $replyCount replies',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// REPLY WIDGET
// ===================================================================

class ReplyWidget extends StatelessWidget {
  final String username;
  final String fullName;
  final String photoUrl;
  final String text;
  final String time;
  final int likeCount;
  final bool isLiked;

  final String replyingTo;

  final VoidCallback? onLike;
  final VoidCallback? onReply;

  const ReplyWidget({
    super.key,
    required this.username,
    required this.fullName,
    required this.photoUrl,
    required this.text,
    required this.time,
    required this.likeCount,
    required this.isLiked,
    required this.replyingTo,
    this.onLike,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 28,
        right: 12,
        top: 6,
        bottom: 6,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========================================================
            // VERTICAL LINE
            // ========================================================

            Container(
              width: 2,
              color: Colors.grey.shade300,
            ),

            const SizedBox(width: 12),

            // ========================================================
            // REPLY PROFILE
            // ========================================================

            CircleAvatar(
              radius: 18,
              backgroundImage: photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              child: photoUrl.isEmpty
                  ? const Icon(
                Icons.person,
                size: 18,
              )
                  : null,
            ),

            const SizedBox(width: 9),

            // ========================================================
            // REPLY CONTENT
            // ========================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          fullName.isNotEmpty
                              ? fullName
                              : username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow:
                          TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 5),

                      Flexible(
                        child: Text(
                          '@$username',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                          overflow:
                          TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  // WHO THIS REPLY IS FOR

                  Text(
                    'Replying to @$replyingTo',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Row(
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),

                      const SizedBox(width: 14),

                      GestureDetector(
                        onTap: onLike,
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
                              color: isLiked
                                  ? Colors.blue
                                  : Colors.grey.shade700,
                            ),

                            const SizedBox(width: 4),

                            Text(
                              '$likeCount',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      GestureDetector(
                        onTap: onReply,
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}