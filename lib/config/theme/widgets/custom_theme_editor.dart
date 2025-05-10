import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/config/theme/bloc/theme_bloc.dart';
import 'package:miji/config/theme/bloc/theme_event.dart';
import 'package:miji/config/theme/models/custom_theme_config.dart';

class CustomThemeEditor extends StatefulWidget {
  const CustomThemeEditor({super.key});
  @override
  CustomThemeEditorState createState() => CustomThemeEditorState();
}

class CustomThemeEditorState extends State<CustomThemeEditor> {
  late CustomThemeConfig _config;
  late Color _primaryColor;
  late Color _backgroundColor;

  @override
  void initState() {
    super.initState();
    final state = context.read<ThemeBloc>().state;
    _config =
        state.customThemeConfig ??
        CustomThemeConfig(
          primaryColor: AppColors.primaryColor,
          backgroundColor: AppColors.backgroundColor,
          textTheme: ThemeData.light().textTheme,
        );
    _primaryColor = _config.primaryColor;
    _backgroundColor = _config.backgroundColor;
  }

  void _updatePrimaryColor(Color color) {
    setState(() {
      _primaryColor = color;
      _config = _config.copyWith(primaryColor: color);
    });
  }

  void _updateBackgroundColor(Color color) {
    setState(() {
      _backgroundColor = color;
      _config = _config.copyWith(backgroundColor: color);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Primary Color'),
        ElevatedButton(
          onPressed:
              () =>
                  _showColorPicker(context, _primaryColor, _updatePrimaryColor),
          child: const Text('Choose Primary Color'),
        ),
        const SizedBox(height: 16),
        const Text('Background Color'),
        ElevatedButton(
          onPressed:
              () => _showColorPicker(
                context,
                _backgroundColor,
                _updateBackgroundColor,
              ),
          child: const Text('Choose Background Color'),
        ),
        ElevatedButton(
          onPressed: () {
            context.read<ThemeBloc>().add(UpdateCustomTheme(config: _config));
          },
          child: const Text('Save Custom Theme'),
        ),
      ],
    );
  }

  void _showColorPicker(
    BuildContext context,
    Color initialColor,
    Function(Color) onColorChange,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pick a color'),
            content: SingleChildScrollView(
              child: BlockPicker(
                pickerColor: initialColor,
                onColorChanged: onColorChange,
              ),
            ),
            actions: [
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }
}