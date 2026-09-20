# ===========================================================================
# R8 rules for PASS AT ONCE CBT (release)
#
# The previous version of this file kept whole libraries -- androidx, kotlin,
# Firebase, Play Services, gRPC, protobuf, Flutter, and every plugin -- with
# `-keep class x.** { *; }`. A keep like that forbids renaming, so R8 could
# obfuscate only about 9% of the app, and Play flagged the bundle for it.
#
# Almost all of it was unnecessary. Every one of those libraries ships its own
# consumer rules inside its AAR and R8 applies them automatically; anything
# named in AndroidManifest.xml is kept by the build; and a Flutter plugin is
# reached over a MethodChannel by *string* name, so its Java classes can be
# renamed freely. Flutter's own rules go further and explicitly allow plugins
# to be shrunk and obfuscated.
#
# What is left here is what R8 cannot work out for itself: things reached by
# reflection, by JNI, or by the platform. When adding a rule, prefer the
# narrowest form that works, and say why it is needed.
# ===========================================================================

# ---- Attributes the runtime and reflective libraries read ----
# Signature carries generic types (Gson, Firestore); the annotation and inner
# class attributes are read by the libraries below.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes Exceptions

# Readable crash reports: R8 renames as usual, and the mapping file uploaded
# with the bundle turns the names back in Play Console.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---- JNI: a native method must keep the name its C++ side calls ----
-keepclasseswithmembernames class * {
    native <methods>;
}

# ---- The platform reaches these by name ----
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keepclassmembers class **.R$* {
    public static <fields>;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ---- Gson maps by field name, so fields it reads may not be renamed ----
# flutter_local_notifications serialises its payloads this way.
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.dexterous.flutterlocalnotifications.models.** { <fields>; }

# ---- Google Sign-In through Credential Manager ----
# The identity library builds its requests reflectively, and R8 has been seen
# to strip those request classes -- which fails sign-in at runtime and nowhere
# else, so this one stays until sign-in is proven without it.
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.playservices.** { *; }

# ---- Warnings about code paths Android never reaches ----
# Compile-time references inside libraries: server-side gRPC, SLF4J, build
# annotations. Silencing a warning is not the same as keeping the class.
-dontwarn org.slf4j.**
-dontwarn io.grpc.**
-dontwarn com.google.protobuf.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn com.google.j2objc.annotations.**
-dontwarn javax.annotation.**
-dontwarn javax.naming.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn java.lang.invoke.**
-dontwarn sun.misc.**
-dontwarn android.webkit.**
