import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class MgUUID {
  MgUUID._(); // 私有构造函数，防止实例化

  static final Uuid _uuid = const Uuid();

  static String generate() {
    // 获取当前时间，格式 yyyyMMddHHmmssSSS
    final String timestamp = DateFormat(
      'yyyyMMddHHmmssSSS',
    ).format(DateTime.now());

    // 生成一段随机字符串（去掉 `-` 符号）
    final String randomStr = _uuid.v4().replaceAll('-', '');

    // 取前 15 位，使总长度为 32
    return timestamp + randomStr.substring(0, 15);
  }
}
