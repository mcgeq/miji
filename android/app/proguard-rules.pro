# R8 / ProGuard 规则（release 构建启用，用于压缩安装包）。
# Flutter 引擎与大部分插件自带 keep 规则；这里只补充未自带规则、使用反射的插件。

# flutter_local_notifications 用 Gson 反射反序列化「已调度通知」，插件未提供 consumer rules。
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-dontwarn com.google.gson.**
-dontwarn sun.misc.**
