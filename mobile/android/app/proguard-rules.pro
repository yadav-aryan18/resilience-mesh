# MediaPipe keep rules
-dontwarn com.google.mediapipe.**
-keep class com.google.mediapipe.** { *; }

# Google Play Core deferred components optional rules
-dontwarn com.google.android.play.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Flutter keep rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
