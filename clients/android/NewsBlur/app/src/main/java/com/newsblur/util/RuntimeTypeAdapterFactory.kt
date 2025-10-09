package com.newsblur.util

import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParseException
import com.google.gson.TypeAdapter
import com.google.gson.TypeAdapterFactory
import com.google.gson.internal.Streams
import com.google.gson.reflect.TypeToken
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonToken
import com.google.gson.stream.JsonWriter
import java.io.IOException

class RuntimeTypeAdapterFactory<T> private constructor(
    private val baseType: Class<*>,
    private val typeFieldName: String,
) : TypeAdapterFactory {
    // Use star-projected Class to avoid variance issues
    private val labelToSubtype = LinkedHashMap<String, Class<*>>()
    private val subtypeToLabel = LinkedHashMap<Class<*>, String>()

    companion object {
        @JvmStatic
        fun <T> of(
            baseType: Class<T>,
            typeFieldName: String,
        ): RuntimeTypeAdapterFactory<T> {
            require(typeFieldName.isNotBlank()) { "typeFieldName must be non-empty" }
            return RuntimeTypeAdapterFactory(baseType, typeFieldName)
        }
    }

    fun registerSubtype(
        subtype: Class<out T>,
        label: String,
    ): RuntimeTypeAdapterFactory<T> {
        require(label.isNotBlank()) { "label must be non-empty" }
        val sub: Class<*> = subtype // widen to Class<*>
        check(baseType.isAssignableFrom(sub)) { "Subtype $sub is not a $baseType" }
        check(!labelToSubtype.containsKey(label)) { "Label already registered: $label" }
        check(!subtypeToLabel.containsKey(sub)) { "Subtype already registered: $sub" }
        labelToSubtype[label] = sub
        subtypeToLabel[sub] = label
        return this
    }

    override fun <R> create(
        gson: Gson,
        type: TypeToken<R>,
    ): TypeAdapter<R>? {
        if (!baseType.isAssignableFrom(type.rawType)) return null

        val labelToDelegate = LinkedHashMap<String, TypeAdapter<Any>>()
        val subtypeToDelegate = LinkedHashMap<Class<*>, TypeAdapter<Any>>()

        // Build delegate adapters for each subtype
        for ((label, sub) in labelToSubtype) {
            @Suppress("UNCHECKED_CAST")
            val delegate = gson.getDelegateAdapter(this, TypeToken.get(sub)) as TypeAdapter<Any>
            labelToDelegate[label] = delegate
            subtypeToDelegate[sub] = delegate
        }

        return object : TypeAdapter<R>() {
            @Throws(IOException::class)
            override fun write(
                out: JsonWriter,
                value: R?,
            ) {
                if (value == null) {
                    out.nullValue()
                    return
                }
                val srcType: Class<*> = value.javaClass
                val label =
                    subtypeToLabel[srcType]
                        ?: throw JsonParseException("Unregistered subtype: $srcType (register it)")

                @Suppress("UNCHECKED_CAST")
                val delegate =
                    (subtypeToDelegate[srcType] as? TypeAdapter<R>)
                        ?: throw JsonParseException("No delegate for $srcType")

                val obj = toJsonObject(delegate, value)
                val withType =
                    JsonObject().apply {
                        addProperty(typeFieldName, label)
                        for ((k, v) in obj.entrySet()) if (k != typeFieldName) add(k, v)
                    }
                Streams.write(withType, out)
            }

            @Throws(IOException::class)
            override fun read(inReader: JsonReader): R? {
                if (inReader.peek() == JsonToken.NULL) {
                    inReader.nextNull()
                    return null
                }
                val obj = Streams.parse(inReader).asJsonObject
                val label =
                    obj[typeFieldName]?.takeUnless { it.isJsonNull }?.asString
                        ?: throw JsonParseException("Missing '$typeFieldName' for ${baseType.name}")

                val delegate =
                    labelToDelegate[label]
                        ?: throw JsonParseException("Unknown subtype label '$label' for ${baseType.name}")

                val withType =
                    JsonObject().apply {
                        addProperty(typeFieldName, label)
                        for ((k, v) in obj.entrySet()) if (k != typeFieldName) add(k, v)
                    }

                @Suppress("UNCHECKED_CAST")
                return (delegate as TypeAdapter<R>).fromJsonTree(withType)
            }
        }.nullSafe()
    }

    private fun <R> toJsonObject(
        delegate: TypeAdapter<R>,
        value: R,
    ): JsonObject {
        val tree = delegate.toJsonTree(value)
        if (tree == null || tree.isJsonNull) return JsonObject()
        return if (tree.isJsonObject) tree.asJsonObject else JsonObject().apply { add("value", tree) }
    }
}
