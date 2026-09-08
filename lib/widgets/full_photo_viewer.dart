import 'package:flutter/material.dart';

//===============================
// FULL PHOTO VIEWER
//===============================

class FullPhotoViewer
    extends StatelessWidget {
  const FullPhotoViewer({
    super.key,
    required this.title,
    required this.photoUrl,
    this.group = false,
  });

  final String title;

  final String photoUrl;

  final bool group;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      Colors.black,

      appBar:
      AppBar(
        backgroundColor:
        Colors.black,

        foregroundColor:
        Colors.white,

        title:
        Text(
          title,
        ),
      ),

      body:
      Center(
        child:
        photoUrl.trim().isEmpty
            ? Icon(
          group
              ? Icons.groups_rounded
              : Icons.person_rounded,

          color:
          Colors.white38,

          size:
          110,
        )
            : InteractiveViewer(
          minScale:
          0.5,

          maxScale:
          5,

          child:
          Image.network(
            photoUrl,

            fit:
            BoxFit.contain,

            errorBuilder:
                (
                _,
                __,
                ___,
                ) =>
            const Icon(
              Icons.broken_image_outlined,

              color:
              Colors.white54,

              size:
              90,
            ),
          ),
        ),
      ),
    );
  }
}