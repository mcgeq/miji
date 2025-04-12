// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           mguid.dart
// Description:    About UUID
// Create   Date:  2025-04-12 10:58:22
// Last Modified:  2025-04-12 10:58:29
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

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
