# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile
-dontobfuscate
-printusage

-keepattributes Exceptions,InnerClasses,Signature
-keepattributes *Annotation*

-dontwarn okio.**
-dontnote okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontnote okhttp3.**

# these two seem to confuse ProGuard, so force keep them
-keep class com.newsblur.util.StateFilter { *; }
-keep class com.newsblur.view.StateToggleButton$StateChangedListener { *; }

# we use proguard only as an APK shrinker and many of our dependencies throw
# all manner of gross warnings. kept silent by default, the following lines
# can be commented out to help diagnose shrinkage errors.
-dontwarn **
-dontnote **

# Gson uses generic type information stored in a class file when working with fields. Proguard
# removes such information by default, so configure it to keep all of it.
-keepattributes Signature

# Application classes that will be serialized/deserialized over Gson
-keep class com.newsblur.domain.** { <fields>; }
-keep class com.newsblur.network.domain.** { <fields>; }

# Prevent proguard from stripping interface information from TypeAdapter, TypeAdapterFactory,
# JsonSerializer, JsonDeserializer instances (so they can be used in @JsonAdapter)
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent R8 from leaving Data object members always null
-keepclassmembers, allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Retain generic signatures of TypeToken and its subclasses with R8 version 3.0 and higher.
-keep, allowobfuscation, allowshrinking class com.google.gson.reflect.TypeToken
-keep, allowobfuscation, allowshrinking class * extends com.google.gson.reflect.TypeToken
