package com.newsblur.addsite

import com.newsblur.discover.DiscoveryTab

enum class AddSiteDiscoveryShortcut(val tab: DiscoveryTab, val title: String = tab.title) {
    WEB(DiscoveryTab.WEB),
    POPULAR(DiscoveryTab.POPULAR),
    TRENDING(DiscoveryTab.SEARCH, "Trending"),
    YOUTUBE(DiscoveryTab.YOUTUBE),
    REDDIT(DiscoveryTab.REDDIT),
    NEWSLETTERS(DiscoveryTab.NEWSLETTERS),
    PODCASTS(DiscoveryTab.PODCASTS),
    GOOGLE(DiscoveryTab.GOOGLE),
}
