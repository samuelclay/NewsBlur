package com.newsblur.web

enum class WebviewActionType {
    WEB_SEARCH,
    HIGHLIGHT,
    ;
}

fun interface WebviewActionDelegate {
    fun onAction(action: WebviewActionType, selectedText: String)
}

fun interface SelectionCallback {
    fun accept(text: String)
}

fun interface JsSelectionProvider {
    fun getSelectedText(callback: SelectionCallback)
}