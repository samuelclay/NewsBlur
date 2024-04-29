# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile
-keepattributes Exceptions,InnerClasses,Signature
-keepattributes *Annotation*

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

# R8
-if class *
-keepclasseswithmembers, allowobfuscation class <1> {
  <init>(...);
  @com.google.gson.annotations.SerializedName <fields>;
}

-keep, allowobfuscation, allowshrinking class com.google.gson.reflect.TypeToken
-keep, allowobfuscation, allowshrinking class * extends com.google.gson.reflect.TypeToken
