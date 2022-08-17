package com.newsblur.util

enum class ListTextSize(val size: Float) {
    XS(0.7f),
    S(0.85f),
    M(1f),
    L(1.2f),
    XL(1.4f),
    XXL(1.8f),
    ;

    companion object {

        @JvmStatic
        fun fromSize(size: Float) = when (size) {
            0.7f -> XS
            0.85f -> S
            1f -> M
            1.2f -> L
            1.4f -> XL
            1.8f -> XXL
            else -> M
        }
    }
}

enum class ReadingTextSize(val size: Float) {
    XS(0.75f),
    S(0.9f),
    M(1f),
    L(1.2f),
    XL(1.5f),
    XXL(2f),
    ;

    companion object {

        @JvmStatic
        fun fromSize(size: Float) = when (size) {
            0.75f -> XS
            0.9f -> S
            1f -> M
            1.2f -> L
            1.5f -> XL
            2f -> XXL
            else -> M
        }
    }
}