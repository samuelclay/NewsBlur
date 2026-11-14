package com.newsblur.activity

import io.mockk.every
import io.mockk.mockk
import org.junit.Test

class Test_ItemsListEarlyFinish {
    @Test
    fun test_banner_cleanup_before_layout_inflation() {
        val activity = mockk<ItemsList>(relaxed = true)
        every { activity["cancelStoryStatusBannerAnimation"]() } answers { callOriginal() }
        ItemsList::class.java.getDeclaredMethod("cancelStoryStatusBannerAnimation")
            .apply { isAccessible = true }.invoke(activity)
    }
}
