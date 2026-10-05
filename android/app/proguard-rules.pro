# GreenGains ProGuard Rules for Release Build
# Prevents obfuscation from breaking native code, OkHttp, Gson, and Kotlin coroutines

# Keep GreenGains service classes (accessed via reflection)
-keep class com.eremat.greengains.service.** { *; }
-keep class com.eremat.greengains.receivers.** { *; }
-keep class com.eremat.greengains.notification.** { *; }

# OkHttp3 (used for backend uploads)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# Gson (JSON serialization)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# Keep data classes for Gson
-keep class com.eremat.greengains.service.SensorReading { *; }
-keep class com.eremat.greengains.service.LocationData { *; }
-keep class com.eremat.greengains.service.LightData { *; }
-keep class com.eremat.greengains.service.AccelerometerData { *; }
-keep class com.eremat.greengains.service.GyroscopeData { *; }
-keep class com.eremat.greengains.service.SensorSnapshot { *; }

# Sensor models now live in .models; the upload queue on disk is Gson-serialised.
-keep class com.eremat.greengains.models.** { *; }
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Generic Gson rules
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep fields in R
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# Geohash library
-keep class ch.hsr.geohash.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Remove logging in release builds (optional - uncomment to enable)
# -assumenosideeffects class android.util.Log {
#     public static *** d(...);
#     public static *** v(...);
#     public static *** i(...);
# }
