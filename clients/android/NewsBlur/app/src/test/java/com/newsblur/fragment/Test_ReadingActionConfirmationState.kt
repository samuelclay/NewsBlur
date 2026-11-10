package com.newsblur.fragment

import android.os.Bundle
import android.os.Handler
import com.newsblur.R
import com.newsblur.activity.ItemsList
import com.newsblur.util.FeedSet
import com.newsblur.util.ReadingAction
import com.newsblur.util.ReadingActionListener
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.unmockkConstructor
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test
import java.io.ByteArrayOutputStream
import java.io.ObjectOutputStream
import java.io.Serializable

class Test_ReadingActionConfirmationState {
    private val arguments = mutableMapOf<String, Any?>()

    @Before
    fun setUp() {
        mockkConstructor(Bundle::class, Handler::class)
        every { anyConstructed<Bundle>().putSerializable(any(), any()) } answers {
            arguments[firstArg()] = secondArg()
        }
        every { anyConstructed<Bundle>().putCharSequence(any(), any()) } answers {
            arguments[firstArg()] = secondArg()
        }
        every { anyConstructed<Bundle>().putInt(any(), any()) } answers {
            arguments[firstArg()] = secondArg()
        }
        every { anyConstructed<Bundle>().putBoolean(any(), any()) } answers {
            arguments[firstArg()] = secondArg()
        }
    }

    @After
    fun tearDown() {
        unmockkConstructor(Bundle::class, Handler::class)
    }

    @Test
    fun test_confirmation_state_does_not_serialize_the_callback_handler() {
        createDialog(HandlerOwningListener(Handler()))

        ObjectOutputStream(ByteArrayOutputStream()).use { it.writeObject(HashMap(arguments)) }

        assertFalse(arguments.values.any { it is ReadingActionListener })
    }

    @Test
    fun test_restored_confirmation_notifies_the_current_activity() {
        val original = mockk<ReadingActionListener>(relaxed = true)
        createDialog(original)
        val restored = restoredArguments()

        ReadingActionConfirmationFragment.notifyReadingActionCompleted(restored, currentActivity)

        verify(exactly = 1) { currentActivity.onReadingActionCompleted() }
        verify(exactly = 0) { original.onReadingActionCompleted() }
    }

    @Test
    fun test_confirmation_without_a_callback_does_not_advance_the_activity() {
        createDialog(null)
        val restored = restoredArguments()

        ReadingActionConfirmationFragment.notifyReadingActionCompleted(restored, currentActivity)

        verify(exactly = 0) { currentActivity.onReadingActionCompleted() }
    }

    private val currentActivity = mockk<ItemsList>(relaxed = true)

    private fun createDialog(callback: ReadingActionListener?) =
        ReadingActionConfirmationFragment.newInstance(
            ReadingAction.MarkFeedRead(FeedSet.singleFeed("42"), null, null),
            "Feed", null, R.array.mark_all_read_options, callback,
        )

    private fun restoredArguments(): Bundle {
        every { anyConstructed<Bundle>().getBoolean(any()) } answers { arguments[firstArg()] as? Boolean ?: false }
        return Bundle()
    }

    private class HandlerOwningListener(val handler: Handler) : ReadingActionListener, Serializable {
        override fun onReadingActionCompleted() = Unit
    }
}
