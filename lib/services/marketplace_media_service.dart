import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../models/marketplace_listing.dart';
import '../utils/marketplace_constants.dart';

class PendingMarketplaceMedia {
  const PendingMarketplaceMedia({
    required this.file,
    required this.type,
    required this.sizeBytes,
    required this.durationMs,
  });

  final XFile file;
  final String type;
  final int sizeBytes;
  final int durationMs;

  bool get isVideo => type == 'video';
}

class MarketplaceUploadCancelledException implements Exception {
  const MarketplaceUploadCancelledException();

  @override
  String toString() => 'Marketplace upload cancelled.';
}

class MarketplaceUploadCancellation {
  bool _cancelled = false;
  UploadTask? _activeTask;

  bool get isCancelled => _cancelled;

  Future<void> cancel() async {
    _cancelled = true;
    final UploadTask? task = _activeTask;
    if (task != null) {
      await task.cancel();
    }
  }

  void attach(UploadTask task) {
    _activeTask = task;
    if (_cancelled) {
      unawaited(task.cancel());
    }
  }

  void detach(UploadTask task) {
    if (identical(_activeTask, task)) {
      _activeTask = null;
    }
  }

  void throwIfCancelled() {
    if (_cancelled) {
      throw const MarketplaceUploadCancelledException();
    }
  }
}

//===================================================
// MARKETPLACE MEDIA PICKING AND FIREBASE UPLOADS
//===================================================

class MarketplaceMediaService {
  MarketplaceMediaService({ImagePicker? picker, FirebaseStorage? storage})
    : _picker = picker ?? ImagePicker(),
      _storage = storage ?? FirebaseStorage.instance;

  final ImagePicker _picker;
  final FirebaseStorage _storage;
  static const int _maximumBytes = 30 * 1024 * 1024;
  static const int _maximumVideoDurationMs = 2 * 60 * 1000;

  Future<List<PendingMarketplaceMedia>> pickGallery({
    required int remainingSlots,
  }) async {
    if (remainingSlots <= 0) {
      return const <PendingMarketplaceMedia>[];
    }
    final List<XFile> files = await _picker.pickMultipleMedia(
      limit: remainingSlots.clamp(1, MarketplaceConstants.maxMediaCount),
      imageQuality: 88,
    );
    final List<PendingMarketplaceMedia> result = <PendingMarketplaceMedia>[];
    for (final XFile file in files.take(remainingSlots)) {
      result.add(await _validatedPendingFromFile(file));
    }
    return result;
  }

  Future<PendingMarketplaceMedia?> capturePhoto() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
    );
    return file == null ? null : _validatedPendingFromFile(file);
  }

  Future<PendingMarketplaceMedia?> captureVideo() async {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );
    return file == null ? null : _validatedPendingFromFile(file);
  }

  Future<List<MarketplaceMedia>> upload({
    required String uid,
    required String listingId,
    required List<PendingMarketplaceMedia> files,
    required void Function(double progress, String label) onProgress,
    int startIndex = 0,
    MarketplaceUploadCancellation? cancellation,
  }) async {
    if (files.isEmpty || files.length > MarketplaceConstants.maxMediaCount) {
      throw StateError('Choose between 1 and 5 photos or videos.');
    }
    final List<MarketplaceMedia> uploaded = <MarketplaceMedia>[];
    final List<Reference> createdReferences = <Reference>[];

    try {
      for (int index = 0; index < files.length; index++) {
        cancellation?.throwIfCancelled();
        final PendingMarketplaceMedia pending = files[index];
        final String extension = _extension(pending.file.name, pending.type);
        final int displayIndex = startIndex + index;
        final int unique = DateTime.now().microsecondsSinceEpoch;
        final String mediaPath =
            'marketplace/$uid/$listingId/media_${displayIndex + 1}_$unique.$extension';
        final Reference mediaReference = _storage.ref(mediaPath);
        createdReferences.add(mediaReference);
        final Uint8List bytes = await pending.file.readAsBytes();
        cancellation?.throwIfCancelled();
        final UploadTask mediaTask = mediaReference.putData(
          bytes,
          SettableMetadata(
            contentType: pending.isVideo
                ? 'video/$extension'
                : 'image/$extension',
            customMetadata: <String, String>{
              'ownerUid': uid,
              'listingId': listingId,
              'mediaType': pending.type,
            },
          ),
        );
        cancellation?.attach(mediaTask);
        final StreamSubscription<TaskSnapshot> subscription = mediaTask
            .snapshotEvents
            .listen((TaskSnapshot snapshot) {
              final double fileProgress = snapshot.totalBytes == 0
                  ? 0
                  : snapshot.bytesTransferred / snapshot.totalBytes;
              onProgress(
                (index + fileProgress) / files.length,
                'Uploading ${index + 1} of ${files.length}',
              );
            });
        try {
          await mediaTask;
        } finally {
          await subscription.cancel();
          cancellation?.detach(mediaTask);
        }
        cancellation?.throwIfCancelled();
        final String mediaUrl = await mediaReference.getDownloadURL();

        String thumbnailUrl = mediaUrl;
        if (pending.isVideo) {
          final Uint8List? thumbnailBytes = await VideoThumbnail.thumbnailData(
            video: pending.file.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 1080,
            quality: 78,
          );
          if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
            final String thumbnailPath =
                'marketplace/$uid/$listingId/thumbnail_${displayIndex + 1}_$unique.jpg';
            final Reference thumbnailReference = _storage.ref(thumbnailPath);
            createdReferences.add(thumbnailReference);
            final UploadTask thumbnailTask = thumbnailReference.putData(
              thumbnailBytes,
              SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: <String, String>{
                  'ownerUid': uid,
                  'listingId': listingId,
                  'thumbnailFor': mediaPath,
                },
              ),
            );
            cancellation?.attach(thumbnailTask);
            try {
              await thumbnailTask;
            } finally {
              cancellation?.detach(thumbnailTask);
            }
            cancellation?.throwIfCancelled();
            thumbnailUrl = await thumbnailReference.getDownloadURL();
          }
        }

        uploaded.add(
          MarketplaceMedia(
            type: pending.type,
            url: mediaUrl,
            thumbnailUrl: thumbnailUrl,
            durationMs: pending.durationMs,
            displayOrder: displayIndex,
            storagePath: mediaPath,
          ),
        );
      }
      cancellation?.throwIfCancelled();
      onProgress(1, 'Saving listing');
      return uploaded;
    } catch (_) {
      for (final Reference reference in createdReferences) {
        try {
          await reference.delete();
        } catch (_) {
          // Best-effort orphan cleanup after an interrupted upload.
        }
      }
      rethrow;
    }
  }

  Future<void> deleteUploadedMedia(Iterable<MarketplaceMedia> media) async {
    for (final MarketplaceMedia item in media) {
      if (item.storagePath.trim().isNotEmpty) {
        try {
          await _storage.ref(item.storagePath).delete();
        } catch (_) {
          // Deleting an already-removed object is harmless.
        }
      }
      if (item.isVideo && item.thumbnailUrl.trim().isNotEmpty) {
        try {
          await _storage.refFromURL(item.thumbnailUrl).delete();
        } catch (_) {
          // A missing generated thumbnail must not block listing cleanup.
        }
      }
    }
  }

  Future<PendingMarketplaceMedia> _validatedPendingFromFile(XFile file) async {
    final String mime = file.mimeType?.toLowerCase() ?? '';
    final String extension = file.name.split('.').last.toLowerCase();
    final bool video =
        mime.startsWith('video/') ||
        <String>{'mp4', 'mov', 'm4v', 'webm', 'avi'}.contains(extension);
    final bool image =
        mime.startsWith('image/') ||
        <String>{
          'jpg',
          'jpeg',
          'png',
          'webp',
          'heic',
          'heif',
        }.contains(extension);
    if (!video && !image) {
      throw FormatException(
        '${file.name} is not a supported photo or video file.',
      );
    }

    final int sizeBytes = await file.length();
    if (sizeBytes <= 0) {
      throw FormatException('${file.name} is empty or could not be read.');
    }
    if (sizeBytes > _maximumBytes) {
      throw FormatException('${file.name} is larger than the 30 MB limit.');
    }

    int durationMs = 0;
    if (video && !kIsWeb) {
      final VideoPlayerController controller = VideoPlayerController.file(
        File(file.path),
      );
      try {
        await controller.initialize();
        durationMs = controller.value.duration.inMilliseconds;
      } finally {
        await controller.dispose();
      }
      if (durationMs <= 0) {
        throw FormatException('${file.name} could not be read as a video.');
      }
      if (durationMs > _maximumVideoDurationMs) {
        throw FormatException(
          '${file.name} is longer than the 2-minute limit.',
        );
      }
    }

    return PendingMarketplaceMedia(
      file: file,
      type: video ? 'video' : 'image',
      sizeBytes: sizeBytes,
      durationMs: durationMs,
    );
  }

  String _extension(String name, String type) {
    final String extension = name.contains('.')
        ? name.split('.').last.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '')
        : '';
    if (extension.isNotEmpty && extension.length <= 5) {
      return extension;
    }
    return type == 'video' ? 'mp4' : 'jpg';
  }
}
