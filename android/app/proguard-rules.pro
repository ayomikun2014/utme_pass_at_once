# ===========================================================================
# ProGuard / R8 Keep Rules for PASS AT ONCE CBT (Release Build)
# Generated for: Firebase, Hive, Google Sign-In, Paystack, ScreenProtector,
#                google_fonts, flutter_local_notifications, connectivity_plus,
#                webview_flutter, image_picker, flutter_tts, device_info_plus,
#                cached_network_image, flutter_pdfview, in_app_review, etc.
# ===========================================================================

# ---- CRITICAL: Keep all native method names ----
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes Exceptions

# ---- Flutter Engine & Plugin Registrant ----
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# ---- Firebase Core / Auth / Firestore / Storage / Messaging ----
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ---- Firestore / gRPC / OkHttp / Protobuf ----
-dontwarn io.grpc.**
-keep class io.grpc.** { *; }
-dontwarn okio.**
-keep class okio.** { *; }
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-dontwarn com.google.protobuf.**
-keep class com.google.protobuf.** { *; }

# ---- SLF4J (referenced by Firebase/gRPC but not bundled in Android) ----
-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }

# ---- Gson (used internally by many Firebase / Google SDKs) ----
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class com.google.gson.stream.** { *; }
# Gson uses generic type information stored in class files when working with fields.
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ---- Google Sign-In / Credentials API / Identity ----
-keep class androidx.credentials.** { *; }
-dontwarn androidx.credentials.**
-keep class com.google.android.libraries.identity.googleid.** { *; }
-dontwarn com.google.android.libraries.identity.googleid.**
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.gms.auth.**
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.common.**

# ---- google_fonts (uses HTTP client internally) ----
-keep class com.google.android.gms.fonts.** { *; }
-dontwarn com.google.android.gms.fonts.**

# ---- Paystack (WebView-based checkout) ----
-keep class co.paystack.android.** { *; }
-dontwarn co.paystack.android.**

# ---- WebView (used by Paystack checkout and webview_flutter) ----
-keep class android.webkit.** { *; }
-dontwarn android.webkit.**
-keep class android.net.http.** { *; }
-dontwarn android.net.http.**

# ---- screen_protector (native MethodChannel - FLAG_SECURE) ----
-keep class com.codemagic.screen_protector.** { *; }
-dontwarn com.codemagic.screen_protector.**

# ---- flutter_local_notifications (native Android notification channels) ----
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# ---- connectivity_plus ----
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# ---- device_info_plus ----
-keep class dev.fluttercommunity.plus.device_info.** { *; }
-dontwarn dev.fluttercommunity.plus.device_info.**

# ---- package_info_plus ----
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-dontwarn dev.fluttercommunity.plus.packageinfo.**

# ---- share_plus ----
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**

# ---- image_picker ----
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# ---- flutter_tts (TextToSpeech native bridge) ----
-keep class com.tundralabs.fluttertts.** { *; }
-dontwarn com.tundralabs.fluttertts.**

# ---- flutter_pdfview (native PDF renderer) ----
-keep class com.alveliu.flutterpdfview.** { *; }
-dontwarn com.alveliu.flutterpdfview.**

# ---- in_app_review ----
-keep class dev.britannio.in_app_review.** { *; }
-dontwarn dev.britannio.in_app_review.**

# ---- cached_network_image / flutter_cache_manager (uses sqflite/HTTP) ----
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# ---- path_provider ----
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

# ---- shared_preferences ----
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# ---- url_launcher ----
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**

# ---- AndroidX Core (used by almost everything) ----
-keep class androidx.** { *; }
-dontwarn androidx.**

# ---- Kotlin (used by many plugins) ----
-keep class kotlin.** { *; }
-dontwarn kotlin.**
-keep class kotlinx.** { *; }
-dontwarn kotlinx.**

# ---- Keep enums (required for Firebase serialization) ----
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ---- Keep Parcelables ----
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# ---- Keep Serializable ----
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    !private <fields>;
    !private <methods>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ---- Keep native methods (JNI bridges) ----
-keepclasseswithmembernames class * {
    native <methods>;
}

# ---- Keep R classes (resource references) ----
-keepclassmembers class **.R$* {
    public static <fields>;
}

# ---- Suppress miscellaneous warnings ----
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn java.lang.invoke.**
-dontwarn sun.misc.**
