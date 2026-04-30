# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.view.** { *; }
-dontwarn io.flutter.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore
-keep class com.google.cloud.firestore.** { *; }
-dontwarn com.google.cloud.firestore.**

# Encryption/Crypto (PointyCastle)
-keep class org.bouncycastle.** { *; }
-keep class javax.crypto.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn javax.crypto.**

# flutter_secure_storage
-keep class com.google.android.security.** { *; }
-dontwarn com.google.android.security.**

# Google Sign-In
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-dontwarn com.google.android.gms.auth.api.signin.**

# Gson (used by Firebase and other libraries)
-keep class com.google.gson.** { *; }
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }
-dontwarn com.google.gson.**
-dontwarn sun.misc.**

# Kotlin
-keep class kotlin.** { *; }
-keep interface kotlin.** { *; }
-dontwarn kotlin.**

# Kotlin Coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Retrofit (if used by Firebase)
-keep class retrofit2.** { *; }
-keep interface retrofit2.** { *; }
-dontwarn retrofit2.**

# OkHttp (if used)
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**

# Annotations
-keep class androidx.annotation.** { *; }
-keep @interface androidx.annotation.** { *; }

# AndroidX
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable implementations
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep inner classes
-keepclasseswithmembers class * {
    *** *(...);
}

# ── R8 missing-class suppressions ──
# Legacy okhttp 1.x classes referenced (but not used at runtime) by io.grpc.okhttp
-dontwarn com.squareup.okhttp.**

# JVM-only reflection class referenced by Guava's Invokable
-dontwarn java.lang.reflect.AnnotatedType

# gRPC + Guava transitive deps (Firebase Firestore pulls these in)
-dontwarn io.grpc.**
-dontwarn com.google.common.**
