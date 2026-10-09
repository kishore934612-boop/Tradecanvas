# Flutter-specific ProGuard rules

# Keep Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep GeneratedPluginRegistrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# path_provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Google Fonts - keep font loading
-keep class com.google.android.gms.fonts.** { *; }

# Prevent R8 from removing WebSocket classes
-keep class org.java_websocket.** { *; }

# share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# Play Core — referenced by Flutter's deferred components manager but not used
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
