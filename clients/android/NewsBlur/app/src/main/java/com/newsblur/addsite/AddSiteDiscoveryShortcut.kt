package com.newsblur.addsite

import androidx.annotation.StringRes
import com.newsblur.R
import com.newsblur.discover.DiscoveryTab

// AddSiteDiscoveryShortcut.kt labels the tiles with string resources; a null title keeps the tab's product name.
enum class AddSiteDiscoveryShortcut(
    val tab: DiscoveryTab,
    @StringRes val titleRes: Int?,
) {
    WEB(DiscoveryTab.WEB, R.string.discover_tab_web_feed),
    POPULAR(DiscoveryTab.POPULAR, R.string.discover_tab_popular),
    TRENDING(DiscoveryTab.SEARCH, R.string.add_site_shortcut_trending),
    YOUTUBE(DiscoveryTab.YOUTUBE, null),
    REDDIT(DiscoveryTab.REDDIT, null),
    NEWSLETTERS(DiscoveryTab.NEWSLETTERS, R.string.discover_tab_newsletters),
    PODCASTS(DiscoveryTab.PODCASTS, R.string.discover_tab_podcasts),
    GOOGLE(DiscoveryTab.GOOGLE, null),
}
