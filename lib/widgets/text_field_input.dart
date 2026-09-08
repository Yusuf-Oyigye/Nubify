import 'package:flutter/material.dart';

//===================================================
// TEXT FIELD INPUT
//===================================================

class TextFieldInput
    extends StatefulWidget {
  const TextFieldInput({
    super.key,
    required this.textEditingController,
    this.isPass = false,
    required this.hintText,
    required this.textInputType,
    this.prefixIcon,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController
  textEditingController;

  final bool isPass;

  final String hintText;

  final TextInputType
  textInputType;

  final IconData? prefixIcon;

  final TextInputAction?
  textInputAction;

  final ValueChanged<String>?
  onSubmitted;

  @override
  State<TextFieldInput>
  createState() =>
      _TextFieldInputState();
}

//===================================================
// TEXT FIELD INPUT STATE
//===================================================

class _TextFieldInputState
    extends State<TextFieldInput> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();

    _obscureText =
        widget.isPass;
  }

  @override
  void didUpdateWidget(
      covariant TextFieldInput
      oldWidget,
      ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.isPass !=
        widget.isPass) {
      _obscureText =
          widget.isPass;
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final OutlineInputBorder
    inputBorder =
    OutlineInputBorder(
      borderSide:
      Divider.createBorderSide(
        context,
      ),
      borderRadius:
      BorderRadius.circular(
        10,
      ),
    );

    return TextField(
      controller:
      widget
          .textEditingController,

      keyboardType:
      widget.textInputType,

      obscureText:
      widget.isPass &&
          _obscureText,

      textInputAction:
      widget.textInputAction,

      onSubmitted:
      widget.onSubmitted,

      decoration:
      InputDecoration(
        hintText:
        widget.hintText,

        prefixIcon:
        widget.prefixIcon ==
            null
            ? null
            : Icon(
          widget
              .prefixIcon,
          color:
          const Color(
            0xFF29B6F6,
          ),
        ),

        suffixIcon:
        widget.isPass
            ? IconButton(
          onPressed:
              () {
            setState(
                  () {
                _obscureText =
                !_obscureText;
              },
            );
          },
          icon:
          Icon(
            _obscureText
                ? Icons
                .visibility_off_outlined
                : Icons
                .visibility_outlined,
          ),
        )
            : null,

        border:
        inputBorder,

        focusedBorder:
        inputBorder.copyWith(
          borderSide:
          const BorderSide(
            color:
            Color(
              0xFF29B6F6,
            ),
            width:
            1.5,
          ),
        ),

        enabledBorder:
        inputBorder,

        filled:
        true,

        contentPadding:
        const EdgeInsets
            .symmetric(
          horizontal:
          12,
          vertical:
          14,
        ),
      ),
    );
  }
}