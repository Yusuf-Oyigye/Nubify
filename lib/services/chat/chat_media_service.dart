import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

//===============================
// CHAT MEDIA SERVICE
//===============================

class ChatMediaService {
  final FirebaseStorage
  _storage =
      FirebaseStorage.instance;

  final FirebaseAuth
  _auth =
      FirebaseAuth.instance;

  //===============================
  // CURRENT UID
  //===============================

  String? get currentUid =>
      _auth.currentUser?.uid;
  //===============================
// CONTENT TYPE
//===============================

  String _contentType(
      String path,
      ) {
    final String value =
    path.toLowerCase();

    if (value.endsWith(
      '.m4a',
    )) {
      return 'audio/mp4';
    }

    if (value.endsWith(
      '.mp3',
    )) {
      return 'audio/mpeg';
    }

    if (value.endsWith(
      '.wav',
    )) {
      return 'audio/wav';
    }

    if (value.endsWith(
      '.mp4',
    )) {
      return 'video/mp4';
    }

    if (value.endsWith(
      '.jpg',
    ) ||
        value.endsWith(
          '.jpeg',
        )) {
      return 'image/jpeg';
    }

    if (value.endsWith(
      '.png',
    )) {
      return 'image/png';
    }

    if (value.endsWith(
      '.webp',
    )) {
      return 'image/webp';
    }

    if (value.endsWith(
      '.pdf',
    )) {
      return 'application/pdf';
    }

    return 'application/octet-stream';
  }
  //===============================
  // UPLOAD XFILE
  //===============================

  Future<String> uploadXFile({
    required XFile file,
    required String folder,
  }) async {
    return uploadFilePath(
      filePath:
      file.path,

      folder:
      folder,
    );
  }

  //===============================
  // UPLOAD FILE PATH
  //===============================

  Future<String> uploadFilePath({
    required String filePath,
    required String folder,
  }) async {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final File file =
    File(
      filePath,
    );

    if (!await file.exists()) {
      throw Exception(
        'Selected file does not exist.',
      );
    }

    final String cleanFolder =
    folder
        .replaceAll(
      RegExp(
        r'[^a-zA-Z0-9_\-/]',
      ),
      '_',
    );

    final String originalName =
        file.path
            .split(
          Platform.pathSeparator,
        )
            .last;

    final String safeName =
    originalName
        .replaceAll(
      RegExp(
        r'[^a-zA-Z0-9._-]',
      ),
      '_',
    );

    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$safeName';

    final Reference reference =
    _storage
        .ref()
        .child(
      'chatMedia',
    )
        .child(
      uid,
    )
        .child(
      cleanFolder,
    )
        .child(
      fileName,
    );
    final UploadTask uploadTask =
    reference.putFile(
      file,

      SettableMetadata(
        contentType:
        _contentType(
          filePath,
        ),
      ),
    );

    final TaskSnapshot snapshot =
    await uploadTask;

    return snapshot.ref
        .getDownloadURL();
  }

  //===============================
  // DIRECT CHAT MEDIA
  //===============================

  Future<String>
  uploadDirectChatFile({
    required String otherUid,
    required String filePath,
  }) async {
    final List<String> ids =
    <String>[
      currentUid ?? '',
      otherUid,
    ]..sort();

    return uploadFilePath(
      filePath:
      filePath,

      folder:
      'direct/${ids.join('_')}',
    );
  }

  //===============================
  // GROUP CHAT MEDIA
  //===============================

  Future<String>
  uploadGroupChatFile({
    required String groupId,
    required String filePath,
  }) async {
    return uploadFilePath(
      filePath:
      filePath,

      folder:
      'groups/$groupId',
    );
  }

  //===============================
  // GROUP PHOTO
  //===============================

  Future<String>
  uploadGroupPhoto({
    required String groupId,
    required String filePath,
  }) async {
    final String? uid =
        currentUid;

    if (uid == null ||
        uid.isEmpty) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final File file =
    File(
      filePath,
    );

    final Reference reference =
    _storage
        .ref()
        .child(
      'groupPhotos',
    )
        .child(
      groupId,
    )
        .child(
      '${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final TaskSnapshot snapshot =
    await reference.putFile(
      file,
    );

    return snapshot.ref
        .getDownloadURL();
  }
}