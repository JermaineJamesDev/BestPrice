# Keep all ML Kit classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }

# Keep specific text recognition classes
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

-dontwarn com.google.mlkit.**

# DROPs all TransportRuntime debug logging calls
-assumenosideeffects class com.google.android.datatransport.runtime.TransportRuntime {
    public static *** debug(...);
    public static *** i(...);
    public static *** v(...);
    public static *** w(...);
    public static *** e(...);
}

# Also strip CCT backend classes if you never need them:
-dontwarn com.google.android.datatransport.cct.**