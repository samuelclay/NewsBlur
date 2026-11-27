package com.newsblur.subscription

import com.newsblur.subscription.ArchiveCardStatus.INCLUDED_IN_ARCHIVE_EXTRA
import com.newsblur.subscription.ArchiveCardStatus.INCLUDED_IN_PRO
import com.newsblur.subscription.ArchiveCardStatus.OWNED
import com.newsblur.subscription.ArchiveCardStatus.PURCHASE
import com.newsblur.subscription.ArchiveCardStatus.UPGRADE_FROM_ARCHIVE
import com.newsblur.subscription.ArchiveCardStatus.UPGRADE_FROM_PREMIUM
import com.newsblur.subscription.ArchiveListenHours.ONE
import com.newsblur.subscription.ArchiveListenHours.TEN
import org.junit.Assert.assertEquals
import org.junit.Test

/** Test_ArchiveCardPlan.kt: which plan ArchiveCardPlan.kt has the Premium Archive card show, buy or manage. */
class Test_ArchiveCardPlan {
    private enum class Account { FREE, PREMIUM, ARCHIVE, ARCHIVE_EXTRA, PRO }

    /** The server sends every lower flag too: an Archive Extra account is also Archive and Premium. */
    private fun plan(
        account: Account,
        extraOffered: Boolean = true,
        chosenHours: ArchiveListenHours? = null,
    ): ArchiveCardPlan =
        archiveCardPlan(
            isPremium = account != Account.FREE,
            isArchive = account >= Account.ARCHIVE,
            isArchiveExtra = account == Account.ARCHIVE_EXTRA,
            isPro = account == Account.PRO,
            extraOffered = extraOffered,
            chosenHours = chosenHours,
        )

    @Test
    fun test_without_extra_from_play_the_card_stays_premium_archive_without_a_toggle() {
        assertEquals(ArchiveCardPlan(false, ONE, PURCHASE, null), plan(Account.FREE, extraOffered = false, chosenHours = TEN))
        assertEquals(ArchiveCardPlan(false, ONE, OWNED, ONE), plan(Account.ARCHIVE, extraOffered = false, chosenHours = TEN))
    }

    @Test
    fun test_the_toggle_starts_on_one_hour_and_two_hours_sells_archive_extra() {
        assertEquals(ArchiveCardPlan(true, ONE, PURCHASE, null), plan(Account.FREE))
        assertEquals(ArchiveCardPlan(true, TEN, PURCHASE, null), plan(Account.FREE, chosenHours = TEN))
        assertEquals(ArchiveCardPlan(true, TEN, UPGRADE_FROM_PREMIUM, null), plan(Account.PREMIUM, chosenHours = TEN))
    }

    @Test
    fun test_archive_subscribers_own_one_hour_and_upgrade_to_two() {
        assertEquals(ArchiveCardPlan(true, ONE, OWNED, ONE), plan(Account.ARCHIVE))
        assertEquals(ArchiveCardPlan(true, TEN, UPGRADE_FROM_ARCHIVE, ONE), plan(Account.ARCHIVE, chosenHours = TEN))
    }

    @Test
    fun test_archive_extra_subscribers_own_two_hours_and_one_hour_is_included() {
        assertEquals(ArchiveCardPlan(true, TEN, OWNED, TEN), plan(Account.ARCHIVE_EXTRA))
        assertEquals(ArchiveCardPlan(true, ONE, INCLUDED_IN_ARCHIVE_EXTRA, TEN), plan(Account.ARCHIVE_EXTRA, chosenHours = ONE))
        // Their plan still reads as Archive Extra when Play stops selling it.
        assertEquals(ArchiveCardPlan(true, TEN, OWNED, TEN), plan(Account.ARCHIVE_EXTRA, extraOffered = false))
    }

    @Test
    fun test_pro_keeps_the_card_as_it_was_without_a_toggle() {
        assertEquals(ArchiveCardPlan(false, ONE, INCLUDED_IN_PRO, null), plan(Account.PRO))
        assertEquals(ArchiveCardPlan(false, ONE, INCLUDED_IN_PRO, null), plan(Account.PRO, chosenHours = TEN))
    }
}
