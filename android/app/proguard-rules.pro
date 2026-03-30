#############################
# Flutter Core
#############################
# Keep Flutter embedding classes
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Keep Flutter plugin classes (including GeneratedPluginRegistrant)
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.plugin.**
-keep class **.GeneratedPluginRegistrant { *; }

#############################
# Kotlin / Coroutines
#############################
-dontwarn kotlin.**
-dontwarn kotlinx.**
-keep class kotlinx.coroutines.** { *; }

#############################
# Networking & JSON
#############################
# OkHttp
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**

# Okio
-keep class okio.** { *; }
-dontwarn okio.**

# Gson
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

#############################
# Google Play Services
#############################
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

#############################
# Play Core / In-App Review
#############################
-keep class com.google.android.play.** { *; }
-dontwarn com.google.android.play.**

#############################
# Reflection / Dynamic Loading
#############################
# Keep any classes accessed via reflection
# (Add your own package if needed)
# Example:
# -keep class com.naijago.appOne.** { *; }

#############################
# General Safety
#############################
# Keep annotation data (used by some libs at runtime)
-keepattributes *Annotation*

# Keep enum values (used by Gson, etc.)
-keepclassmembers enum * { 
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable (so Android doesn't strip them)
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

#############################
# OneSignal / OpenTelemetry
#############################
# OneSignal's OTEL runtime references optional Jackson and AutoValue
# annotations that are not packaged in this app. R8 reports them as
# missing classes during minification, so we suppress those warnings.
-dontwarn com.fasterxml.jackson.core.JsonFactory
-dontwarn com.fasterxml.jackson.core.JsonGenerator
-dontwarn com.google.auto.value.AutoValue$CopyAnnotations
