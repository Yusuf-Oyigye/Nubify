import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/nubify_honor_widgets.dart';

//===================================================
// BUILT-IN CAMPUS PHOTOS — EDIT ONLY THIS LIST
//
// Optional. Photos you add inside the app (the gold
// "Add photo" button) show up on their own. Use this
// list only for pictures you ship with the app:
// 1. Put the picture in assets/images/campus/
// 2. Add a line below with its name and file path.
//===================================================

const List<_CampusPlace> _builtInPlaces = [
  // _CampusPlace(
  //   name: 'Main Gate',
  //   photo: 'assets/images/campus/main_gate.jpg',
  // ),
];

//===================================================
// CAMPUS PLACE
//===================================================

class _CampusPlace {
  const _CampusPlace({
    required this.name,
    required this.photo,
    this.id = '',
    this.storagePath = '',
  });

  final String name;

  // An https link (added in the app) or an asset path.
  final String photo;

  // Only filled for photos added inside the app, so they
  // can be removed again.
  final String id;
  final String storagePath;
}

// Each photo needs a unique tag so it can fly into the
// full-screen viewer.
String _heroTag(int index, _CampusPlace place) =>
    'explore-$index-${place.photo}';

//===================================================
// PHOTOS STORED ONLINE
//
// Everyone signed in can see them. Only the Nubify
// owner account can add or remove them.
//===================================================

class _ExploreStore {
  static CollectionReference<Map<String, dynamic>> get _places =>
      FirebaseFirestore.instance.collection('nubify_explore_places');

  static Stream<List<_CampusPlace>> watchUploaded() {
    try {
      return _places
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => [
          for (final doc in snapshot.docs)
            if ((doc.data()['photoUrl'] ?? '').toString().startsWith('http'))
              _CampusPlace(
                id: doc.id,
                name: (doc.data()['name'] ?? '').toString(),
                photo: doc.data()['photoUrl'].toString(),
                storagePath: (doc.data()['storagePath'] ?? '').toString(),
              ),
        ],
      )
          .handleError((Object _) {});
    } catch (_) {
      return Stream<List<_CampusPlace>>.value(const []);
    }
  }

  static Future<bool> canEdit() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return false;
      }

      final IdTokenResult token = await user.getIdTokenResult();
      return token.claims?['marketplaceOwner'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> add(Uint8List bytes, String fileName, String name) async {
    final String extension = fileName.split('.').last.toLowerCase();
    final String contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final String path = 'nubifyPublicPages/explore/'
        'place_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final Reference ref = FirebaseStorage.instance.ref(path);

    await ref.putData(bytes, SettableMetadata(contentType: contentType));

    await _places.add({
      'name': name,
      'photoUrl': await ref.getDownloadURL(),
      'storagePath': path,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> remove(_CampusPlace place) async {
    await _places.doc(place.id).delete();

    try {
      await FirebaseStorage.instance.ref(place.storagePath).delete();
    } catch (_) {
      // The file is already gone; nothing to clean up.
    }
  }
}

//===================================================
// NUBIFY — EXPLORE NUB
//===================================================

class ExploreNubScreen extends StatefulWidget {
  const ExploreNubScreen({super.key});

  @override
  State<ExploreNubScreen> createState() => _ExploreNubScreenState();
}

class _ExploreNubScreenState extends State<ExploreNubScreen> {
  late final Stream<List<_CampusPlace>> _uploaded =
  _ExploreStore.watchUploaded();
  final TextEditingController _search = TextEditingController();

  String _query = '';
  bool _isOwner = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();

    _ExploreStore.canEdit().then((bool owner) {
      if (owner && mounted) {
        setState(() => _isOwner = true);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  //===================================================
  // ACTIONS
  //===================================================

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _addPlace() async {
    final XFile? photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (photo == null) {
      return;
    }

    final Uint8List bytes = await photo.readAsBytes();

    if (!mounted) {
      return;
    }

    final String? name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddPlaceSheet(bytes: bytes),
    );

    if (name == null || name.trim().isEmpty) {
      return;
    }

    await _run(
          () => _ExploreStore.add(bytes, photo.name, name.trim()),
      'Photo added to Explore NUB',
    );
  }

  Future<void> _removePlace(_CampusPlace place) async {
    final bool? remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this photo?'),
        content: Text(
          '"${place.name}" will be removed from Explore NUB for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (remove == true) {
      await _run(() => _ExploreStore.remove(place), 'Photo removed');
    }
  }

  Future<void> _run(Future<void> Function() task, String success) async {
    setState(() => _busy = true);

    String message = success;

    try {
      await task();
    } on FirebaseException catch (error) {
      message = error.code == 'permission-denied' ||
          error.code == 'unauthorized'
          ? 'Adding photos is not switched on yet. '
          'Publish the new Firebase rules first.'
          : 'Something went wrong. Please try again.';
    } catch (_) {
      message = 'Something went wrong. Please try again.';
    }

    if (!mounted) {
      return;
    }

    setState(() => _busy = false);
    _snack(message);
  }

  void _openViewer(List<_CampusPlace> places, int index) {
    HapticFeedback.selectionClick();

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) =>
            _PlaceViewer(places: places, initialIndex: index),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  //===================================================
  // BUILD
  //===================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: NubifyHonorColors.page(context),
        floatingActionButton: _isOwner
            ? FloatingActionButton.extended(
          onPressed: _busy ? null : _addPlace,
          backgroundColor: NubifyHonorColors.gold,
          foregroundColor: NubifyHonorColors.ink,
          icon: const Icon(Icons.add_a_photo_rounded),
          label: const Text(
            'Add photo',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        )
            : null,
        body: StreamBuilder<List<_CampusPlace>>(
          stream: _uploaded,
          initialData: const [],
          builder: (context, snapshot) {
            final List<_CampusPlace> all = [
              ...?snapshot.data,
              ..._builtInPlaces,
            ];

            final String query = _query.trim().toLowerCase();
            final List<_CampusPlace> shown = query.isEmpty
                ? all
                : all
                .where((place) => place.name.toLowerCase().contains(query))
                .toList();

            // The first photo is shown big when not searching.
            final bool featured = query.isEmpty && shown.isNotEmpty;
            final int columns = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHero()),
                if (_busy)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: NubifyHonorColors.gold,
                    ),
                  ),
                if (all.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 2),
                      child: _buildSearch(),
                    ),
                  ),
                if (featured)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                      child: NubifyReveal(
                        delay: const Duration(milliseconds: 120),
                        child: _buildCard(shown, 0, featured: true),
                      ),
                    ),
                  ),
                if (shown.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmpty(nothingYet: all.isEmpty),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: .78,
                      ),
                      itemCount: shown.length - (featured ? 1 : 0),
                      itemBuilder: (context, i) => NubifyReveal(
                        delay: Duration(milliseconds: 160 + 60 * (i % 6)),
                        child: _buildCard(shown, i + (featured ? 1 : 0)),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(
      List<_CampusPlace> places,
      int index, {
        bool featured = false,
      }) {
    final _CampusPlace place = places[index];

    return _PlaceCard(
      place: place,
      heroTag: _heroTag(index, place),
      featured: featured,
      onTap: () => _openViewer(places, index),
      onLongPress: _isOwner && place.id.isNotEmpty
          ? () => _removePlace(place)
          : null,
    );
  }

  //===================================================
  // HEADER
  //===================================================

  Widget _buildHero() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NubifyHonorColors.ink,
              NubifyHonorColors.inkSoft,
              Color(0xFF12304A),
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -80,
              right: -60,
              child: NubifyGlow(color: Color(0xFF3FA7D6), size: 210),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 18, 22),
                child: Column(
                  children: [
                    const NubifyHeaderBar(title: 'Explore NUB'),
                    const SizedBox(height: 14),
                    NubifyReveal(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF7CC8EE),
                                    Color(0xFF2B7BB9),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3FA7D6)
                                        .withValues(alpha: .45),
                                    blurRadius: 22,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.travel_explore_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Our campus',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .3,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Discover the places that make NUB '
                                        'home. Tap a photo to see it in full.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13.5,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===================================================
  // SEARCH
  //===================================================

  Widget _buildSearch() {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: NubifyHonorColors.line(context)),
    );

    return TextField(
      controller: _search,
      onChanged: (value) => setState(() => _query = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search places',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
          tooltip: 'Clear',
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            _search.clear();
            setState(() => _query = '');
          },
        ),
        filled: true,
        fillColor: NubifyHonorColors.card(context),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(
            color: NubifyHonorColors.gold,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  //===================================================
  // EMPTY STATE
  //===================================================

  Widget _buildEmpty({required bool nothingYet}) {
    final String message = nothingYet
        ? (_isOwner
        ? 'Tap Add photo to share the first one.'
        : 'Photos of our campus will appear here soon.')
        : 'Try another name.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NubifyHonorColors.gold.withValues(alpha: .12),
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              color: NubifyHonorColors.gold,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            nothingYet ? 'No campus photos yet' : 'No place matches "$_query"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NubifyHonorColors.text(context),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NubifyHonorColors.muted(context),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

//===================================================
// PHOTO (online link or asset)
//===================================================

class _PlaceImage extends StatelessWidget {
  const _PlaceImage({required this.photo, required this.fit});

  final String photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    const Widget broken = ColoredBox(
      color: NubifyHonorColors.inkSoft,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white38,
          size: 32,
        ),
      ),
    );

    if (photo.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: photo,
        fit: fit,
        placeholder: (_, _) =>
        const ColoredBox(color: NubifyHonorColors.inkSoft),
        errorWidget: (_, _, _) => broken,
      );
    }

    return Image.asset(photo, fit: fit, errorBuilder: (_, _, _) => broken);
  }
}

//===================================================
// PHOTO CARD
//===================================================

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.heroTag,
    required this.onTap,
    this.onLongPress,
    this.featured = false,
  });

  final _CampusPlace place;
  final String heroTag;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final double radius = featured ? 24 : 20;

    final Widget card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: heroTag,
              child: _PlaceImage(photo: place.photo, fit: BoxFit.cover),
            ),

            // Dark fade at the bottom so the name is readable.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [.45, 1],
                  colors: [Colors.transparent, Color(0xD9000000)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (featured) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: NubifyHonorColors.gold.withValues(alpha: .9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'CAMPUS HIGHLIGHT',
                        style: TextStyle(
                          color: NubifyHonorColors.ink,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.place_rounded,
                        size: featured ? 19 : 15,
                        color: NubifyHonorColors.goldLight,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: featured ? 20 : 14.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, onLongPress: onLongPress),
            ),
          ],
        ),
      ),
    );

    return featured ? AspectRatio(aspectRatio: 16 / 10, child: card) : card;
  }
}

//===================================================
// FULL-SCREEN VIEWER (swipe between photos)
//===================================================

class _PlaceViewer extends StatefulWidget {
  const _PlaceViewer({required this.places, required this.initialIndex});

  final List<_CampusPlace> places;
  final int initialIndex;

  @override
  State<_PlaceViewer> createState() => _PlaceViewerState();
}

class _PlaceViewerState extends State<_PlaceViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _CampusPlace place = widget.places[_index];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.places.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Hero(
                    tag: _heroTag(i, widget.places[i]),
                    child: _PlaceImage(
                      photo: widget.places[i].photo,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

            // Close button and photo counter.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .12),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (widget.places.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_index + 1} / ${widget.places.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Place name at the bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.place_rounded,
                            color: NubifyHonorColors.goldLight,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              place.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//===================================================
// ADD PHOTO SHEET (owner only)
//===================================================

class _AddPlaceSheet extends StatefulWidget {
  const _AddPlaceSheet({required this.bytes});

  final Uint8List bytes;

  @override
  State<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<_AddPlaceSheet> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();

    if (name.isNotEmpty) {
      Navigator.pop(context, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add a campus photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.memory(widget.bytes, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Place name',
                  hintText: 'e.g. Central Library',
                  prefixIcon: const Icon(Icons.place_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _name,
                builder: (context, value, _) => FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: value.text.trim().isEmpty ? null : _submit,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text(
                    'Add to Explore NUB',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}