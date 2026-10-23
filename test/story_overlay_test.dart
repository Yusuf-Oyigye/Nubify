import 'package:flutter_test/flutter_test.dart';
import 'package:nubify/models/story.dart';

void main() {
  test('story text position and finger drawing survive serialization', () {
    final NubifyStory story = NubifyStory.fromMap(<String, dynamic>{
      'storyId': 'story-1',
      'uid': 'user-1',
      'type': 'image',
      'text': 'Campus night',
      'textX': 0.27,
      'textY': 0.71,
      'textSize': 48.0,
      'drawings': <Map<String, dynamic>>[
        <String, dynamic>{
          'color': 0xFF62D8CF,
          'width': 8.0,
          'points': <Map<String, dynamic>>[
            <String, dynamic>{'x': 0.10, 'y': 0.20},
            <String, dynamic>{'x': 0.30, 'y': 0.40},
          ],
        },
      ],
    });

    expect(story.textX, closeTo(0.27, 0.001));
    expect(story.textY, closeTo(0.71, 0.001));
    expect(story.drawings, hasLength(1));
    expect(story.drawings.single.points, hasLength(2));

    final Map<String, dynamic> saved = story.toMap();
    expect(saved['textX'], closeTo(0.27, 0.001));
    expect(saved['textY'], closeTo(0.71, 0.001));
    expect(saved['drawings'], isNotEmpty);
  });

  test('old stories receive safe overlay defaults', () {
    final NubifyStory story = NubifyStory.fromMap(<String, dynamic>{
      'storyId': 'legacy-story',
      'uid': 'user-1',
      'type': 'text',
      'text': 'Old story',
    });

    expect(story.textX, 0.50);
    expect(story.textY, 0.50);
    expect(story.drawings, isEmpty);
  });
}
