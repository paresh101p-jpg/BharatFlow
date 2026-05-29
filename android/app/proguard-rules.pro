# Flutter & Platform Integration Keep Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase Core & Firebase Messaging Keep Rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Play Services & Auth
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.internal.ads.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Workmanager
-keep class com.befrog.workmanager.** { *; }
-dontwarn com.befrog.workmanager.**

# Geolocator & Location Services
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# In-App Update
-keep class com.google.android.play.core.install.model.** { *; }
-keep class com.google.android.play.core.appupdate.** { *; }
-dontwarn com.google.android.play.core.**

# Supabase & Native Serialization Models
-keep class io.supabase.flutter.** { *; }
-keep class com.supabase.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
    @com.google.android.gms.common.annotation.KeepForSdk <fields>;
    @com.google.firebase.database.PropertyName <fields>;
}
-keep class **.Model { *; }
-keep class **.Models { *; }
-keep class **.Entity { *; }
-keep class * implements java.io.Serializable { *; }
