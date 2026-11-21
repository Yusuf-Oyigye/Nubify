import 'package:flutter/material.dart';

typedef ProfileFeedItemBuilder<T> =
    Widget Function(BuildContext context, T item, int index);

//===================================================
// PROFILE VERTICAL FEED
//
// OPENS AT THE GRID ITEM THE USER TAPPED.
// ITEMS BEFORE IT REMAIN AVAILABLE ABOVE, WHILE THE
// TAPPED ITEM AND THE REST OF THE FEED GROW DOWNWARD.
//===================================================

class ProfileVerticalFeed<T> extends StatefulWidget {
  const ProfileVerticalFeed({
    super.key,
    required this.title,
    required this.items,
    required this.initialIndex,
    required this.itemBuilder,
  });

  final String title;
  final List<T> items;
  final int initialIndex;
  final ProfileFeedItemBuilder<T> itemBuilder;

  @override
  State<ProfileVerticalFeed<T>> createState() => _ProfileVerticalFeedState<T>();
}

class _ProfileVerticalFeedState<T> extends State<ProfileVerticalFeed<T>> {
  final GlobalKey _centerKey = GlobalKey();

  late final int _initialIndex;

  @override
  void initState() {
    super.initState();

    _initialIndex = widget.items.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.items.length - 1);
  }

  Widget _buildItem(BuildContext context, int actualIndex) {
    return KeyedSubtree(
      key: ValueKey<String>('profile-feed-item-$actualIndex'),
      child: widget.itemBuilder(
        context,
        widget.items[actualIndex],
        actualIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('No posts to show.')),
      );
    }

    final int itemsBefore = _initialIndex;
    final int itemsFromSelected = widget.items.length - _initialIndex;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: CustomScrollView(
        center: _centerKey,
        slivers: <Widget>[
          // The closest previous item is child zero because this sliver
          // grows in the opposite direction above the selected item.
          if (itemsBefore > 0)
            SliverList(
              delegate: SliverChildBuilderDelegate((
                BuildContext context,
                int index,
              ) {
                final int actualIndex = _initialIndex - index - 1;

                return _buildItem(context, actualIndex);
              }, childCount: itemsBefore),
            ),

          SliverList(
            key: _centerKey,
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int index,
            ) {
              final int actualIndex = _initialIndex + index;

              return _buildItem(context, actualIndex);
            }, childCount: itemsFromSelected),
          ),
        ],
      ),
    );
  }
}
