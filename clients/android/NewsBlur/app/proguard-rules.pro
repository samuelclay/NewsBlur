# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
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
