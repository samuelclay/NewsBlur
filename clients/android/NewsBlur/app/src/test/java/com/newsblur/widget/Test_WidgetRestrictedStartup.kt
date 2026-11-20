package com.newsblur.widget

import android.app.Application
import android.content.Intent
import android.os.CancellationSignal
import com.newsblur.NbApplication
import com.newsblur.util.Log
import dagger.hilt.android.EntryPointAccessors
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_WidgetRestrictedStartup {
    @After
    fun tear_down() = unmockkAll()

    @Test
    fun test_plain_application_can_bind_and_destroy_widget_without_hilt_or_preferences() {
        mockkStatic(Log::class)
        every { Log.d(any<Any>(), any()) } returns Unit
        mockkConstructor(CancellationSignal::class)
        // WidgetRemoteViewsService.kt can be bound with Android's restricted-mode Application.
        val application = mockk<Application>()
        every { application.applicationContext } returns application
        val service = mockk<WidgetRemoteViewsService>()
        every { service.applicationContext } returns application
        every { service.onGetViewFactory(any()) } answers { callOriginal() }
        val factory = service.onGetViewFactory(mockk<Intent>())

        factory.onCreate()
        factory.onDataSetChanged()
        assertEquals(0, factory.count)
        assertEquals(1, factory.viewTypeCount)
        assertNull(factory.loadingView)
        assertNull(factory.getViewAt(0))
        factory.onDestroy()
    }

    @Test
    fun test_normal_application_keeps_the_newsblur_widget_factory() {
        mockkStatic(Log::class)
        every { Log.d(any<Any>(), any()) } returns Unit
        mockkConstructor(CancellationSignal::class)
        mockkStatic(EntryPointAccessors::class)
        val application = mockk<NbApplication>()
        every { application.applicationContext } returns application
        every {
            EntryPointAccessors.fromApplication(application, WidgetRemoteViewsFactoryEntryPoint::class.java)
        } returns mockk<WidgetRemoteViewsFactoryEntryPoint>(relaxed = true)
        val service = mockk<WidgetRemoteViewsService>()
        every { service.applicationContext } returns application
        every { service.onGetViewFactory(any()) } answers { callOriginal() }

        assertTrue(service.onGetViewFactory(mockk<Intent>(relaxed = true)) is WidgetRemoteViewsFactory)
    }
}
