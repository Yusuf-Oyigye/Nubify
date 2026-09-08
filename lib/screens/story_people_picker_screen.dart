import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/story.dart';

class StoryPeoplePickerScreen
    extends StatefulWidget {
  const StoryPeoplePickerScreen({
    super.key,
    required this.title,
    this.initialSelected =
    const <StoryPerson>[],
    this.maxSelection,
  });

  final String title;

  final List<StoryPerson>
  initialSelected;

  final int? maxSelection;

  @override
  State<
      StoryPeoplePickerScreen>
  createState() =>
      _StoryPeoplePickerScreenState();
}

class _StoryPeoplePickerScreenState
    extends State<
        StoryPeoplePickerScreen> {
  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final TextEditingController
  _searchController =
  TextEditingController();

  bool _isLoading =
  true;

  String _search =
      '';

  List<StoryPerson> _people =
  <StoryPerson>[];

  final Map<String, StoryPerson>
  _selected =
  <String, StoryPerson>{};

  final Set<String>
  _connections =
  <String>{};

  //===========================================================
  // INIT
  //===========================================================

  @override
  void initState() {
    super.initState();

    for (final StoryPerson person
    in widget
        .initialSelected) {
      _selected[person.uid] =
          person;
    }

    _loadPeople();
  }

  //===========================================================
  // LOAD PEOPLE
  //===========================================================

  Future<void>
  _loadPeople() async {
    final String? currentUid =
        _auth
            .currentUser
            ?.uid;

    if (currentUid == null) {
      if (mounted) {
        setState(() {
          _isLoading =
          false;
        });
      }

      return;
    }

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      meSnapshot =
      await _firestore
          .collection(
        'users',
      )
          .doc(
        currentUid,
      )
          .get();

      final Map<String, dynamic>
      meData =
          meSnapshot.data() ??
              <String,
                  dynamic>{};

      final List followers =
      meData['followers']
      is List
          ? meData['followers']
      as List
          : const [];

      final List following =
      meData['following']
      is List
          ? meData['following']
      as List
          : const [];

      _connections
        ..addAll(
          followers.map(
                (item) =>
                item.toString(),
          ),
        )
        ..addAll(
          following.map(
                (item) =>
                item.toString(),
          ),
        );

      final QuerySnapshot<
          Map<String, dynamic>>
      snapshot =
      await _firestore
          .collection(
        'users',
      )
          .limit(
        300,
      )
          .get();

      final List<StoryPerson>
      people =
      snapshot.docs
          .where(
            (doc) =>
        doc.id !=
            currentUid,
      )
          .map(
            (doc) =>
            StoryPerson
                .fromMap(
              doc.data(),
              fallbackUid:
              doc.id,
            ),
      )
          .toList();

      people.sort(
            (
            StoryPerson a,
            StoryPerson b,
            ) {
          final bool aConnected =
          _connections
              .contains(
            a.uid,
          );

          final bool bConnected =
          _connections
              .contains(
            b.uid,
          );

          if (aConnected !=
              bConnected) {
            return aConnected
                ? -1
                : 1;
          }

          return a.displayName
              .toLowerCase()
              .compareTo(
            b.displayName
                .toLowerCase(),
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _people =
            people;

        _isLoading =
        false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading =
        false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
          Text(
            'Unable to load people: $error',
          ),
        ),
      );
    }
  }

  //===========================================================
  // FILTERED PEOPLE
  //===========================================================

  List<StoryPerson>
  get _filteredPeople {
    final String query =
    _search
        .trim()
        .toLowerCase();

    if (query.isEmpty) {
      return _people;
    }

    return _people.where(
          (
          StoryPerson person,
          ) {
        return person.username
            .toLowerCase()
            .contains(
          query,
        ) ||
            person.fullName
                .toLowerCase()
                .contains(
              query,
            );
      },
    ).toList();
  }

  //===========================================================
  // TOGGLE PERSON
  //===========================================================

  void _togglePerson(
      StoryPerson person,
      ) {
    final bool isSelected =
    _selected
        .containsKey(
      person.uid,
    );

    if (isSelected) {
      setState(() {
        _selected.remove(
          person.uid,
        );
      });

      return;
    }

    final int? maxSelection =
        widget.maxSelection;

    if (maxSelection != null &&
        _selected.length >=
            maxSelection) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
          Text(
            'You can select up to $maxSelection people.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _selected[person.uid] =
          person;
    });
  }

  //===========================================================
  // DONE
  //===========================================================

  void _done() {
    Navigator.pop(
      context,

      _selected.values
          .toList(),
    );
  }

  //===========================================================
  // BUILD
  //===========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar:
      AppBar(
        title:
        Text(
          widget.title,
        ),

        actions:
        <Widget>[
          TextButton(
            onPressed:
            _done,

            child:
            const Text(
              'Done',

              style:
              TextStyle(
                color:
                Color(
                  0xFF29B6F6,
                ),

                fontWeight:
                FontWeight
                    .bold,
              ),
            ),
          ),
        ],
      ),

      body:
      SafeArea(
        child:
        Column(
          children:
          <Widget>[
            //===================================================
            // SEARCH
            //===================================================

            Padding(
              padding:
              const EdgeInsets
                  .fromLTRB(
                14,
                10,
                14,
                8,
              ),

              child:
              TextField(
                controller:
                _searchController,

                onChanged:
                    (
                    String value,
                    ) {
                  setState(() {
                    _search =
                        value;
                  });
                },

                decoration:
                InputDecoration(
                  hintText:
                  'Search name or @username',

                  prefixIcon:
                  const Icon(
                    Icons.search,
                  ),

                  suffixIcon:
                  _search.isEmpty
                      ? null
                      : IconButton(
                    onPressed:
                        () {
                      _searchController
                          .clear();

                      setState(
                            () {
                          _search =
                          '';
                        },
                      );
                    },
                    icon:
                    const Icon(
                      Icons.close,
                    ),
                  ),

                  filled:
                  true,

                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),

                    borderSide:
                    BorderSide.none,
                  ),
                ),
              ),
            ),

            //===================================================
            // SELECTED COUNT
            //===================================================

            if (_selected
                .isNotEmpty)
              Padding(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal:
                  16,

                  vertical:
                  4,
                ),

                child:
                Align(
                  alignment:
                  Alignment
                      .centerLeft,

                  child:
                  Text(
                    '${_selected.length} selected',

                    style:
                    const TextStyle(
                      color:
                      Color(
                        0xFF29B6F6,
                      ),

                      fontWeight:
                      FontWeight
                          .w700,
                    ),
                  ),
                ),
              ),

            //===================================================
            // PEOPLE
            //===================================================

            Expanded(
              child:
              _isLoading
                  ? const Center(
                child:
                CircularProgressIndicator(
                  color:
                  Color(
                    0xFF29B6F6,
                  ),
                ),
              )
                  : _filteredPeople
                  .isEmpty
                  ? const Center(
                child:
                Text(
                  'No users found.',
                ),
              )
                  : ListView
                  .builder(
                itemCount:
                _filteredPeople
                    .length,

                itemBuilder:
                    (
                    BuildContext
                    context,
                    int index,
                    ) {
                  final StoryPerson
                  person =
                  _filteredPeople[
                  index];

                  final bool
                  selected =
                  _selected
                      .containsKey(
                    person.uid,
                  );

                  final bool
                  connected =
                  _connections
                      .contains(
                    person.uid,
                  );

                  return ListTile(
                    leading:
                    CircleAvatar(
                      backgroundImage:
                      person.photoUrl
                          .trim()
                          .isNotEmpty
                          ? NetworkImage(
                        person.photoUrl,
                      )
                          : null,

                      child:
                      person.photoUrl
                          .trim()
                          .isEmpty
                          ? const Icon(
                        Icons.person,
                      )
                          : null,
                    ),

                    title:
                    Row(
                      children:
                      <Widget>[
                        Flexible(
                          child:
                          Text(
                            person.displayName,
                            maxLines:
                            1,
                            overflow:
                            TextOverflow.ellipsis,
                          ),
                        ),
                        if (connected) ...<Widget>[
                          const SizedBox(
                            width:
                            6,
                          ),
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal:
                              7,
                              vertical:
                              2,
                            ),
                            decoration:
                            BoxDecoration(
                              color:
                              const Color(
                                0xFF29B6F6,
                              ).withOpacity(
                                0.12,
                              ),
                              borderRadius:
                              BorderRadius.circular(
                                20,
                              ),
                            ),
                            child:
                            const Text(
                              'Connected',
                              style:
                              TextStyle(
                                color:
                                Color(
                                  0xFF29B6F6,
                                ),
                                fontSize:
                                10,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    subtitle:
                    Text(
                      '@${person.username}',
                    ),

                    trailing:
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,

                      color:
                      selected
                          ? const Color(
                        0xFF29B6F6,
                      )
                          : Colors.grey,
                    ),

                    onTap:
                        () {
                      _togglePerson(
                        person,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  //===========================================================
  // DISPOSE
  //===========================================================

  @override
  void dispose() {
    _searchController
        .dispose();

    super.dispose();
  }
}