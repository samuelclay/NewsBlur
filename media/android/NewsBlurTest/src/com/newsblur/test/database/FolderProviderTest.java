package com.newsblur.test.database;

import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.test.ProviderTestCase2;
import android.test.mock.MockContentResolver;

import com.newsblur.database.BlurDatabase;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Folder;

public class FolderProviderTest extends ProviderTestCase2<FeedProvider> {

	private BlurDatabase dbHelper;
	private MockContentResolver contentResolver;

	public FolderProviderTest() {
		super(FeedProvider.class, FeedProvider.AUTHORITY);
	}
	
	public void testPrereqs() {
		assertNotNull(contentResolver);
		assertNotNull(dbHelper);
	}
	
	public void testOnCreate() {
		assertTrue(getProvider().onCreate());
	}
	
	@Override
	protected void setUp() throws Exception {
		super.setUp();
		dbHelper = new BlurDatabase(getMockContext());
		contentResolver = getMockContentResolver();
	}
	
	public void testInsertFolder() {
		Folder testFolder = getTestFolder(1);
		
		Uri uri = contentResolver.insert(FeedProvider.FOLDERS_URI, testFolder.values);
		SQLiteDatabase db = dbHelper.getReadableDatabase();
		Cursor rawQuery = db.rawQuery("SELECT * FROM " + DatabaseConstants.FOLDER_TABLE, null);
		
		assertEquals(1, rawQuery.getCount());
		assertEquals("1", uri.getLastPathSegment());
	}
	
	private Folder getTestFolder(final int testId) {
		Folder folder = new Folder();
		folder.setId(Integer.toString(testId));
		folder.setName("Name" + testId);
		return folder;
	}

}
