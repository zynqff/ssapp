# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core (fix R8 missing classes)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Google Sign In
-keep class com.google.android.gms.** { *; }

# SQLite
-keep class net.sqlcipher.** { *; }
