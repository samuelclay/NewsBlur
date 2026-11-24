package com.newsblur.addsite

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// Test_AddSiteDescribe.kt: AddSiteSheet.kt only offers a Describe search for typed phrases that aren't addresses.
class Test_AddSiteDescribe {
    @Test fun test_descriptions_with_spaces_become_prompts() {
        assertEquals("reviews of iOS apps", AddSiteDescribeDecision.prompt("  reviews  of\tiOS apps "))
        assertEquals("the verge", AddSiteDescribeDecision.prompt("the verge"))
        assertEquals("site news.ycombinator.com", AddSiteDescribeDecision.prompt("site news.ycombinator.com"))
    }

    @Test fun test_addresses_and_single_words_are_not_prompts() {
        assertNull(AddSiteDescribeDecision.prompt("https://example.com/feed"))
        assertNull(AddSiteDescribeDecision.prompt("https://example.com/feed with words"))
        assertNull(AddSiteDescribeDecision.prompt("example.com"))
        assertNull(AddSiteDescribeDecision.prompt("verge"))
        assertNull(AddSiteDescribeDecision.prompt("a"))
        assertNull(AddSiteDescribeDecision.prompt("   "))
    }
}
