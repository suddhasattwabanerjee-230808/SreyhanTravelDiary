# Release builds are shrunk by R8. ML Kit's translator finds its parts by
# name at runtime, and once R8 had stripped or renamed them, every Bengali or
# Hindi check crashed (NullPointerException: getClass() on null) in 0.5.0.
# Keep ML Kit and its Play services internals whole.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.firebase.components.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_**
