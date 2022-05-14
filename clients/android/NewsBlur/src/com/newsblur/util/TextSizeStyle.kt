package com.newsblur.util

enum class TextSizeStyle(val size: Float) {
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