package com.newsblur.util

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_ContactPage {
    @Test
    fun test_contact_details_are_available_in_app_without_email_client() {
        val strings = DocumentBuilderFactory.newInstance().newDocumentBuilder()
            .parse(File("src/main/res/values/strings.xml"))
        val nodes = strings.getElementsByTagName("string")
        val values = (0 until nodes.length).associate {
            nodes.item(it).attributes.getNamedItem("name").nodeValue to nodes.item(it).textContent
        }
        assertTrue("Contact page must have an explicit label", values.values.contains("Contact us"))
        assertTrue("Support email must be visible without composing a log report",
            values.values.any { it.contains("android@newsblur.com") })
        assertTrue("A dedicated in-app contact screen must be registered",
            File("src/main/AndroidManifest.xml").readText().contains(".activity.ContactActivity"))
    }
}
