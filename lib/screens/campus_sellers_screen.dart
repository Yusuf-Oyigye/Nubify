import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/marketplace_theme.dart';
import 'marketplace_seller_store_screen.dart';

//===================================================
// CAMPUS SELLERS — NO SEPARATE SELLER REGISTRATION
//===================================================

class CampusSellersScreen extends StatefulWidget {
  const CampusSellersScreen({super.key});

  @override
  State<CampusSellersScreen> createState() => _CampusSellersScreenState();
}

class _SellerPreview {
  const _SellerPreview({
    required this.id,
    required this.name,
    required this.photoUrl,
    this.knownCount,
  });

  final String id;
  final String name;
  final String photoUrl;
  final int? knownCount;
}

class _CampusSellersScreenState extends State<CampusSellersScreen> {
  final TextEditingController _search = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, Future<int>> _countRequests = <String, Future<int>>{};

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _sellerStream;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _newListingsStream;

  String _query = '';

  //===================================================
  // INITIALIZE FIRESTORE STREAMS
  //===================================================

  @override
  void initState() {
    super.initState();

    _sellerStream = _firestore
        .collection('marketplaceSellerStats')
        .where('availableListingCount', isGreaterThan: 0)
        .orderBy('availableListingCount', descending: true)
        .limit(100)
        .snapshots();

    // Newly published sellers can appear before
    // the server-generated seller statistics update.

    _newListingsStream = _firestore
        .collection('marketplaceProducts')
        .where('status', isEqualTo: 'available')
        .where('publicVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  //===================================================
  // COUNT ACTUAL AVAILABLE LISTINGS
  //===================================================

  Future<int> _actualAvailableCount(String sellerId) async {
    final AggregateQuerySnapshot count = await _firestore
        .collection('marketplaceProducts')
        .where('sellerId', isEqualTo: sellerId)
        .where('status', isEqualTo: 'available')
        .where('publicVisible', isEqualTo: true)
        .limit(50)
        .count()
        .get();

    return count.count ?? 0;
  }

  //===================================================
  // SELLER AVAILABLE LISTING COUNT
  //===================================================

  Widget _availableCount(_SellerPreview seller) {
    if (seller.knownCount != null) {
      final int count = seller.knownCount!;

      return Text(
        '$count available ${count == 1 ? 'listing' : 'listings'}',
        textAlign: TextAlign.center,
      );
    }

    return FutureBuilder<int>(
      future: _countRequests.putIfAbsent(
        seller.id,
        () => _actualAvailableCount(seller.id),
      ),
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        if (snapshot.hasError) {
          return const Text('Available listings', textAlign: TextAlign.center);
        }

        if (!snapshot.hasData) {
          return const Text('New campus seller', textAlign: TextAlign.center);
        }

        final int count = snapshot.data!;

        return Text(
          '$count available ${count == 1 ? 'listing' : 'listings'}',
          textAlign: TextAlign.center,
        );
      },
    );
  }

  //===================================================
  // CAMPUS SELLERS SCREEN
  //===================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Sellers')),
      body: Column(
        children: <Widget>[
          //===================================================
          // SEARCH SELLERS
          //===================================================

          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: (String value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search campus sellers',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: MarketplaceTheme.softSurface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          //===================================================
          // SELLER DIRECTORY
          //===================================================
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _sellerStream,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> stats,
                  ) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _newListingsStream,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                            recent,
                          ) {
                            if (!stats.hasData &&
                                !recent.hasData &&
                                (stats.connectionState ==
                                        ConnectionState.waiting ||
                                    recent.connectionState ==
                                        ConnectionState.waiting)) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final Map<String, _SellerPreview> sellers =
                                <String, _SellerPreview>{};

                            //===================================================
                            // ADD NEW SELLERS FROM AVAILABLE LISTINGS
                            //===================================================

                            for (final QueryDocumentSnapshot<
                                  Map<String, dynamic>
                                >
                                doc
                                in recent.data?.docs ??
                                    <
                                      QueryDocumentSnapshot<
                                        Map<String, dynamic>
                                      >
                                    >[]) {
                              final Map<String, dynamic> data = doc.data();

                              final String id = (data['sellerId'] ?? '')
                                  .toString();

                              if (id.isEmpty || sellers.containsKey(id)) {
                                continue;
                              }

                              sellers[id] = _SellerPreview(
                                id: id,
                                name: (data['sellerName'] ?? 'Student seller')
                                    .toString(),
                                photoUrl: (data['sellerPhotoUrl'] ?? '')
                                    .toString(),
                              );
                            }

                            //===================================================
                            // MERGE EXISTING SELLER STATISTICS
                            //===================================================

                            for (final QueryDocumentSnapshot<
                                  Map<String, dynamic>
                                >
                                doc
                                in stats.data?.docs ??
                                    <
                                      QueryDocumentSnapshot<
                                        Map<String, dynamic>
                                      >
                                    >[]) {
                              final Map<String, dynamic> data = doc.data();

                              final String id = (data['sellerId'] ?? doc.id)
                                  .toString();

                              final int count =
                                  (data['availableListingCount'] as num?)
                                      ?.toInt() ??
                                  0;

                              if (id.isEmpty || count <= 0) {
                                continue;
                              }

                              final _SellerPreview? existing = sellers[id];

                              sellers[id] = _SellerPreview(
                                id: id,
                                name:
                                    (data['sellerName'] ??
                                            existing?.name ??
                                            'Student seller')
                                        .toString(),
                                photoUrl:
                                    (data['sellerPhotoUrl'] ??
                                            existing?.photoUrl ??
                                            '')
                                        .toString(),
                                knownCount: count,
                              );
                            }

                            //===================================================
                            // SEARCH FILTER
                            //===================================================

                            final List<_SellerPreview> visible = sellers.values
                                .where(
                                  (_SellerPreview seller) => seller.name
                                      .toLowerCase()
                                      .contains(_query),
                                )
                                .toList(growable: false);

                            //===================================================
                            // EMPTY STATE
                            //===================================================

                            if (visible.isEmpty) {
                              return Center(
                                child: Text(
                                  stats.hasError && recent.hasError
                                      ? 'Unable to load campus sellers. Please retry.'
                                      : _query.isEmpty
                                      ? 'No campus sellers yet.'
                                      : 'No campus seller matches your search.',
                                ),
                              );
                            }

                            //===================================================
                            // TWO COLUMN SELLER GRID
                            //===================================================

                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                              itemCount: visible.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.72,
                                  ),
                              itemBuilder: (BuildContext context, int index) {
                                final _SellerPreview seller = visible[index];

                                return InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            MarketplaceSellerStoreScreen(
                                              sellerId: seller.id,
                                            ),
                                      ),
                                    );
                                  },
                                  child: Ink(
                                    padding: const EdgeInsets.all(14),
                                    decoration: MarketplaceTheme.premiumCard(
                                      context,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        //===================================================
                                        // SELLER PHOTO
                                        //===================================================

                                        CircleAvatar(
                                          radius: 34,
                                          backgroundImage:
                                              seller.photoUrl.isEmpty
                                              ? null
                                              : CachedNetworkImageProvider(
                                                  seller.photoUrl,
                                                ),
                                          child: seller.photoUrl.isEmpty
                                              ? const Icon(
                                                  Icons.person_rounded,
                                                  size: 34,
                                                )
                                              : null,
                                        ),

                                        const SizedBox(height: 10),

                                        //===================================================
                                        // SELLER NAME
                                        //===================================================
                                        Text(
                                          seller.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),

                                        const SizedBox(height: 4),

                                        _availableCount(seller),

                                        const Spacer(),

                                        //===================================================
                                        // VIEW STORE BUTTON
                                        //===================================================
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      MarketplaceSellerStoreScreen(
                                                        sellerId: seller.id,
                                                      ),
                                                ),
                                              );
                                            },
                                            child: const Text('View Store'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }

  //===================================================
  // CLEANUP
  //===================================================

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}
