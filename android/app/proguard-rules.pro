# R8 / ProGuard 规则（release 构建启用，用于压缩安装包）。
# Flutter 引擎与大部分插件自带 keep 规则；这里只补充未自带规则、使用反射的插件。

# ML Kit 靠「合并后 manifest 里的类名 + 反射调用无参构造」来实例化 ComponentRegistrar，
# 这一步 R8 的静态分析完全看不见。ML Kit 的 AAR 自带这么一条 consumer 规则：
#   -keep class * implements com.google.firebase.components.ComponentRegistrar
# ——它保证**类**不被裁掉，但对**成员**只字未提。于是 R8 观察到「没有任何字节码
# 调用这些注册器的无参构造」，就把构造器删了。本次 release 构建的 usage.txt
# （build/app/outputs/mapping/release/usage.txt）里确实躺着三行：
#   com.google.mlkit.common.internal.CommonComponentRegistrar:   public void <init>()
#   com.google.mlkit.vision.common.internal.VisionCommonRegistrar: public void <init>()
#   com.google.mlkit.vision.text.internal.TextRegistrar:          public void <init>()
# 运行时反射取不到构造器 → ML Kit 初始化失败 → TextRecognition.getClient() 抛异常。
# 症状很有欺骗性：**release 包静默失效、debug 包一切正常**（debug 不跑 R8）。
# 补上成员规格即可。这比 -keep class com.google.mlkit.** { *; } 精确得多——
# 后者会连带关掉整个 ML Kit 的裁剪与混淆，只为救一个构造器。
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }

# ML Kit 文字识别：插件在 TextRecognizer.initialize() 里硬引用了**全部语种**的
# Options（天城文 / 日文 / 韩文 / 拉丁 / 中文），而 app 只引入了拉丁（基础包自带）
# 与中文语言包，R8 在 release 压缩时把这些未引入的类判定为缺失并中断构建。
# 这些分支只有传入对应 script 时才会实例化（Dart 侧固定用 TextRecognitionScript.chinese），
# 永远不会执行 —— 因此不必为它们引入额外语言包（那会让包体白涨几十 MB），
# 忽略警告即可。若日后新增语种或升级插件报出新的缺类，这条通配规则一并覆盖。
-dontwarn com.google.mlkit.vision.text.**

# flutter_local_notifications 用 Gson 反射反序列化「已调度通知」，插件未提供 consumer rules。
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-dontwarn com.google.gson.**
-dontwarn sun.misc.**
