package com.newsblur

import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader

object ResourceUtil {

    fun readJsonResource(filename: String): String {
        return try {
            val resource = if (filename.endsWith(".json")) "/$filename" else "/$filename.json"
            val sb = StringBuilder()
            val input = this::class.java.getResource(resource)?.openStream() ?: run {
                throw IOException("Unable to read file from resource")
            }
            val br = BufferedReader(InputStreamReader(input))
            var line = br.readLine()
            while (line != null) {
                sb.append(line)
                line = br.readLine()
            }
            sb.toString()
        } catch (e: IOException) {
            throw RuntimeException(e)
        }
    }
}