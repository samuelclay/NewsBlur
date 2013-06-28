package com.newsblur.test.database;

import java.util.Date;

import android.content.ContentResolver;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.test.ProviderTestCase2;
import android.util.Log;

import com.newsblur.database.BlurDatabase;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Folder;
import com.newsblur.domain.Story;

public class FolderProviderTest extends ProviderTestCase2<FeedProvider> {

	private BlurDatabase dbHelper;
	private ContentResolver contentResolver;
	private String TAG = "FolderProviderTest";

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
		Log.d(TAG , "Setup");
		
		dbHelper = new BlurDatabase(getContext());
		dbHelper.dropAndRecreateTables();
		contentResolver = getContext().getContentResolver();
	}
	
	public void testInsertFolder() {
		Folder testFolder = getTestFolder(1);
		
		Uri uri = contentResolver.insert(FeedProvider.FOLDERS_URI, testFolder.values);
		SQLiteDatabase db = dbHelper.getReadableDatabase();
		Cursor rawQuery = db.rawQuery("SELECT * FROM " + DatabaseConstants.FOLDER_TABLE, null);
		
		assertEquals(1, rawQuery.getCount());
		assertEquals("1", uri.getLastPathSegment());
	}
	
	
	public void testInsertStory() {
		Story testStory = getTestStory(1);
		Uri feedUri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(testStory.feedId).build();
		
		Uri uri = contentResolver.insert(feedUri, testStory.getValues());
		SQLiteDatabase db = dbHelper.getReadableDatabase();
		Cursor rawQuery = db.rawQuery("SELECT * FROM " + DatabaseConstants.STORY_TABLE, null);
		
		assertEquals(1, rawQuery.getCount());
	}
	
	
	public void testInsertUpdateStory() {
		Story testStory = getTestStory(1);
		Uri feedUri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(testStory.feedId).build();
		
		contentResolver.insert(feedUri, testStory.getValues());
		SQLiteDatabase db = dbHelper.getReadableDatabase();
		Cursor rawQuery = db.rawQuery("SELECT * FROM " + DatabaseConstants.STORY_TABLE, null);
		
		assertEquals(1, rawQuery.getCount());
		
		testStory.read = 1;
		
		contentResolver.insert(feedUri, testStory.getValues());
		
		Cursor secondQuery = db.rawQuery("SELECT * FROM " + DatabaseConstants.STORY_TABLE, null);
		secondQuery.moveToFirst();
		assertEquals(1, secondQuery.getCount());
		assertEquals(1, secondQuery.getInt(secondQuery.getColumnIndex(DatabaseConstants.STORY_READ)));
	}
	
	
	private Folder getTestFolder(final int testId) {
		Folder folder = new Folder();
		folder.setId(Integer.toString(testId));
		folder.setName("Name" + testId);
		return folder;
	}
	
	private Story getTestStory(final int testId) {
		Story story = new Story();
		story.authors = "Arthur Conan Doyle";
		story.commentCount = 1;
		story.content = "Watson, come here, I need you.";
		story.date = new Date();
		story.date.setTime(946747860000l); // January 1 2000, 12:30pm
		story.feedId = "3"; // Daring Fireball
		story.id = "The Story of the New iPhone";
		story.sharedUserIds = new String[] { };
		story.tags = new String[] { };
		story.permalink = "http://www.daringfireball.com/omgiphone";
		story.read = 0;
		story.title = "Hello";
		
		return story;
	}
}
