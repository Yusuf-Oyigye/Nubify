import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/models/post.dart';
import 'package:nubify/widgets/nubify_profile_grid.dart';

void main() {
  Post postWithMedia({
    required List<PostMedia> media,
    String thumbnailUrl = '',
  }) {
    return Post(
      postId: 'post-id',
      uid: 'user-id',
      username: 'user',
      fullName: 'User',
      photoUrl: '',
      caption: '',
      media: media,
      isNUBuzz: false,
      postType: 'post',
      hasPoll: false,
      poll: null,
      taggedUsers: const <TaggedUser>[],
      taggedUserIds: const <String>[],
      likeCount: 0,
      commentCount: 0,
      repostCount: 0,
      shareCount: 0,
      viewCount: 0,
      createdAt: null,
      isRepost: false,
      originalPostId: null,
      repostCaption: null,
      thumbnailUrl: thumbnailUrl,
    );
  }

  PostMedia media({
    required String type,
    required String url,
    required int order,
    String thumbnailUrl = '',
  }) {
    return PostMedia(
      url: url,
      type: type,
      fileName: 'media-$order',
      storagePath: 'posts/user/media-$order',
      order: order,
      thumbnailUrl: thumbnailUrl,
    );
  }

  test('photo post uses its first photo as the profile grid cover', () {
    final Post post = postWithMedia(
      thumbnailUrl: 'https://example.com/unrelated-thumbnail.jpg',
      media: <PostMedia>[
        media(type: 'image', url: 'https://example.com/photo.jpg', order: 0),
      ],
    );

    expect(nubifyPostCover(post), 'https://example.com/photo.jpg');
  });

  test('video post uses the thumbnail saved on its first video', () {
    final Post post = postWithMedia(
      media: <PostMedia>[
        media(
          type: 'video',
          url: 'https://example.com/video.mp4',
          thumbnailUrl: 'https://example.com/video-thumbnail.jpg',
          order: 0,
        ),
      ],
    );

    expect(nubifyPostCover(post), 'https://example.com/video-thumbnail.jpg');
  });

  test('legacy video can use its post-level thumbnail', () {
    final Post post = postWithMedia(
      thumbnailUrl: 'https://example.com/legacy-thumbnail.jpg',
      media: <PostMedia>[
        media(
          type: 'video',
          url: 'https://example.com/legacy-video.mp4',
          order: 0,
        ),
      ],
    );

    expect(nubifyPostCover(post), 'https://example.com/legacy-thumbnail.jpg');
  });

  test('mixed post keeps the first video as its preview source', () {
    final Post post = postWithMedia(
      media: <PostMedia>[
        media(
          type: 'image',
          url: 'https://example.com/second-photo.jpg',
          order: 1,
        ),
        media(
          type: 'video',
          url: 'https://example.com/first-video.mp4',
          thumbnailUrl: 'https://example.com/first-video-thumbnail.jpg',
          order: 0,
        ),
      ],
    );

    expect(
      nubifyPostCover(post),
      'https://example.com/first-video-thumbnail.jpg',
    );
  });
}
