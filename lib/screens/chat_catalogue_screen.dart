import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

//===============================
// CHAT CATALOGUE SCREEN
//===============================

class ChatCatalogueScreen
    extends StatelessWidget {
  ChatCatalogueScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    required this.sellerUsername,
    required this.sellerPhotoUrl,
  });

  final String sellerId;

  final String sellerName;

  final String sellerUsername;

  final String sellerPhotoUrl;

  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  static const Color
  _blue =
  Color(
    0xFF29B6F6,
  );

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      const Color(
        0xFF0B1116,
      ),
      appBar:
      AppBar(
        backgroundColor:
        const Color(
          0xFF0B1116,
        ),
        title:
        const Text(
          'Catalogue',
          style:
          TextStyle(
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body:
      Column(
        children:
        <Widget>[
          //===============================
          // SELLER HEADER
          //===============================

          Container(
            width:
            double.infinity,
            padding:
            const EdgeInsets.fromLTRB(
              18,
              16,
              18,
              18,
            ),
            decoration:
            const BoxDecoration(
              gradient:
              LinearGradient(
                colors:
                <Color>[
                  Color(
                    0xFF15242D,
                  ),
                  Color(
                    0xFF0B1116,
                  ),
                ],
                begin:
                Alignment.topCenter,
                end:
                Alignment.bottomCenter,
              ),
            ),
            child:
            Row(
              children:
              <Widget>[
                CircleAvatar(
                  radius:
                  32,
                  backgroundColor:
                  Colors.white10,
                  backgroundImage:
                  sellerPhotoUrl
                      .trim()
                      .isNotEmpty
                      ? NetworkImage(
                    sellerPhotoUrl,
                  )
                      : null,
                  child:
                  sellerPhotoUrl
                      .trim()
                      .isEmpty
                      ? const Icon(
                    Icons
                        .person_rounded,
                    color:
                    Colors.white,
                  )
                      : null,
                ),

                const SizedBox(
                  width:
                  12,
                ),

                Expanded(
                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children:
                    <Widget>[
                      Text(
                        sellerName,
                        maxLines:
                        1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color:
                          Colors.white,
                          fontSize:
                          19,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),

                      if (sellerUsername
                          .trim()
                          .isNotEmpty)
                        Text(
                          '@$sellerUsername',
                          style:
                          const TextStyle(
                            color:
                            Colors.white60,
                          ),
                        ),

                      const SizedBox(
                        height:
                        6,
                      ),

                      const Row(
                        children:
                        <Widget>[
                          Icon(
                            Icons
                                .verified_rounded,
                            size:
                            15,
                            color:
                            _blue,
                          ),
                          SizedBox(
                            width:
                            4,
                          ),
                          Text(
                            'Nubify Marketplace',
                            style:
                            TextStyle(
                              color:
                              Colors.white54,
                              fontSize:
                              11,
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

          //===============================
          // PRODUCTS
          //===============================

          Expanded(
            child:
            StreamBuilder<
                QuerySnapshot<
                    Map<String,
                        dynamic>>>(
              stream:
              _firestore
                  .collection(
                'marketplaceProducts',
              )
                  .where(
                'sellerId',
                isEqualTo:
                sellerId,
              )
                  .snapshots(),
              builder:
                  (
                  BuildContext
                  context,
                  AsyncSnapshot<
                      QuerySnapshot<
                          Map<String,
                              dynamic>>>
                  snapshot,
                  ) {
                if (snapshot
                    .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                    CircularProgressIndicator(
                      color:
                      _blue,
                    ),
                  );
                }

                final docs =
                    snapshot
                        .data
                        ?.docs ??
                        [];

                if (docs.isEmpty) {
                  return const Center(
                    child:
                    Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children:
                      <Widget>[
                        Icon(
                          Icons
                              .storefront_outlined,
                          color:
                          Colors.white30,
                          size:
                          56,
                        ),
                        SizedBox(
                          height:
                          12,
                        ),
                        Text(
                          'No products listed yet.',
                          style:
                          TextStyle(
                            color:
                            Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding:
                  const EdgeInsets.symmetric(
                    vertical:
                    8,
                  ),
                  itemCount:
                  docs.length,
                  separatorBuilder:
                      (
                      _,
                      _,
                      ) =>
                  const Divider(
                    height:
                    1,
                    color:
                    Colors.white10,
                  ),
                  itemBuilder:
                      (
                      BuildContext
                      context,
                      int index,
                      ) {
                    final product =
                    docs[index]
                        .data();

                    final String
                    title =
                    (product['title'] ??
                        product['name'] ??
                        'Product')
                        .toString();

                    final String
                    description =
                    (product['description'] ??
                        '')
                        .toString();

                    final String
                    imageUrl =
                    (product['imageUrl'] ??
                        '')
                        .toString();

                    final dynamic
                    rawPrice =
                    product['price'];

                    final String
                    price =
                    rawPrice ==
                        null
                        ? ''
                        : rawPrice
                        .toString();

                    return ListTile(
                      contentPadding:
                      const EdgeInsets.symmetric(
                        horizontal:
                        16,
                        vertical:
                        8,
                      ),
                      leading:
                      ClipRRect(
                        borderRadius:
                        BorderRadius.circular(
                          13,
                        ),
                        child:
                        Container(
                          width:
                          66,
                          height:
                          66,
                          color:
                          Colors.white10,
                          child:
                          imageUrl
                              .trim()
                              .isNotEmpty
                              ? Image.network(
                            imageUrl,
                            fit:
                            BoxFit.cover,
                          )
                              : const Icon(
                            Icons
                                .storefront_rounded,
                            color:
                            _blue,
                          ),
                        ),
                      ),
                      title:
                      Text(
                        title,
                        maxLines:
                        1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color:
                          Colors.white,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                      subtitle:
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children:
                        <Widget>[
                          if (description
                              .trim()
                              .isNotEmpty)
                            Text(
                              description,
                              maxLines:
                              1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style:
                              const TextStyle(
                                color:
                                Colors.white54,
                              ),
                            ),

                          if (price
                              .isNotEmpty)
                            Text(
                              'EGP $price',
                              style:
                              const TextStyle(
                                color:
                                _blue,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                        ],
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
}