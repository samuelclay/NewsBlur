package com.newsblur.util

enum class ThumbnailStyle {
    LEFT_SMALL,
    LEFT_LARGE,
    RIGHT_SMALL,
    RIGHT_LARGE,
    OFF,
    ;

    fun isLeft() = this == LEFT_SMALL || this == LEFT_LARGE

    fun isRight() = this == RIGHT_SMALL || this == RIGHT_LARGE

    fun isSmall() = this == RIGHT_SMALL || this == LEFT_SMALL

    fun isOff() = this == OFF
}