import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/chat_media_service.dart';
import '../services/group_chat_service.dart';
import 'group_chat_screen.dart';

//===============================
// CREATE GROUP SCREEN
//===============================

class CreateGroupScreen
    extends StatefulWidget {
  const CreateGroupScreen({
    super.key,
  });

  @override
  State<CreateGroupScreen>
  createState() =>
      _CreateGroupScreenState();
}

//===============================
// CREATE GROUP STATE
//===============================

class _CreateGroupScreenState
    extends State<CreateGroupScreen> {
  static const Color _blue =
  Color(
    0xFF29B6F6,
  );

  final FirebaseFirestore
  _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth
  _auth =
      FirebaseAuth.instance;

  final GroupChatService
  _groupService =
  GroupChatService();

  final ChatMediaService
  _mediaService =
  ChatMediaService();

  final ImagePicker
  _imagePicker =
  ImagePicker();

  final TextEditingController
  _nameController =
  TextEditingController();

  final TextEditingController
  _descriptionController =
  TextEditingController();

  final TextEditingController
  _searchController =
  TextEditingController();

  final Set<String>
  _selectedIds =
  <String>{};

  final Set<String>
  _priorityIds =
  <String>{};

  final Set<String>
  _blockedIds =
  <String>{};

  String _search =
      '';

  XFile? _photo;

  bool _loadingLists =
  true;

  bool _creating =
  false;

  //===============================
  // INIT
  //===============================

  @override
  void initState() {
    super.initState();

    _loadLists();

    _searchController.addListener(
          () {
        if (!mounted) {
          return;
        }

        setState(() {
          _search =
              _searchController.text
                  .trim()
                  .toLowerCase();
        });
      },
    );
  }

  //===============================
  // LOAD USER LISTS
  //===============================

  Future<void> _loadLists() async {
    final String? uid =
        _auth.currentUser?.uid;

    if (uid == null) {
      return;
    }

    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      userSnapshot =
      await _firestore
          .collection(
        'users',
      )
          .doc(
        uid,
      )
          .get();

      final Map<String, dynamic>
      data =
          userSnapshot.data() ??
              <String, dynamic>{};

      final List<String> followers =
      data['followers'] is List
          ? (data['followers'] as List)
          .map(
            (dynamic value) =>
            value.toString(),
      )
          .toList()
          : <String>[];

      final List<String> following =
      data['following'] is List
          ? (data['following'] as List)
          .map(
            (dynamic value) =>
            value.toString(),
      )
          .toList()
          : <String>[];

      _priorityIds
        ..clear()
        ..addAll(
          followers,
        )
        ..addAll(
          following,
        );

      final QuerySnapshot<
          Map<String, dynamic>>
      blocked =
      await _firestore
          .collection(
        'users',
      )
          .doc(
        uid,
      )
          .collection(
        'blockedUsers',
      )
          .get();

      _blockedIds
        ..clear()
        ..addAll(
          blocked.docs.map(
                (
                QueryDocumentSnapshot<
                    Map<String, dynamic>>
                document,
                ) =>
            document.id,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _loadingLists =
          false;
        });
      }
    }
  }

  //===============================
  // PICK PHOTO
  //===============================

  Future<void> _pickPhoto() async {
    final XFile? photo =
    await _imagePicker.pickImage(
      source:
      ImageSource.gallery,
      imageQuality:
      88,
      maxWidth:
      1200,
    );

    if (photo == null) {
      return;
    }

    setState(() {
      _photo =
          photo;
    });
  }

  //===============================
  // USER MATCH
  //===============================

  bool _matches(
      Map<String, dynamic> user,
      ) {
    if (_search.isEmpty) {
      return true;
    }

    final String fullName =
    (user['fullName'] ?? '')
        .toString()
        .toLowerCase();

    final String username =
    (user['username'] ?? '')
        .toString()
        .toLowerCase();

    return fullName.contains(
      _search,
    ) ||
        username.contains(
          _search,
        );
  }

  //===============================
  // TOGGLE USER
  //===============================

  void _toggleUser(
      String uid,
      ) {
    setState(() {
      if (_selectedIds.contains(
        uid,
      )) {
        _selectedIds.remove(
          uid,
        );
      } else {
        _selectedIds.add(
          uid,
        );
      }
    });
  }

  //===============================
  // CREATE GROUP
  //===============================

  Future<void> _createGroup() async {
    final String name =
    _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Enter a group name.',
      );

      return;
    }

    if (_selectedIds.isEmpty) {
      _showMessage(
        'Add at least one member.',
      );

      return;
    }

    if (_creating) {
      return;
    }

    setState(() {
      _creating =
      true;
    });

    try {
      //===============================
      // CREATE FIRESTORE GROUP
      //===============================

      final String groupId =
      await _groupService.createGroup(
        name:
        name,
        description:
        _descriptionController.text
            .trim(),
        selectedMemberIds:
        _selectedIds.toList(),
      );

      //===============================
      // UPLOAD GROUP PHOTO
      //===============================

      if (_photo != null) {
        final String photoUrl =
        await _mediaService.uploadGroupPhoto(
          groupId:
          groupId,
          filePath:
          _photo!.path,
        );

        await _groupService.updateGroupInfo(
          groupId:
          groupId,
          photoUrl:
          photoUrl,
        );
      }

      if (!mounted) {
        return;
      }

      //===============================
      // OPEN GROUP
      //===============================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
              GroupChatScreen(
                groupId:
                groupId,
              ),
        ),
      );
    } catch (error) {
      _showMessage(
        error
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _creating =
          false;
        });
      }
    }
  }

  //===============================
  // MESSAGE
  //===============================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(
          message,
        ),
      ),
    );
  }

  //===============================
  // SELECTED USERS
  //===============================

  Widget _selectedUsersBar(
      List<QueryDocumentSnapshot<
          Map<String, dynamic>>>
      users,
      ) {
    final List<QueryDocumentSnapshot<
        Map<String, dynamic>>>
    selected =
    users
        .where(
          (
          QueryDocumentSnapshot<
              Map<String, dynamic>>
          document,
          ) =>
          _selectedIds.contains(
            document.id,
          ),
    )
        .toList();

    if (selected.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height:
      92,
      child:
      ListView.builder(
        scrollDirection:
        Axis.horizontal,
        padding:
        const EdgeInsets.symmetric(
          horizontal:
          12,
        ),
        itemCount:
        selected.length,
        itemBuilder:
            (
            BuildContext context,
            int index,
            ) {
          final QueryDocumentSnapshot<
              Map<String, dynamic>>
          document =
          selected[index];

          final Map<String, dynamic>
          data =
          document.data();

          final String fullName =
          (data['fullName'] ?? '')
              .toString();

          final String username =
          (data['username'] ?? '')
              .toString();

          final String photoUrl =
          (data['photoUrl'] ?? '')
              .toString();

          final String displayName =
          fullName.trim().isNotEmpty
              ? fullName
              : username;

          return Padding(
            padding:
            const EdgeInsets.only(
              right:
              10,
            ),
            child:
            SizedBox(
              width:
              66,
              child:
              Column(
                children:
                <Widget>[
                  Stack(
                    clipBehavior:
                    Clip.none,
                    children:
                    <Widget>[
                      CircleAvatar(
                        radius:
                        25,
                        backgroundColor:
                        Colors.white10,
                        backgroundImage:
                        photoUrl.trim().isNotEmpty
                            ? NetworkImage(
                          photoUrl,
                        )
                            : null,
                        child:
                        photoUrl.trim().isEmpty
                            ? const Icon(
                          Icons.person_rounded,
                        )
                            : null,
                      ),

                      Positioned(
                        right:
                        -5,
                        top:
                        -5,
                        child:
                        GestureDetector(
                          onTap:
                              () {
                            _toggleUser(
                              document.id,
                            );
                          },
                          child:
                          Container(
                            width:
                            21,
                            height:
                            21,
                            decoration:
                            const BoxDecoration(
                              color:
                              Colors.redAccent,
                              shape:
                              BoxShape.circle,
                            ),
                            child:
                            const Icon(
                              Icons.close_rounded,
                              color:
                              Colors.white,
                              size:
                              14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                    5,
                  ),

                  Text(
                    displayName,
                    maxLines:
                    1,
                    overflow:
                    TextOverflow.ellipsis,
                    textAlign:
                    TextAlign.center,
                    style:
                    const TextStyle(
                      color:
                      Colors.white70,
                      fontSize:
                      10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  //===============================
  // USER TILE
  //===============================

  Widget _userTile(
      QueryDocumentSnapshot<
          Map<String, dynamic>>
      document,
      ) {
    final Map<String, dynamic>
    data =
    document.data();

    final String fullName =
    (data['fullName'] ?? '')
        .toString();

    final String username =
    (data['username'] ?? '')
        .toString();

    final String photoUrl =
    (data['photoUrl'] ?? '')
        .toString();

    final String displayName =
    fullName.trim().isNotEmpty
        ? fullName
        : username.trim().isNotEmpty
        ? username
        : 'Nubify user';

    final bool selected =
    _selectedIds.contains(
      document.id,
    );

    return ListTile(
      onTap:
          () {
        _toggleUser(
          document.id,
        );
      },
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal:
        16,
        vertical:
        2,
      ),
      leading:
      CircleAvatar(
        radius:
        25,
        backgroundColor:
        Colors.white10,
        backgroundImage:
        photoUrl.trim().isNotEmpty
            ? NetworkImage(
          photoUrl,
        )
            : null,
        child:
        photoUrl.trim().isEmpty
            ? const Icon(
          Icons.person_rounded,
        )
            : null,
      ),
      title:
      Text(
        displayName,
        style:
        const TextStyle(
          color:
          Colors.white,
          fontWeight:
          FontWeight.w700,
        ),
      ),
      subtitle:
      username.trim().isNotEmpty
          ? Text(
        '@$username',
        style:
        const TextStyle(
          color:
          Colors.white54,
        ),
      )
          : null,
      trailing:
      AnimatedContainer(
        duration:
        const Duration(
          milliseconds:
          180,
        ),
        width:
        26,
        height:
        26,
        decoration:
        BoxDecoration(
          color:
          selected
              ? _blue
              : Colors.transparent,
          shape:
          BoxShape.circle,
          border:
          Border.all(
            color:
            selected
                ? _blue
                : Colors.white30,
            width:
            2,
          ),
        ),
        child:
        selected
            ? const Icon(
          Icons.check_rounded,
          color:
          Colors.white,
          size:
          17,
        )
            : null,
      ),
    );
  }

  //===============================
  // USER SECTION
  //===============================

  Widget _section({
    required String title,
    required List<
        QueryDocumentSnapshot<
            Map<String, dynamic>>>
    users,
  }) {
    if (users.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children:
      <Widget>[
        Padding(
          padding:
          const EdgeInsets.fromLTRB(
            16,
            14,
            16,
            5,
          ),
          child:
          Text(
            title,
            style:
            const TextStyle(
              color:
              _blue,
              fontSize:
              12,
              fontWeight:
              FontWeight.w800,
            ),
          ),
        ),

        ...users.map(
          _userTile,
        ),
      ],
    );
  }

  //===============================
  // BUILD
  //===============================

  @override
  Widget build(
      BuildContext context,
      ) {
    final String? currentUid =
        _auth.currentUser?.uid;

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
          'Create group',
          style:
          TextStyle(
            fontWeight:
            FontWeight.w800,
          ),
        ),
        actions:
        <Widget>[
          TextButton(
            onPressed:
            _creating
                ? null
                : _createGroup,
            child:
            _creating
                ? const SizedBox(
              width:
              19,
              height:
              19,
              child:
              CircularProgressIndicator(
                strokeWidth:
                2,
                color:
                _blue,
              ),
            )
                : const Text(
              'Create',
              style:
              TextStyle(
                color:
                _blue,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body:
      Column(
        children:
        <Widget>[
          //===============================
          // GROUP DETAILS
          //===============================

          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              7,
            ),
            child:
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children:
              <Widget>[
                GestureDetector(
                  onTap:
                  _pickPhoto,
                  child:
                  Stack(
                    children:
                    <Widget>[
                      CircleAvatar(
                        radius:
                        34,
                        backgroundColor:
                        const Color(
                          0xFF17252E,
                        ),
                        foregroundImage:
                        _photo != null
                            ? FileImage(
                          // ignore: avoid_dynamic_calls
                          _photoFile(),
                        )
                            : null,
                        child:
                        _photo == null
                            ? const Icon(
                          Icons.groups_rounded,
                          color:
                          _blue,
                          size:
                          33,
                        )
                            : null,
                      ),

                      Positioned(
                        right:
                        0,
                        bottom:
                        0,
                        child:
                        Container(
                          width:
                          24,
                          height:
                          24,
                          decoration:
                          const BoxDecoration(
                            color:
                            _blue,
                            shape:
                            BoxShape.circle,
                          ),
                          child:
                          const Icon(
                            Icons.camera_alt_rounded,
                            color:
                            Colors.white,
                            size:
                            14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width:
                  13,
                ),

                Expanded(
                  child:
                  Column(
                    children:
                    <Widget>[
                      TextField(
                        controller:
                        _nameController,
                        maxLength:
                        80,
                        decoration:
                        const InputDecoration(
                          hintText:
                          'Group name',
                          counterText:
                          '',
                        ),
                      ),

                      TextField(
                        controller:
                        _descriptionController,
                        maxLength:
                        300,
                        maxLines:
                        2,
                        decoration:
                        const InputDecoration(
                          hintText:
                          'Group description (optional)',
                          counterText:
                          '',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          //===============================
          // SEARCH
          //===============================

          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              14,
              5,
              14,
              8,
            ),
            child:
            TextField(
              controller:
              _searchController,
              decoration:
              InputDecoration(
                hintText:
                'Search users',
                prefixIcon:
                const Icon(
                  Icons.search_rounded,
                ),
                filled:
                true,
                fillColor:
                const Color(
                  0xFF192126,
                ),
                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    25,
                  ),
                  borderSide:
                  BorderSide.none,
                ),
              ),
            ),
          ),

          if (_loadingLists)
            const Expanded(
              child:
              Center(
                child:
                CircularProgressIndicator(
                  color:
                  _blue,
                ),
              ),
            )
          else
            Expanded(
              child:
              StreamBuilder<
                  QuerySnapshot<
                      Map<String, dynamic>>>(
                stream:
                _firestore
                    .collection(
                  'users',
                )
                    .snapshots(),
                builder:
                    (
                    BuildContext context,
                    AsyncSnapshot<
                        QuerySnapshot<
                            Map<String, dynamic>>>
                    snapshot,
                    ) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child:
                      CircularProgressIndicator(
                        color:
                        _blue,
                      ),
                    );
                  }

                  final List<
                      QueryDocumentSnapshot<
                          Map<String, dynamic>>>
                  users =
                  snapshot.data!.docs
                      .where(
                        (
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        document,
                        ) {
                      if (document.id ==
                          currentUid) {
                        return false;
                      }

                      if (_blockedIds.contains(
                        document.id,
                      )) {
                        return false;
                      }

                      return _matches(
                        document.data(),
                      );
                    },
                  )
                      .toList();

                  users.sort(
                        (
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        a,
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        b,
                        ) {
                      final String aName =
                      (a.data()['fullName'] ??
                          a.data()['username'] ??
                          '')
                          .toString()
                          .toLowerCase();

                      final String bName =
                      (b.data()['fullName'] ??
                          b.data()['username'] ??
                          '')
                          .toString()
                          .toLowerCase();

                      return aName.compareTo(
                        bName,
                      );
                    },
                  );

                  final List<
                      QueryDocumentSnapshot<
                          Map<String, dynamic>>>
                  priority =
                  users
                      .where(
                        (
                        document,
                        ) =>
                        _priorityIds.contains(
                          document.id,
                        ),
                  )
                      .toList();

                  final List<
                      QueryDocumentSnapshot<
                          Map<String, dynamic>>>
                  others =
                  users
                      .where(
                        (
                        document,
                        ) =>
                    !_priorityIds.contains(
                      document.id,
                    ),
                  )
                      .toList();

                  return Column(
                    children:
                    <Widget>[
                      _selectedUsersBar(
                        users,
                      ),

                      Expanded(
                        child:
                        ListView(
                          children:
                          <Widget>[
                            _section(
                              title:
                              'People you follow / who follow you',
                              users:
                              priority,
                            ),

                            if (priority.isNotEmpty &&
                                others.isNotEmpty)
                              const Divider(
                                color:
                                Colors.white10,
                              ),

                            _section(
                              title:
                              'Other Nubify users',
                              users:
                              others,
                            ),

                            const SizedBox(
                              height:
                              30,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  //===============================
  // PHOTO FILE
  //===============================
  File _photoFile() {
    return File(
      _photo!.path,
    );
  }

  //===============================
  // DISPOSE
  //===============================

  @override
  void dispose() {
    _nameController.dispose();

    _descriptionController.dispose();

    _searchController.dispose();

    super.dispose();
  }
}