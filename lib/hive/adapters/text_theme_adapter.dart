import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class TextThemeAdapter extends TypeAdapter<TextTheme> {
  @override
  final int typeId = 1;

  @override
  TextTheme read(BinaryReader reader) {
    final Map<String, dynamic> map = reader.readMap() as Map<String, dynamic>;
    return TextTheme(
      bodyMedium: TextStyle(
        color: Color(int.parse(map['bodyColor'] ?? '0xFF000000')),
        fontSize: map['bodySize']?.toDouble() ?? 16.0,
      ),
      titleLarge: TextStyle(
        color: Color(int.parse(map['titleColor'] ?? '0xFF000000')),
        fontSize: map['titleSize']?.toDouble() ?? 24.0,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  void write(BinaryWriter writer, TextTheme obj) {
    writer.writeMap({
      'bodyColor':
          (obj.bodyMedium?.color)?.toARGB32().toString() ?? '0xFF000000',
      'bodySize': obj.bodyMedium?.fontSize,
      'titleColor':
          (obj.titleLarge?.color)?.toARGB32().toString() ?? '0xFF000000',
      'titleSize': obj.titleLarge?.fontSize,
    });
  }
}