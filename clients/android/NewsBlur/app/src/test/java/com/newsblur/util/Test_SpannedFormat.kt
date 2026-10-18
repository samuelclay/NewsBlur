package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Paths
import javax.xml.parsers.DocumentBuilderFactory

@Suppress("ktlint:standard:class-naming")
class Test_SpannedFormat {
    private fun text(
        template: String,
        vararg arguments: String,
    ) = SpannedFormat.pieces(template, arguments.toList()).joinToString("") { it.text }

    // Test_SpannedFormat.kt: reads the English source strings the activity adapters format.
    private val englishStrings: Map<String, String> by lazy {
        val document =
            Files.newInputStream(Paths.get("src/main/res/values/strings.xml")).use { input ->
                DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(input)
            }
        val nodes = document.getElementsByTagName("string")
        (0 until nodes.length).associate { index ->
            val node = nodes.item(index)
            node.attributes.getNamedItem("name").nodeValue to node.textContent.replace("\\'", "'")
        }
    }

    private fun english(
        name: String,
        vararg arguments: String,
    ) = text(englishStrings.getValue(name), *arguments)

    @Test
    fun test_arguments_land_where_the_translation_puts_them() {
        val pieces = SpannedFormat.pieces("%2\$sを%1\$sが購読しました", listOf("Sam", "NewsBlur Blog"))
        assertEquals(
            listOf(
                SpannedFormat.Piece("NewsBlur Blog", 1),
                SpannedFormat.Piece("を", null),
                SpannedFormat.Piece("Sam", 0),
                SpannedFormat.Piece("が購読しました", null),
            ),
            pieces,
        )
    }

    @Test
    fun test_sequential_percent_and_unknown_placeholders() {
        assertEquals("a then b", text("%s then %s", "a", "b"))
        assertEquals("100% of %3\$s", text("%1\$s%% of %3\$s", "100"))
        // An empty argument, such as a story without a title, is an empty piece that format() leaves unstyled.
        assertEquals(
            listOf(SpannedFormat.Piece("You shared ", null), SpannedFormat.Piece("", 0)),
            SpannedFormat.pieces("You shared %1\$s", listOf("")),
        )
    }

    @Test
    fun test_activity_sentences_match_the_old_english_rows() {
        // ActivitiesAdapter.java used to append "<user> <fragment> <story>"; the complete strings read the same.
        assertEquals("You subscribed to Daring Fireball", english("profile_activity_you_subscribed", "Daring Fireball"))
        assertEquals("sam subscribed to Daring Fireball", english("profile_activity_user_subscribed", "sam", "Daring Fireball"))
        assertEquals("You saved A story", english("profile_activity_you_saved", "A story"))
        assertEquals("sam saved A story", english("profile_activity_user_saved", "sam", "A story"))
        assertEquals("You signed up for NewsBlur", english("profile_activity_you_signed_up"))
        assertEquals("sam signed up for NewsBlur", english("profile_activity_user_signed_up", "sam"))
        assertEquals("You followed roy", english("profile_activity_you_followed", "roy"))
        assertEquals("sam followed roy", english("profile_activity_user_followed", "sam", "roy"))
        assertEquals("You favorited roy comments on A story", english("profile_activity_you_favorited_comments", "roy", "A story"))
        assertEquals("sam favorited roy comments on A story", english("profile_activity_user_favorited_comments", "sam", "roy", "A story"))
        assertEquals("You Replied to roy", english("profile_activity_you_replied", "roy"))
        assertEquals("sam Replied to roy", english("profile_activity_user_replied", "sam", "roy"))
        assertEquals("You shared A story", english("profile_activity_you_shared", "A story"))
        assertEquals("sam shared A story", english("profile_activity_user_shared", "sam", "A story"))
    }

    @Test
    fun test_interaction_sentences_match_the_old_english_rows() {
        // InteractionsAdapter.java used to pass "you", "your" or "sam's" into sentence fragments.
        assertEquals("roy is now following you", english("profile_interaction_following_you", "roy"))
        assertEquals("roy is now following sam", english("profile_interaction_following_user", "roy", "sam"))
        assertEquals("roy favorited your comments on A story", english("profile_interaction_favorited_your_comments", "roy", "A story"))
        assertEquals(
            "roy favorited sam's comments on A story",
            english("profile_interaction_favorited_user_comments", "roy", "sam", "A story"),
        )
        assertEquals("roy replied to your comment", english("profile_interaction_replied_your_comment", "roy"))
        assertEquals("roy replied to your reply", english("profile_interaction_replied_your_reply", "roy"))
        assertEquals("roy replied to sam's comment", english("profile_interaction_replied_user_comment", "roy", "sam"))
        assertEquals("roy replied to sam's reply", english("profile_interaction_replied_user_reply", "roy", "sam"))
        assertEquals("roy re-shared A story", english("profile_interaction_reshared", "roy", "A story"))
    }
}
