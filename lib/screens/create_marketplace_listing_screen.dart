import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/marketplace_listing.dart';
import '../services/marketplace_media_service.dart';
import '../services/marketplace_service.dart';
import '../utils/marketplace_constants.dart';
import '../utils/marketplace_theme.dart';
import 'marketplace_listing_details_screen.dart';

class _EditableMarketplaceMedia {
  _EditableMarketplaceMedia.existing(this.existing)
    : pending = null,
      key = 'existing-marketplace-media-${_sequence++}';

  _EditableMarketplaceMedia.pending(this.pending)
    : existing = null,
      key = 'pending-marketplace-media-${_sequence++}';

  static int _sequence = 0;

  final MarketplaceMedia? existing;
  final PendingMarketplaceMedia? pending;
  final String key;
}

class CreateMarketplaceListingScreen extends StatefulWidget {
  const CreateMarketplaceListingScreen({super.key, this.listingId});

  final String? listingId;

  @override
  State<CreateMarketplaceListingScreen> createState() =>
      _CreateMarketplaceListingScreenState();
}

class _CreateMarketplaceListingScreenState
    extends State<CreateMarketplaceListingScreen> {
  final MarketplaceMediaService _mediaService = MarketplaceMediaService();
  final MarketplaceService _marketplace = MarketplaceService();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final List<_EditableMarketplaceMedia> _mediaItems =
      <_EditableMarketplaceMedia>[];
  final List<MarketplaceMedia> _removedExistingMedia = <MarketplaceMedia>[];

  String? _category;
  String? _condition;
  int _coverIndex = 0;
  bool _saving = false;
  bool _loadingExisting = false;
  MarketplaceListing? _editingListing;
  double _progress = 0;
  String _progressLabel = '';
  MarketplaceUploadCancellation? _uploadCancellation;
  bool _cancellingUpload = false;

  int get _totalMedia => _mediaItems.length;

  @override
  void initState() {
    super.initState();
    if (widget.listingId?.trim().isNotEmpty == true) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    try {
      final MarketplaceListing? listing = await _marketplace.getListing(
        widget.listingId!.trim(),
      );
      if (listing == null) {
        throw StateError('This listing no longer exists.');
      }
      if (listing.sellerId != FirebaseAuth.instance.currentUser?.uid) {
        throw StateError('Only the listing owner can edit it.');
      }
      _editingListing = listing;
      _title.text = listing.title;
      _description.text = listing.description;
      _price.text = listing.price?.toString() ?? '';
      _category = listing.category.isEmpty ? null : listing.category;
      _condition = listing.condition.isEmpty ? null : listing.condition;
      _mediaItems
        ..clear()
        ..addAll(listing.media.map(_EditableMarketplaceMedia.existing));
      _coverIndex = listing.coverMediaIndex < 0 ? 0 : listing.coverMediaIndex;
    } catch (error) {
      if (mounted) {
        _message(error.toString());
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingExisting = false);
      }
    }
  }

  Future<void> _addFromGallery() async {
    final int remaining = MarketplaceConstants.maxMediaCount - _totalMedia;
    if (remaining <= 0) {
      _message('You can add a maximum of five photos and videos combined.');
      return;
    }
    try {
      final List<PendingMarketplaceMedia> selected = await _mediaService
          .pickGallery(remainingSlots: remaining);
      if (selected.isNotEmpty && mounted) {
        setState(
          () => _mediaItems.addAll(
            selected.map(_EditableMarketplaceMedia.pending),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _message(_mediaError(error));
      }
    }
  }

  Future<void> _capture({required bool video}) async {
    if (_totalMedia >= MarketplaceConstants.maxMediaCount) {
      _message('You already selected five media files.');
      return;
    }
    try {
      final PendingMarketplaceMedia? selected = video
          ? await _mediaService.captureVideo()
          : await _mediaService.capturePhoto();
      if (selected != null && mounted) {
        setState(
          () => _mediaItems.add(_EditableMarketplaceMedia.pending(selected)),
        );
      }
    } catch (error) {
      if (mounted) {
        _message(_mediaError(error));
      }
    }
  }

  Future<void> _replaceMedia(int index) async {
    if (_saving || index < 0 || index >= _mediaItems.length) {
      return;
    }
    try {
      final List<PendingMarketplaceMedia> selected = await _mediaService
          .pickGallery(remainingSlots: 1);
      if (selected.isEmpty || !mounted) {
        return;
      }
      setState(() {
        final MarketplaceMedia? oldExisting = _mediaItems[index].existing;
        if (oldExisting != null) {
          _removedExistingMedia.add(oldExisting);
        }
        _mediaItems[index] = _EditableMarketplaceMedia.pending(selected.first);
      });
    } catch (error) {
      if (mounted) {
        _message(_mediaError(error));
      }
    }
  }

  String _mediaError(Object error) {
    return error
        .toString()
        .replaceFirst('FormatException: ', '')
        .replaceFirst('PlatformException', 'Media picker error');
  }

  void _removeMedia(int index) {
    if (index < 0 || index >= _mediaItems.length) {
      return;
    }
    setState(() {
      final _EditableMarketplaceMedia removed = _mediaItems.removeAt(index);
      if (removed.existing != null) {
        _removedExistingMedia.add(removed.existing!);
      }
      if (_mediaItems.isEmpty) {
        _coverIndex = 0;
      } else if (index < _coverIndex) {
        _coverIndex -= 1;
      } else if (_coverIndex >= _mediaItems.length) {
        _coverIndex = _mediaItems.length - 1;
      }
    });
  }

  void _moveMedia(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _mediaItems.length ||
        newIndex < 0 ||
        newIndex >= _mediaItems.length ||
        oldIndex == newIndex) {
      return;
    }
    setState(() {
      final _EditableMarketplaceMedia? cover = _mediaItems.isEmpty
          ? null
          : _mediaItems[_coverIndex.clamp(0, _mediaItems.length - 1)];
      final _EditableMarketplaceMedia moved = _mediaItems.removeAt(oldIndex);
      _mediaItems.insert(newIndex, moved);
      if (cover != null) {
        _coverIndex = _mediaItems.indexOf(cover);
      }
    });
  }

  Future<void> _showMediaSource() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photos or videos'),
              subtitle: Text(
                '${MarketplaceConstants.maxMediaCount - _totalMedia} slots remaining',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _addFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _capture(video: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Record a video'),
              subtitle: const Text('Maximum recording length: 2 minutes'),
              onTap: () {
                Navigator.pop(sheetContext);
                _capture(video: true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save({required bool publish}) async {
    if (_saving) {
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _message('Sign in before creating a listing.');
      return;
    }
    if (publish) {
      final String? validation = _validatePublish();
      if (validation != null) {
        _message(validation);
        return;
      }
    }

    setState(() {
      _saving = true;
      _progress = 0;
      _progressLabel = 'Preparing listing';
    });

    final DocumentReference<Map<String, dynamic>> reference = FirebaseFirestore
        .instance
        .collection('marketplaceProducts')
        .doc(_editingListing?.listingId);
    List<MarketplaceMedia> uploaded = <MarketplaceMedia>[];
    MarketplaceUploadCancellation? cancellation;
    bool listingSaved = false;
    final bool newlyPublishing =
        publish && (_editingListing?.status ?? 'draft') != 'available';
    try {
      final DocumentSnapshot<Map<String, dynamic>> profile =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final Map<String, dynamic> userData =
          profile.data() ?? <String, dynamic>{};
      final List<PendingMarketplaceMedia> pendingMedia = _mediaItems
          .map((_EditableMarketplaceMedia item) => item.pending)
          .whereType<PendingMarketplaceMedia>()
          .toList(growable: false);
      if (pendingMedia.isNotEmpty) {
        cancellation = MarketplaceUploadCancellation();
        if (mounted) {
          setState(() => _uploadCancellation = cancellation);
        }
        uploaded = await _mediaService.upload(
          uid: user.uid,
          listingId: reference.id,
          files: pendingMedia,
          startIndex: 0,
          cancellation: cancellation,
          onProgress: (double value, String label) {
            if (mounted) {
              setState(() {
                _progress = value;
                _progressLabel = label;
              });
            }
          },
        );
        if (mounted && identical(_uploadCancellation, cancellation)) {
          setState(() => _uploadCancellation = null);
        }
      }
      int uploadedIndex = 0;
      final List<MarketplaceMedia> combined = _mediaItems
          .map((_EditableMarketplaceMedia item) {
            if (item.existing != null) {
              return item.existing!;
            }
            final MarketplaceMedia value = uploaded[uploadedIndex];
            uploadedIndex += 1;
            return value;
          })
          .toList(growable: false);
      final List<MarketplaceMedia> normalized = List<MarketplaceMedia>.generate(
        combined.length,
        (int index) {
          final MarketplaceMedia item = combined[index];
          return MarketplaceMedia(
            type: item.type,
            url: item.url,
            thumbnailUrl: item.thumbnailUrl,
            durationMs: item.durationMs,
            displayOrder: index,
            storagePath: item.storagePath,
          );
        },
      );
      final int safeCover = normalized.isEmpty
          ? -1
          : _coverIndex.clamp(0, normalized.length - 1);
      final String thumbnail = normalized.isEmpty
          ? ''
          : (normalized[safeCover].thumbnailUrl.trim().isEmpty
                ? normalized[safeCover].url
                : normalized[safeCover].thumbnailUrl);
      final double? numericPrice = double.tryParse(_price.text.trim());

      final Map<String, dynamic> listingData = <String, dynamic>{
        'listingId': reference.id,
        'sellerId': user.uid,
        'sellerName': (userData['fullName'] ?? '').toString(),
        'sellerPhotoUrl': (userData['photoUrl'] ?? '').toString(),
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category': _category ?? '',
        'condition': _condition ?? '',
        'priceType': 'fixed',
        'price': numericPrice,
        'currency': MarketplaceConstants.currency,
        'media': normalized
            .map((MarketplaceMedia item) => item.toMap())
            .toList(),
        'mediaCount': normalized.length,
        'coverMediaIndex': safeCover,
        'thumbnailUrl': thumbnail,
        'status': _editingListing?.status ?? 'draft',
        'publicVisible': _editingListing?.publicVisible ?? false,
        'contactPreferences': <String, dynamic>{
          'allowMessages': true,
          'allowCalls': true,
        },
        'searchPrefixes':
            publish || (_editingListing?.status ?? 'draft') == 'available'
            ? MarketplaceConstants.buildSearchPrefixes(<String>[
                _title.text,
                _description.text,
                _category ?? '',
                (userData['fullName'] ?? '').toString(),
              ])
            : <String>[],
        'createdAt': _editingListing?.createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(_editingListing!.createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
        'publishedAt': _editingListing?.publishedAt == null
            ? null
            : Timestamp.fromDate(_editingListing!.publishedAt!),
        'soldAt': _editingListing?.soldAt == null
            ? null
            : Timestamp.fromDate(_editingListing!.soldAt!),
        'unavailableAt': _editingListing?.unavailableAt == null
            ? null
            : Timestamp.fromDate(_editingListing!.unavailableAt!),
        'archivedAt': _editingListing?.archivedAt == null
            ? null
            : Timestamp.fromDate(_editingListing!.archivedAt!),
      };
      await reference.set(listingData);
      listingSaved = true;

      if (_removedExistingMedia.isNotEmpty) {
        await _mediaService.deleteUploadedMedia(_removedExistingMedia);
      }

      if (newlyPublishing) {
        setState(() => _progressLabel = 'Publishing listing');
        await _marketplace.publish(reference.id);
      }

      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      if (publish) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: MarketplaceTheme.emerald,
              size: 62,
            ),
            title: Text(
              newlyPublishing ? 'Listing Published!' : 'Changes Saved!',
            ),
            content: Text(
              newlyPublishing
                  ? 'Your listing is now available in NUB Marketplace.'
                  : 'Your available listing has been updated.',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('View Listing'),
              ),
            ],
          ),
        );
        if (!mounted) {
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                MarketplaceListingDetailsScreen(listingId: reference.id),
          ),
        );
      } else {
        _message(
          _editingListing == null
              ? 'Draft saved privately.'
              : 'Listing updated.',
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (!listingSaved && uploaded.isNotEmpty) {
        await _mediaService.deleteUploadedMedia(uploaded);
      }
      if (mounted) {
        _message(
          cancellation?.isCancelled == true ||
                  error is MarketplaceUploadCancelledException
              ? 'Upload cancelled. Nothing was published.'
              : _saveError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadCancellation = null;
          _cancellingUpload = false;
        });
      }
    }
  }

  Future<void> _cancelUpload() async {
    final MarketplaceUploadCancellation? cancellation = _uploadCancellation;
    if (cancellation == null || _cancellingUpload) {
      return;
    }
    setState(() {
      _cancellingUpload = true;
      _progressLabel = 'Cancelling upload…';
    });
    try {
      await cancellation.cancel();
    } catch (_) {
      // The upload Future reports the final cancellation result and cleanup.
    }
  }

  String? _validatePublish() {
    if (_totalMedia == 0) return 'Add at least one photo or video.';
    if (_title.text.trim().length < 2) return 'Enter a clear listing title.';
    if (_category == null) return 'Choose a category.';
    if (_condition == null) return 'Choose the condition.';
    final double? value = double.tryParse(_price.text.trim());
    if (value == null || value <= 0 || value > 100000000) {
      return 'Enter a valid price greater than zero.';
    }
    return null;
  }

  String _saveError(Object error) {
    final String value = error.toString();
    final String normalized = value.toLowerCase();
    if (normalized.contains('unauthorized') ||
        normalized.contains('permission-denied')) {
      return 'Nubify could not upload this listing. Please refresh and try again.';
    }
    return value.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _saving) {
          _message('Cancel the current upload before leaving this screen.');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _editingListing == null ? 'Sell on Marketplace' : 'Edit Listing',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _saving ? null : () => _save(publish: false),
              child: Text(
                _editingListing == null ? 'Save Draft' : 'Save Changes',
              ),
            ),
          ],
        ),
        body: _loadingExisting
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Show it beautifully',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Choose up to five photos and videos combined.',
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$_totalMedia/5',
                        style: const TextStyle(
                          color: MarketplaceTheme.sky,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 126,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _totalMedia + (_totalMedia < 5 ? 1 : 0),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == _mediaItems.length) {
                          return Padding(
                            key: const ValueKey<String>(
                              'add-marketplace-media',
                            ),
                            padding: const EdgeInsets.only(right: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: _showMediaSource,
                              child: Ink(
                                width: 112,
                                decoration: BoxDecoration(
                                  color: MarketplaceTheme.softSurface(context),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: MarketplaceTheme.sky.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: MarketplaceTheme.sky,
                                      size: 34,
                                    ),
                                    SizedBox(height: 7),
                                    Text(
                                      'Add media',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        final _EditableMarketplaceMedia entry =
                            _mediaItems[index];
                        final Widget tile = entry.existing != null
                            ? _ExistingMediaTile(
                                item: entry.existing!,
                                cover: index == _coverIndex,
                                onCover: () =>
                                    setState(() => _coverIndex = index),
                                onReplace: () => _replaceMedia(index),
                                onRemove: () => _removeMedia(index),
                              )
                            : _PendingMediaTile(
                                item: entry.pending!,
                                cover: index == _coverIndex,
                                onCover: () =>
                                    setState(() => _coverIndex = index),
                                onReplace: () => _replaceMedia(index),
                                onRemove: () => _removeMedia(index),
                              );
                        return Padding(
                          key: ValueKey<String>(entry.key),
                          padding: const EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 112,
                            height: 126,
                            child: Stack(
                              children: <Widget>[
                                tile,
                                if (_mediaItems.length > 1)
                                  Positioned(
                                    left: 4,
                                    top: 4,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        _MediaMoveButton(
                                          tooltip: 'Move left',
                                          icon: Icons.chevron_left_rounded,
                                          onTap: index > 0
                                              ? () =>
                                                    _moveMedia(index, index - 1)
                                              : null,
                                        ),
                                        const SizedBox(width: 3),
                                        _MediaMoveButton(
                                          tooltip: 'Move right',
                                          icon: Icons.chevron_right_rounded,
                                          onTap: index < _mediaItems.length - 1
                                              ? () =>
                                                    _moveMedia(index, index + 1)
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_totalMedia > 0) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Tap to choose the cover. Use the arrow buttons to reorder and the swap icon to replace a file.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 22),
                  TextField(
                    controller: _title,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Title (required)',
                      prefixIcon: Icon(Icons.title_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: InputDecoration(
                      labelText: 'Category (required)',
                      prefixIcon: Icon(
                        _category == null
                            ? Icons.category_outlined
                            : MarketplaceConstants.categories
                                  .firstWhere(
                                    (MarketplaceCategory item) =>
                                        item.id == _category,
                                  )
                                  .icon,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: MarketplaceConstants.categories
                        .map(
                          (MarketplaceCategory value) =>
                              DropdownMenuItem<String>(
                                value: value.id,
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      value.icon,
                                      size: 20,
                                      color: MarketplaceTheme.sky,
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(child: Text(value.label)),
                                  ],
                                ),
                              ),
                        )
                        .toList(),
                    onChanged: (String? value) =>
                        setState(() => _category = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _condition,
                    decoration: const InputDecoration(
                      labelText: 'Condition (required)',
                      prefixIcon: Icon(Icons.auto_awesome_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: MarketplaceConstants.conditions
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              MarketplaceConstants.conditionLabel(value),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) =>
                        setState(() => _condition = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Price (required)',
                      prefixText: 'EGP ',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    minLines: 5,
                    maxLines: 10,
                    maxLength: 5000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_saving) ...<Widget>[
                    const SizedBox(height: 18),
                    LinearProgressIndicator(
                      value: _progress > 0 && _progress < 1 ? _progress : null,
                    ),
                    const SizedBox(height: 8),
                    Text(_progressLabel, textAlign: TextAlign.center),
                    if (_uploadCancellation != null) ...<Widget>[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _cancellingUpload ? null : _cancelUpload,
                        icon: const Icon(Icons.close_rounded),
                        label: Text(
                          _cancellingUpload ? 'Cancelling…' : 'Cancel Upload',
                        ),
                      ),
                    ],
                  ],
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () => _save(
                      publish: (_editingListing?.status ?? 'draft') != 'sold',
                    ),
              icon: const Icon(Icons.rocket_launch_rounded),
              label: Text(
                _saving
                    ? 'Saving…'
                    : _editingListing?.status == 'available'
                    ? 'Save Changes'
                    : _editingListing?.status == 'sold'
                    ? 'Save Sold Listing'
                    : 'Publish Listing',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: MarketplaceTheme.sky,
                foregroundColor: MarketplaceTheme.midnight,
                minimumSize: const Size.fromHeight(54),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }
}

class _MediaMoveButton extends StatelessWidget {
  const _MediaMoveButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(
              icon,
              size: 17,
              color: onTap == null ? Colors.white38 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingMediaTile extends StatelessWidget {
  const _PendingMediaTile({
    required this.item,
    required this.cover,
    required this.onCover,
    required this.onReplace,
    required this.onRemove,
  });

  final PendingMarketplaceMedia item;
  final bool cover;
  final VoidCallback onCover;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: onCover,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 112,
              height: 126,
              child: item.isVideo
                  ? ColoredBox(
                      color: MarketplaceTheme.navy,
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    )
                  : FutureBuilder<Uint8List>(
                      future: item.file.readAsBytes(),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<Uint8List> snapshot,
                          ) {
                            if (!snapshot.hasData) {
                              return const ColoredBox(
                                color: MarketplaceTheme.navy,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                            );
                          },
                    ),
            ),
          ),
        ),
        if (cover)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: MarketplaceTheme.sky,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'COVER',
                style: TextStyle(
                  color: MarketplaceTheme.midnight,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        Positioned(
          right: 4,
          top: 4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 17),
              ),
            ),
          ),
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onReplace,
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExistingMediaTile extends StatelessWidget {
  const _ExistingMediaTile({
    required this.item,
    required this.cover,
    required this.onCover,
    required this.onReplace,
    required this.onRemove,
  });

  final MarketplaceMedia item;
  final bool cover;
  final VoidCallback onCover;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String preview = item.thumbnailUrl.isNotEmpty
        ? item.thumbnailUrl
        : item.url;
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: onCover,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 112,
              height: 126,
              child: preview.isEmpty
                  ? const ColoredBox(
                      color: MarketplaceTheme.navy,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                      ),
                    )
                  : Image.network(preview, fit: BoxFit.cover),
            ),
          ),
        ),
        if (item.isVideo)
          const Positioned(
            left: 42,
            top: 45,
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        if (cover)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: MarketplaceTheme.sky,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'COVER',
                style: TextStyle(
                  color: MarketplaceTheme.midnight,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        Positioned(
          right: 4,
          top: 4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 17),
              ),
            ),
          ),
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onReplace,
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
