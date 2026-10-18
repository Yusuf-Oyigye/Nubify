import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/marketplace_theme.dart';
import 'marketplace_seller_store_screen.dart';

class CampusSellersScreen extends StatefulWidget {
  const CampusSellersScreen({super.key});

  @override
  State<CampusSellersScreen> createState() => _CampusSellersScreenState();
}

class _CampusSellersScreenState extends State<CampusSellersScreen> {
  final TextEditingController _search = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _sellerStream;
  String _query = '';

  @override
  void initState() {
    super.initState();
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'marketplaceSellerStats',
    );
    query = query
        .where('availableListingCount', isGreaterThan: 0)
        .orderBy('availableListingCount', descending: true);
    _sellerStream = query.limit(100).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Sellers')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: (String value) =>
                  setState(() => _query = value.trim().toLowerCase()),
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
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _sellerStream,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs =
                        (snapshot.data?.docs ??
                                <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                            .where(
                              (doc) => (doc.data()['sellerName'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(_query),
                            )
                            .toList();
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          _query.isEmpty
                              ? 'No campus seller yet.'
                              : 'No campus seller matches this search.',
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: docs.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.9,
                          ),
                      itemBuilder: (BuildContext context, int index) {
                        final data = docs[index].data();
                        final String sellerId =
                            (data['sellerId'] ?? docs[index].id).toString();
                        final String photo = (data['sellerPhotoUrl'] ?? '')
                            .toString();
                        return InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => MarketplaceSellerStoreScreen(
                                sellerId: sellerId,
                              ),
                            ),
                          ),
                          child: Ink(
                            padding: const EdgeInsets.all(16),
                            decoration: MarketplaceTheme.premiumCard(context),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 38,
                                  backgroundImage: photo.isEmpty
                                      ? null
                                      : CachedNetworkImageProvider(photo),
                                  child: photo.isEmpty
                                      ? const Icon(
                                          Icons.person_rounded,
                                          size: 36,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        (data['sellerName'] ?? 'Student seller')
                                            .toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${data['availableListingCount'] ?? 0} available listings',
                                ),
                                const Spacer(),
                                const Text(
                                  'View Store',
                                  style: TextStyle(
                                    color: MarketplaceTheme.sky,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}
