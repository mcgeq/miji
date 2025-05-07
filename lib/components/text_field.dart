import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class MijiTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color? fillColor;
  final double borderRadius;
  final EdgeInsets padding;
  final bool enabled;
  final String? semanticsLabel;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final TextStyle? errorStyle;
  final Color errorBorderColor;
  final double errorBorderWidth;
  final List<TextInputFormatter>? inputFormatters;

  const MijiTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixWidget,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.borderColor = Colors.grey,
    this.focusedBorderColor = Colors.blue,
    this.fillColor,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    this.enabled = true,
    this.semanticsLabel,
    this.labelStyle,
    this.hintStyle,
    this.errorStyle,
    this.errorBorderColor = Colors.red,
    this.errorBorderWidth = 1.0,
    this.inputFormatters,
  });

  @override
  State<StatefulWidget> createState() => _MijiTextFielddState();
}

class _MijiTextFielddState extends State<MijiTextField> {
  late FocusNode _focusNode;
  bool _isObscured = true;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
    _focusNode =
        FocusNode()..addListener(() {
          if (widget.prefixIcon != null || widget.obscureText) {
            setState(() {});
          }
        });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  InputDecoration _buildDecoration(BuildContext context) {
    final isFocused = _focusNode.hasFocus;
    return InputDecoration(
      labelText: widget.labelText,
      labelStyle: widget.labelStyle,
      hintText: widget.hintText,
      hintStyle: widget.hintStyle,
      errorStyle:
          widget.errorStyle ?? TextStyle(color: widget.errorBorderColor),
      prefixIcon:
          widget.prefixIcon != null
              ? Icon(
                widget.prefixIcon,
                color:
                    isFocused ? widget.focusedBorderColor : widget.borderColor,
              )
              : null,
      suffixIcon:
          widget.suffixWidget ??
          (widget.obscureText
              ? IconButton(
                icon: Icon(
                  _isObscured ? Icons.visibility : Icons.visibility_off,
                  color:
                      isFocused
                          ? widget.focusedBorderColor
                          : widget.borderColor,
                ),
                onPressed: () {
                  setState(() {
                    _isObscured = !_isObscured;
                  });
                },
              )
              : null),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(color: widget.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(color: widget.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(color: widget.focusedBorderColor, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(
          color: widget.errorBorderColor,
          width: widget.errorBorderWidth,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(
          color: widget.errorBorderColor,
          width: widget.errorBorderWidth,
        ),
      ),
      filled: true,
      fillColor: widget.fillColor ?? Theme.of(context).colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: MergeSemantics(
        child: Semantics(
          label: widget.semanticsLabel ?? widget.labelText ?? widget.hintText,
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.obscureText ? _isObscured : false,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            onChanged: widget.onChanged,
            focusNode: _focusNode,
            enabled: widget.enabled,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: widget.inputFormatters,
            decoration: _buildDecoration(context),
            style: const TextStyle(fontSize: 16.0),
          ),
        ),
      ),
    );
  }
}
