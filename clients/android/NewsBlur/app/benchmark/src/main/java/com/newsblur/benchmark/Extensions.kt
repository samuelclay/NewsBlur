package com.newsblur.benchmark

import androidx.benchmark.macro.MacrobenchmarkScope
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until

fun MacrobenchmarkScope.inputIntoLabel(label: String, text: String) {
    device.findObject(By.text(label))
            .text = text
}

fun MacrobenchmarkScope.clickOnText(text: String) {
    device.findObject(By.text(text))
            .click()
}

fun MacrobenchmarkScope.waitForTextShown(text: String, timeout: Long = 5000) {
    check(device.wait(Until.hasObject(By.text(text)), timeout)) {
        "View showing '$text' not found after waiting $timeout ms."
    }
}

fun MacrobenchmarkScope.waitLongForTextShown(text: String, timeout: Long = 15000) {
    check(device.wait(Until.hasObject(By.text(text)), timeout)) {
        "View showing '$text' not found after waiting $timeout ms."
    }
}