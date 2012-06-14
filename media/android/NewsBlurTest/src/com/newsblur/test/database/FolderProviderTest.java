package com.newsblur.test.database;

import com.newsblur.database.FeedContentProvider;

import android.test.ProviderTestCase2;

public class FolderProviderTest extends ProviderTestCase2<FeedContentProvider> {

	public FolderProviderTest(Class<FeedContentProvider> providerClass, String providerAuthority) {
		super(providerClass, FeedContentProvider.PROVIDER_URI);
	}

}
