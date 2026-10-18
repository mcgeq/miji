import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/gtd/domain/plan_color.dart';

/// 颜色值对象的职责只有三件：解析不抛、序列化稳定、能按 HSV 造出来。
void main() {
  test('解析：#RRGGBB / 不带 # / 小写都认，坏值给 null 不抛', () {
    expect(PlanColor.tryParse('#0EA5E9')?.hex, '#0EA5E9');
    expect(PlanColor.tryParse('0EA5E9')?.hex, '#0EA5E9');
    expect(PlanColor.tryParse('#0ea5e9')?.hex, '#0EA5E9');
    expect(PlanColor.tryParse(' #0EA5E9 ')?.hex, '#0EA5E9');
    expect(PlanColor.tryParse('#0EA5'), isNull);
    expect(PlanColor.tryParse('#GGGGGG'), isNull);
    expect(PlanColor.tryParse(''), isNull);
    expect(PlanColor.tryParse(null), isNull);
  });

  test('parseOr：坏值落到给定的兜底', () {
    expect(
      PlanColor.parseOr('乱写', defaultSeedPlanColor),
      defaultSeedPlanColor,
    );
    expect(PlanColor.parseOr('#123456', defaultSeedPlanColor).hex, '#123456');
  });

  test('序列化再解析回来是同一个颜色', () {
    final color = PlanColor.tryParse('#84CC16')!;
    expect(PlanColor.tryParse(color.hex), color);
    // 值相等：颜色对象要能直接比，列表里做「选中」判断靠它。
    expect(color, PlanColor.rgb(0x84CC16));
    expect(color.hashCode, PlanColor.rgb(0x84CC16).hashCode);
  });

  test('HSV 构造：色相绕回、通道夹紧', () {
    final red = PlanColor.fromHsv(hue: 0, saturation: 1, value: 1);
    expect(red.hex, '#FF0000');

    // 720 度 = 0 度。
    expect(PlanColor.fromHsv(hue: 720, saturation: 1, value: 1).hex, '#FF0000');
    // 越界的饱和度 / 明度被夹到 [0,1]。
    expect(
      PlanColor.fromHsv(hue: 0, saturation: 5, value: 5).hex,
      '#FF0000',
    );
    // 全黑、全白。
    expect(PlanColor.fromHsv(hue: 200, saturation: 0, value: 1).hex, '#FFFFFF');
    expect(PlanColor.fromHsv(hue: 200, saturation: 1, value: 0).hex, '#000000');
  });

  test('HSV 往返：解析后取 hsv 再构造，颜色不变', () {
    for (final hex in ['#0EA5E9', '#8B5CF6', '#EF4444', '#10B981']) {
      final color = PlanColor.tryParse(hex)!;
      final hsv = color.hsv;
      expect(
        PlanColor.fromHsv(
          hue: hsv.hue,
          saturation: hsv.saturation,
          value: hsv.value,
        ).hex,
        hex,
      );
    }
  });

  test('onColor：浅色上给深字、深色上给白字', () {
    expect(PlanColor.tryParse('#FFFFFF')!.onColor.toARGB32(), 0xFF1B1A17);
    expect(PlanColor.tryParse('#000000')!.onColor.toARGB32(), 0xFFFFFFFF);
    expect(PlanColor.tryParse('#FDE68A')!.onColor.toARGB32(), 0xFF1B1A17);
    expect(PlanColor.tryParse('#1E3A8A')!.onColor.toARGB32(), 0xFFFFFFFF);
  });
}
