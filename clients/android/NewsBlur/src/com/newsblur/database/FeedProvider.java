package com.newsblur.database;

import java.util.Arrays;

import android.R.string;
import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.UriMatcher;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.text.TextUtils;
import android.util.Log;

import com.newsblur.util.AppConstants;

/**
 * A magic subclass of ContentProvider that enhances calls to the DB for presumably more simple caller syntax.
 * 
 * TODO: the fact that most of the app uses this subclass of ContentProvider cast as such may
 *  deepy confuse future maintainers as to why the methods within magically do far, far more
 *  than suggested by the normal contract and provided args.  When time and resources permit,
 *  this paradigm could be replaced with a much more straightforward if slightly more verbose
 *  use of Plain Old Raw Queries.  Alternatively, the DB could be renormalized so that it is not
 *  necessary to use queries of such intense complexity.
 */
public class FeedProvider extends ContentProvider {

	public static final String AUTHORITY = "com.newsblur";
	public static final String VERSION = "v1";
	
	public static final Uri NEWSBLUR_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION);
	public static final Uri OFFLINE_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/offline_updates/");
	public static final Uri SOCIAL_FEEDS_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/social_feeds/");
	public static final Uri FEEDS_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/feeds/");
	public static final Uri CLASSIFIER_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/classifiers/");
	public static final Uri FEED_COUNT_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/feedcount/");
	public static final Uri SOCIALCOUNT_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/socialfeedcount/");
	public static final Uri ALL_STORIES_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/stories/");
	public static final Uri USERS_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/users/");
	public static final Uri STARRED_STORIES_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/starred_stories/");
	public static final Uri STARRED_STORIES_COUNT_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/starred_stories_count/");
	
	public static final Uri FEED_STORIES_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/stories/feed/");
	public static final Uri MULTIFEED_STORIES_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/stories/feeds/");
	public static final Uri SOCIALFEED_STORIES_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/stories/socialfeed/");
	public static final Uri STORY_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/story/");
	public static final Uri ALL_SHARED_STORIES_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/stories/socialfeeds/");
	public static final Uri COMMENTS_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/comments/");
	public static final Uri REPLIES_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/replies/");
	public static final Uri FEED_FOLDER_MAP_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/feedfoldermap/");
	public static final Uri FOLDERS_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/folders/");
	
	private static final int ALL_FEEDS = 0;
	private static final int ALL_SOCIAL_FEEDS = 1;
	private static final int ALL_FOLDERS = 2;
	private static final int FEED_STORIES = 3;
	private static final int INDIVIDUAL_FOLDER = 4;
	private static final int FEED_FOLDER_MAP = 5;
	private static final int SPECIFIC_FEED_FOLDER_MAP = 6;
	private static final int SOCIALFEED_STORIES = 7;
	private static final int INDIVIDUAL_FEED = 8;
	private static final int STORY_COMMENTS = 9;
	private static final int INDIVIDUAL_STORY = 10;
	private static final int FEED_COUNT = 11;
	private static final int OFFLINE_UPDATES = 12;
	private static final int SOCIALFEED_COUNT = 13;
	private static final int INDIVIDUAL_SOCIAL_FEED = 14;
	private static final int REPLIES = 15;
	private static final int MULTIFEED_STORIES = 16;
	private static final int ALL_STORIES = 20;
	private static final int ALL_SHARED_STORIES = 17;
	private static final int FEED_STORIES_NO_UPDATE = 18;
	private static final int CLASSIFIERS_FOR_FEED = 19;
	private static final int USERS = 21;
	private static final int STARRED_STORIES = 22;
	private static final int STARRED_STORIES_COUNT = 23;
	
	private BlurDatabase databaseHelper;

	private static UriMatcher uriMatcher;
	static {
		// TODO: get rid of the hard-coded URL paths and replace then with the constant values in DatabaseConstants
        //  that they actually represent.
		uriMatcher = new UriMatcher(UriMatcher.NO_MATCH);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feeds/", ALL_FEEDS);
		uriMatcher.addURI(AUTHORITY, VERSION + "/social_feeds/", ALL_SOCIAL_FEEDS);
		uriMatcher.addURI(AUTHORITY, VERSION + "/social_feeds/#/", INDIVIDUAL_SOCIAL_FEED);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feeds/*/", INDIVIDUAL_FEED);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feedcount/", FEED_COUNT);
		uriMatcher.addURI(AUTHORITY, VERSION + "/socialfeedcount/", SOCIALFEED_COUNT);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feed/*/", INDIVIDUAL_FEED);
		uriMatcher.addURI(AUTHORITY, VERSION + "/classifiers/#/", CLASSIFIERS_FOR_FEED);
		uriMatcher.addURI(AUTHORITY, VERSION + "/stories/socialfeed/#/", SOCIALFEED_STORIES);
		uriMatcher.addURI(AUTHORITY, VERSION + "/stories/socialfeeds/", ALL_SHARED_STORIES);
		uriMatcher.addURI(AUTHORITY, VERSION + "/stories/feed/#/", FEED_STORIES);
		uriMatcher.addURI(AUTHORITY, VERSION + "/stories/feed/#/noupdate", FEED_STORIES_NO_UPDATE);
		uriMatcher.addURI(AUTHORITY, VERSION + "/stories/", ALL_STORIES);
		uriMatcher.addURI(AUTHORITY, VERSION + "/stories/feeds/", MULTIFEED_STORIES);
		uriMatcher.addURI(AUTHORITY, VERSION + "/story/*/", INDIVIDUAL_STORY);
		uriMatcher.addURI(AUTHORITY, VERSION + "/comments/", STORY_COMMENTS);
		uriMatcher.addURI(AUTHORITY, VERSION + "/replies/", REPLIES);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feedfoldermap/", FEED_FOLDER_MAP);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feedfoldermap/*/", SPECIFIC_FEED_FOLDER_MAP);
		uriMatcher.addURI(AUTHORITY, VERSION + "/folders/", ALL_FOLDERS);
		uriMatcher.addURI(AUTHORITY, VERSION + "/folders/*/", INDIVIDUAL_FOLDER);
		uriMatcher.addURI(AUTHORITY, VERSION + "/offline_updates/", OFFLINE_UPDATES);
		uriMatcher.addURI(AUTHORITY, VERSION + "/users/", USERS);
        uriMatcher.addURI(AUTHORITY, VERSION + "/starred_stories/", STARRED_STORIES);
		uriMatcher.addURI(AUTHORITY, VERSION + "/starred_stories_count/", STARRED_STORIES_COUNT);
	}

	@Override
	public int delete(Uri uri, String selection, String[] selectionArgs) {
		final SQLiteDatabase db = databaseHelper.getWritableDatabase();
		switch (uriMatcher.match(uri)) {
			case OFFLINE_UPDATES:
				return db.delete(DatabaseConstants.UPDATE_TABLE, selection, selectionArgs);
			
			case ALL_SOCIAL_FEEDS:	
				db.delete(DatabaseConstants.SOCIALFEED_TABLE, null, null);
				return 1;	
				
			case ALL_FEEDS:	
				db.delete(DatabaseConstants.FEED_TABLE, null, null);
				db.delete(DatabaseConstants.FOLDER_TABLE, null, null);
				db.delete(DatabaseConstants.FEED_FOLDER_MAP_TABLE, null, null);
				db.delete(DatabaseConstants.STORY_TABLE, null, null);
				return 1;
				
			case ALL_STORIES:	
				return db.delete(DatabaseConstants.STORY_TABLE, null, null);	
				
			case SOCIALFEED_STORIES:
				StringBuilder socialDeleteBuilder = new StringBuilder();
				socialDeleteBuilder.append("DELETE FROM " + DatabaseConstants.STORY_TABLE);
				socialDeleteBuilder.append(" WHERE " + DatabaseConstants.STORY_ID + " IN (");
				socialDeleteBuilder.append(" SELECT " + DatabaseConstants.STORY_ID + " FROM ");
				socialDeleteBuilder.append(DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE + " WHERE ");
				socialDeleteBuilder.append(DatabaseConstants.SOCIALFEED_STORY_USER_ID + " = ? )");
				db.execSQL(socialDeleteBuilder.toString(), new String[] { uri.getLastPathSegment() });
				
				return db.delete(DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE, DatabaseConstants.SOCIALFEED_STORY_USER_ID + " = ?", new String[] { uri.getLastPathSegment() } );
				
			case INDIVIDUAL_FEED:
				db.delete(DatabaseConstants.FEED_TABLE, DatabaseConstants.FEED_ID + " = ?", new String[] { uri.getLastPathSegment() } );
				db.delete(DatabaseConstants.FEED_FOLDER_MAP_TABLE, DatabaseConstants.FEED_FOLDER_FEED_ID + " = ?", new String[] { uri.getLastPathSegment() } );
				return db.delete(DatabaseConstants.STORY_TABLE, DatabaseConstants.STORY_FEED_ID + " = ?", new String[] { uri.getLastPathSegment() } );
				
			case FEED_STORIES:
				db.delete(DatabaseConstants.STORY_TABLE, DatabaseConstants.STORY_FEED_ID + " = ?", new String[] { uri.getLastPathSegment() } );
				return 1;	
				
			case CLASSIFIERS_FOR_FEED:
				return db.delete(DatabaseConstants.CLASSIFIER_TABLE, DatabaseConstants.CLASSIFIER_ID + " = ?", new String[] { uri.getLastPathSegment() });
				
            case STARRED_STORIES:
                return db.delete(DatabaseConstants.STARRED_STORIES_TABLE, null, null);

			default:
				return 0;
		}
	}

	@Override
	public String getType(Uri uri) {
		return null;
	}

	@Override
	public int bulkInsert(Uri uri, ContentValues[] valuesArray) {
		int count = 0;
		final SQLiteDatabase db = databaseHelper.getWritableDatabase();
		switch (uriMatcher.match(uri)) {
			case ALL_FOLDERS:
				db.beginTransaction();
				try {
					for(ContentValues values: valuesArray) {
						db.insertWithOnConflict(DatabaseConstants.FOLDER_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
						count++;
					}
					db.setTransactionSuccessful();
				} finally {
					db.endTransaction();
				}
				break;
			case FEED_FOLDER_MAP:
				db.beginTransaction();
				try {
					for(ContentValues values: valuesArray) {
						db.insertWithOnConflict(DatabaseConstants.FEED_FOLDER_MAP_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
						count++;
					}
					db.setTransactionSuccessful();
				} finally {
					db.endTransaction();
				}
				break;
			case ALL_FEEDS:
				db.beginTransaction();
				try {
					for(ContentValues values: valuesArray) {
						db.insertWithOnConflict(DatabaseConstants.FEED_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
						count++;
					}
					db.setTransactionSuccessful();
				} finally {
					db.endTransaction();
				}
				break;
			case ALL_SOCIAL_FEEDS:
				db.beginTransaction();
				try {
					for(ContentValues values: valuesArray) {
						db.insertWithOnConflict(DatabaseConstants.SOCIALFEED_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
						count++;
					}
					db.setTransactionSuccessful();
				} finally {
					db.endTransaction();
				}
				break;
			default:
				count = super.bulkInsert(uri, valuesArray);
		}
		return count;
	}

	@Override
	public Uri insert(Uri uri, ContentValues values) {
		final SQLiteDatabase db = databaseHelper.getWritableDatabase();
		Uri resultUri = null;
		switch (uriMatcher.match(uri)) {

			// Inserting a folder
		case ALL_FOLDERS:
			final long folderId = db.insertWithOnConflict(DatabaseConstants.FOLDER_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			resultUri = uri.buildUpon().appendPath("" + folderId).build();
			break;

			// Inserting a feed to folder mapping
		case FEED_FOLDER_MAP:
			db.insertWithOnConflict(DatabaseConstants.FEED_FOLDER_MAP_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			resultUri = uri.buildUpon().appendPath(values.getAsString(DatabaseConstants.FEED_FOLDER_FOLDER_NAME)).build();
			break;
		
		case USERS:
			db.insertWithOnConflict(DatabaseConstants.USER_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			resultUri = uri.buildUpon().appendPath(values.getAsString(DatabaseConstants.USER_USERID)).build();
			break;
			
			// Inserting a classifier for a feed
		case CLASSIFIERS_FOR_FEED:
			values.put(DatabaseConstants.CLASSIFIER_ID, uri.getLastPathSegment());
			db.insertWithOnConflict(DatabaseConstants.CLASSIFIER_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			break;

			// Inserting a feed
		case ALL_FEEDS:
			db.insertWithOnConflict(DatabaseConstants.FEED_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			resultUri = uri.buildUpon().appendPath(values.getAsString(DatabaseConstants.FEED_ID)).build();
			break;
		
			// Inserting a social feed
		case ALL_SOCIAL_FEEDS:
			db.insertWithOnConflict(DatabaseConstants.SOCIALFEED_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			resultUri = uri.buildUpon().appendPath(values.getAsString(DatabaseConstants.SOCIAL_FEED_ID)).build();
			break;

			// Inserting a story for a social feed
		case SOCIALFEED_STORIES:
			final ContentValues socialMapValues = new ContentValues();
			socialMapValues.put(DatabaseConstants.SOCIALFEED_STORY_USER_ID, uri.getLastPathSegment());
			socialMapValues.put(DatabaseConstants.SOCIALFEED_STORY_STORYID, values.getAsString(DatabaseConstants.STORY_ID));
			db.insertWithOnConflict(DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE, null, socialMapValues, SQLiteDatabase.CONFLICT_REPLACE);
		
			resultUri = uri.buildUpon().appendPath(values.getAsString(DatabaseConstants.SOCIAL_FEED_ID)).build();
			break;
	
			// Inserting a comment
		case STORY_COMMENTS:
			db.insertWithOnConflict(DatabaseConstants.COMMENT_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			break;	
		
			// Inserting a reply
		case REPLIES:
			db.insertWithOnConflict(DatabaseConstants.REPLY_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			break;

			// Inserting a story	
		case FEED_STORIES:
			db.insertWithOnConflict(DatabaseConstants.STORY_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			break;	
			
			// Inserting a story assuming it's not already in the DB
		case FEED_STORIES_NO_UPDATE:
			db.insertWithOnConflict(DatabaseConstants.STORY_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			break;		
			
			// Inserting a story	
		case OFFLINE_UPDATES:
			db.insertWithOnConflict(DatabaseConstants.UPDATE_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			break;

        case STARRED_STORIES:
            db.insertWithOnConflict(DatabaseConstants.STARRED_STORIES_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
            break;

        case STARRED_STORIES_COUNT:
            db.insertWithOnConflict(DatabaseConstants.STARRED_STORY_COUNT_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
            break;

		case UriMatcher.NO_MATCH:
			Log.e(this.getClass().getName(), "No match found for URI: " + uri.toString());
			break;
		}
		return resultUri;
	}

	@Override
	public boolean onCreate() {
		databaseHelper = new BlurDatabase(getContext().getApplicationContext());
		return true;
	}

    /**
     * A simple utility wrapper that lets us log the insanely complex queries used below for debugging.
     */
    class LoggingDatabase {
        SQLiteDatabase mdb; 
        public LoggingDatabase(SQLiteDatabase db) {
            mdb = db;
        }
        public Cursor rawQuery(String sql, String[] selectionArgs) {
            if (AppConstants.VERBOSE_LOG) {
                Log.d(LoggingDatabase.class.getName(), "rawQuery: " + sql);
                Log.d(LoggingDatabase.class.getName(), "selArgs : " + Arrays.toString(selectionArgs));
            }
            return mdb.rawQuery(sql, selectionArgs);
        }
        public Cursor query(String table, String[] columns, String selection, String[] selectionArgs, String groupBy, String having, String orderBy) {
            return mdb.query(table, columns, selection, selectionArgs, groupBy, having, orderBy);
        }
    }

	@Override
	public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {

		final SQLiteDatabase rdb = databaseHelper.getReadableDatabase();
        final LoggingDatabase db = new LoggingDatabase(rdb);
		switch (uriMatcher.match(uri)) {

			// Query for all feeds (by default only return those that have unread items in them)
		case ALL_FEEDS:
            String feedsQuery = "SELECT " + TextUtils.join(",", DatabaseConstants.FEED_COLUMNS) + " FROM " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + 
					" INNER JOIN " + DatabaseConstants.FEED_TABLE + 
					" ON " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID + " = " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "." + DatabaseConstants.FEED_FOLDER_FEED_ID +
                    ((selection == null) ? "" : " WHERE " + selection) +
					" ORDER BY " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_TITLE + " COLLATE NOCASE";
            return db.rawQuery(feedsQuery, selectionArgs);

			// Query for a specific feed	
		case INDIVIDUAL_FEED:
			return db.rawQuery("SELECT " + TextUtils.join(",", DatabaseConstants.FEED_COLUMNS) + " FROM " + DatabaseConstants.FEED_TABLE +
					" WHERE " +  DatabaseConstants.FEED_ID + "= '" + uri.getLastPathSegment() + "'", selectionArgs);	
		
		case USERS:
			return db.query(DatabaseConstants.USER_TABLE, projection, selection, selectionArgs, null, null, null);	

        case STARRED_STORIES:
			String savedStoriesQuery = "SELECT " + TextUtils.join(",", DatabaseConstants.STARRED_STORY_COLUMNS) + ", " + DatabaseConstants.FEED_TITLE + ", " +
			DatabaseConstants.FEED_FAVICON_URL + ", " + DatabaseConstants.FEED_FAVICON_COLOR + ", " + DatabaseConstants.FEED_FAVICON_BORDER + ", " +
			DatabaseConstants.FEED_FAVICON_FADE + ", " + DatabaseConstants.FEED_FAVICON_TEXT +
                    " FROM " + DatabaseConstants.STARRED_STORIES_TABLE +
			" INNER JOIN " + DatabaseConstants.FEED_TABLE + 
			" ON " + DatabaseConstants.STARRED_STORIES_TABLE + "." + DatabaseConstants.STORY_FEED_ID + " = " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID; 
			return db.rawQuery(savedStoriesQuery, null);

        case STARRED_STORIES_COUNT:
            return db.query(DatabaseConstants.STARRED_STORY_COUNT_TABLE, projection, selection, selectionArgs, null, null, null);
			
			// Query for classifiers for a given feed
		case CLASSIFIERS_FOR_FEED:
			return db.query(DatabaseConstants.CLASSIFIER_TABLE, null, DatabaseConstants.CLASSIFIER_ID + " = ?", new String[] { uri.getLastPathSegment() }, null, null, null);
			
			// Query for a specific folder	
		case INDIVIDUAL_FOLDER:
			String individualFolderQuery = "SELECT " + TextUtils.join(",", DatabaseConstants.FOLDER_COLUMNS) + " FROM " + DatabaseConstants.FEED_FOLDER_MAP_TABLE  +
			" LEFT JOIN " + DatabaseConstants.FOLDER_TABLE + 
			" ON " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "." + DatabaseConstants.FEED_FOLDER_FOLDER_NAME + " = " + DatabaseConstants.FOLDER_TABLE + "." + DatabaseConstants.FOLDER_NAME +
			" LEFT JOIN " + DatabaseConstants.FEED_TABLE + 
			" ON " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID + " = " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "."  + DatabaseConstants.FEED_FOLDER_FEED_ID + 
			" WHERE " + DatabaseConstants.FOLDER_NAME + " = ?";

			StringBuilder individualFolderbuilder = new StringBuilder();
			individualFolderbuilder.append(individualFolderQuery);
			selectionArgs = new String[] { uri.getLastPathSegment() };
			
			return db.rawQuery(individualFolderbuilder.toString(), selectionArgs);
			
			// Query for total feed counts
		case FEED_COUNT:
			String sumQuery = "SELECT SUM(" + DatabaseConstants.FEED_POSITIVE_COUNT + ") AS " + DatabaseConstants.SUM_POS + ", " +
			"SUM(" + DatabaseConstants.FEED_NEUTRAL_COUNT + ") AS " + DatabaseConstants.SUM_NEUT + " FROM " + DatabaseConstants.FEED_TABLE;
			return db.rawQuery(sumQuery, selectionArgs);	
			
		case SOCIALFEED_COUNT:
			String socialSumQuery = "SELECT SUM(" + DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT + ") AS " + DatabaseConstants.SUM_POS + ", " +
			"SUM(" + DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT + ") AS " + DatabaseConstants.SUM_NEUT + ", " + 
			"SUM(" + DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT + ") AS " + DatabaseConstants.SUM_NEG + " FROM " + DatabaseConstants.SOCIALFEED_TABLE;
			return db.rawQuery(socialSumQuery, selectionArgs);		
			
			// Querying for a stories from a feed
		case FEED_STORIES:
			if (!TextUtils.isEmpty(selection)) {
				selection = selection + " AND " + DatabaseConstants.STORY_FEED_ID + " = ?";
			} else {
				selection = DatabaseConstants.STORY_FEED_ID + " = ?";
			}
			selectionArgs = new String[] { uri.getLastPathSegment() };
			return db.query(DatabaseConstants.STORY_TABLE, DatabaseConstants.STORY_COLUMNS, selection, selectionArgs, null, null, sortOrder);
			
			// Querying for all stories
		case ALL_STORIES:
			String allStoriesQuery = "SELECT " + TextUtils.join(",", DatabaseConstants.STORY_COLUMNS) + ", " + DatabaseConstants.FEED_TITLE + ", " +
			DatabaseConstants.FEED_FAVICON_URL + ", " + DatabaseConstants.FEED_FAVICON_COLOR + ", " + DatabaseConstants.FEED_FAVICON_BORDER + ", " +
			DatabaseConstants.FEED_FAVICON_FADE + ", " + DatabaseConstants.FEED_FAVICON_TEXT +
                    " FROM " + DatabaseConstants.STORY_TABLE +
			" INNER JOIN " + DatabaseConstants.FEED_TABLE + 
			" ON " + DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_FEED_ID + " = " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID + 
			" WHERE " + selection + " ORDER BY " + sortOrder;
			return db.rawQuery(allStoriesQuery, null);
			
			// Querying for a stories from a selection of feeds
		case MULTIFEED_STORIES:
			if (!TextUtils.isEmpty(selection)) {
				selection = selection + " AND " + DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_FEED_ID + " IN ( " + TextUtils.join(",", selectionArgs) + ")";
			} else {
				selection = DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_FEED_ID + " IN ( " + TextUtils.join(",", selectionArgs) + ")";
			}
			String userQuery = "SELECT " + TextUtils.join(",", DatabaseConstants.STORY_COLUMNS) + ", " + DatabaseConstants.FEED_TITLE + ", " +
			DatabaseConstants.FEED_FAVICON_URL + ", " + DatabaseConstants.FEED_FAVICON_COLOR + ", " + DatabaseConstants.FEED_FAVICON_BORDER + ", " +
			DatabaseConstants.FEED_FAVICON_FADE + ", " + DatabaseConstants.FEED_FAVICON_TEXT +
                    " FROM " + DatabaseConstants.STORY_TABLE +
			" INNER JOIN " + DatabaseConstants.FEED_TABLE + 
			" ON " + DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_FEED_ID + " = " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID + 
			" WHERE " + selection + " ORDER BY " + sortOrder;
			
			return db.rawQuery(userQuery, null);
			
			// Querying for a stories from a feed
		case STORY_COMMENTS:
			if (selectionArgs.length == 1) {
				selection = DatabaseConstants.COMMENT_STORYID + " = ?";
			} else {
				selection = DatabaseConstants.COMMENT_STORYID + " = ? AND " + DatabaseConstants.COMMENT_USERID + " = ?";
			}
			return db.query(DatabaseConstants.COMMENT_TABLE, DatabaseConstants.COMMENT_COLUMNS, selection, selectionArgs, null, null, null);

			// Querying for replies to a comment
		case REPLIES:
			selection = DatabaseConstants.REPLY_COMMENTID+ " = ?";
			return db.query(DatabaseConstants.REPLY_TABLE, DatabaseConstants.REPLY_COLUMNS, selection, selectionArgs, null, null, null);
			
			// Query for feeds with no folder mapping	
		case FEED_FOLDER_MAP:
			String nullFolderQuery = "SELECT " + TextUtils.join(",", DatabaseConstants.FEED_COLUMNS) + " FROM " + DatabaseConstants.FEED_TABLE + 
			" LEFT JOIN " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + 
			" ON " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID + " = " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "."  + DatabaseConstants.FEED_FOLDER_FEED_ID +
			" WHERE " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "." + DatabaseConstants.FEED_FOLDER_FOLDER_NAME + " IS NULL " +
			" GROUP BY " + DatabaseConstants.FEED_TABLE+ "." + DatabaseConstants.FEED_ID;

			StringBuilder nullFolderBuilder = new StringBuilder();
			nullFolderBuilder.append(nullFolderQuery);
			if (selectionArgs != null && selectionArgs.length > 0) {
				nullFolderBuilder.append(selectionArgs[0]);
			}
			nullFolderBuilder.append(" ORDER BY " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_TITLE + " COLLATE NOCASE");
			return db.rawQuery(nullFolderBuilder.toString(), null);

			// Querying for feeds for a given folder	
		case SPECIFIC_FEED_FOLDER_MAP:
			String[] folderArguments = new String[] { uri.getLastPathSegment() };

			String query = "SELECT " + 
			TextUtils.join(",", (projection == null ? DatabaseConstants.FEED_COLUMNS : projection)) + " FROM " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + 
			" INNER JOIN " + DatabaseConstants.FEED_TABLE + 
			" ON " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID + " = " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "." + DatabaseConstants.FEED_FOLDER_FEED_ID +
			" WHERE " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "." + DatabaseConstants.FEED_FOLDER_FOLDER_NAME + " = ? " +
			" GROUP BY " + DatabaseConstants.FEED_TABLE+ "." + DatabaseConstants.FEED_ID;

			StringBuilder builder = new StringBuilder();
			builder.append(query);
			if (selectionArgs != null && selectionArgs.length > 0) {
				builder.append(selectionArgs[0]);
			}
			builder.append(" ORDER BY " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_TITLE + " COLLATE NOCASE");
			return db.rawQuery(builder.toString(), folderArguments);

			// Querying for all folders with unread items
		case ALL_FOLDERS:
            // Of note about the following query:
            //  1) the union clause lets ALL_FOLDER queries also select the "root" folder that appears in the UI whether
            //     or not it has unread stories in it.
            //  2) the root folder is excluded from the final join so as not to create a duplicate root folder
            //  3) values of the pos/neut/neg columns for the root folder are ignored by the UI
            //  4) we use a union rather than a full outer join because sqlite doesn't support the latter
            //  5) the order of the left and right sides of the union are important: due to an undocumented feature/bug in sqlite,
            //     if the two sides of the union are reversed, the result columns are incorrectly prefixed.
            String folderQuery = "SELECT " + DatabaseConstants.FOLDER_ID + ", " + DatabaseConstants.FOLDER_NAME + ", 0 AS " + DatabaseConstants.SUM_POS + ", 0 AS " + DatabaseConstants.SUM_NEUT + ", 0 AS " + DatabaseConstants.SUM_NEG +
            " FROM " + DatabaseConstants.FOLDER_TABLE +
            " WHERE " + DatabaseConstants.FOLDER_NAME + "='" + AppConstants.ROOT_FOLDER + "' UNION" +
            " SELECT " + TextUtils.join(",", DatabaseConstants.FOLDER_COLUMNS) + 
            " FROM " + DatabaseConstants.FEED_FOLDER_MAP_TABLE  +
            " INNER JOIN " + DatabaseConstants.FOLDER_TABLE + 
            " ON " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "." + DatabaseConstants.FEED_FOLDER_FOLDER_NAME + " = " + DatabaseConstants.FOLDER_TABLE + "." + DatabaseConstants.FOLDER_NAME +
            " INNER JOIN " + DatabaseConstants.FEED_TABLE + 
            " ON " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID + " = " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "."  + DatabaseConstants.FEED_FOLDER_FEED_ID + 
            " WHERE NOT " + DatabaseConstants.FOLDER_NAME + "='" + AppConstants.ROOT_FOLDER + "'" +
            " GROUP BY " + DatabaseConstants.FOLDER_TABLE + "." + DatabaseConstants.FOLDER_NAME;

            StringBuilder folderBuilder = new StringBuilder();
            folderBuilder.append(folderQuery);
            if (selectionArgs != null && selectionArgs.length > 0) {
                // TODO: by not iterating over the selectionArgs array, this method wildly breaks the contract of the query() method and
                //  will almost certainly confuse callers eventually
                folderBuilder.append(selectionArgs[0]);
            }
            folderBuilder.append(" ORDER BY ");
            folderBuilder.append(DatabaseConstants.FOLDER_TABLE + "." + DatabaseConstants.FOLDER_NAME + " COLLATE NOCASE");
            return db.rawQuery(folderBuilder.toString(), null);
		case OFFLINE_UPDATES:
			return db.query(DatabaseConstants.UPDATE_TABLE, null, null, null, null, null, null);
		case ALL_SOCIAL_FEEDS:
			return db.query(DatabaseConstants.SOCIALFEED_TABLE, null, selection, null, null, null, "UPPER(" + DatabaseConstants.SOCIAL_FEED_TITLE + ") ASC");
		case INDIVIDUAL_SOCIAL_FEED:
			return db.query(DatabaseConstants.SOCIALFEED_TABLE, null, DatabaseConstants.SOCIAL_FEED_ID + " = ?", new String[] { uri.getLastPathSegment() }, null, null, null);
		case ALL_SHARED_STORIES: 
			String allSharedQuery = "SELECT " + TextUtils.join(",", DatabaseConstants.STORY_COLUMNS) + ", " + DatabaseConstants.FEED_TITLE + ", " +
			DatabaseConstants.FEED_FAVICON_URL + ", " + DatabaseConstants.FEED_FAVICON_COLOR + ", " + DatabaseConstants.FEED_FAVICON_BORDER + ", " +
			DatabaseConstants.FEED_FAVICON_FADE + ", " + DatabaseConstants.FEED_FAVICON_TEXT +
                    " FROM " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE +
			" INNER JOIN " + DatabaseConstants.STORY_TABLE + 
			" ON " + DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_ID + " = " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE + "." + DatabaseConstants.SOCIALFEED_STORY_STORYID +
			" INNER JOIN " + DatabaseConstants.FEED_TABLE + 
			" ON " + DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_FEED_ID + " = " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID;
			
			StringBuilder allSharedBuilder = new StringBuilder();
			allSharedBuilder.append(allSharedQuery);
			if (!TextUtils.isEmpty(selection)) {
				allSharedBuilder.append(" WHERE ");
				allSharedBuilder.append(selection);
			}
			allSharedBuilder.append("GROUP BY " + DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_ID);
			if (!TextUtils.isEmpty(sortOrder)) {
				allSharedBuilder.append(" ORDER BY " + sortOrder);
			}
			return db.rawQuery(allSharedBuilder.toString(), null);
			
		case SOCIALFEED_STORIES:
			String[] userArgument = new String[] { uri.getLastPathSegment() };

			String socialQuery = "SELECT " + TextUtils.join(",", DatabaseConstants.STORY_COLUMNS) + ", " + DatabaseConstants.FEED_TITLE + ", " +
			DatabaseConstants.FEED_FAVICON_URL + ", " + DatabaseConstants.FEED_FAVICON_COLOR + ", " + DatabaseConstants.FEED_FAVICON_BORDER + ", " +
			DatabaseConstants.FEED_FAVICON_FADE + ", " + DatabaseConstants.FEED_FAVICON_TEXT +
                    " FROM " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE +
			" INNER JOIN " + DatabaseConstants.STORY_TABLE + 
			" ON " + DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_ID + " = " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE + "." + DatabaseConstants.SOCIALFEED_STORY_STORYID +
			" INNER JOIN " + DatabaseConstants.FEED_TABLE + 
			" ON " + DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_FEED_ID + " = " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID +
			" WHERE " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE + "." + DatabaseConstants.SOCIALFEED_STORY_USER_ID + " = ? ";
			
			StringBuilder storyBuilder = new StringBuilder();
			storyBuilder.append(socialQuery);
			if (!TextUtils.isEmpty(selection)) {
				storyBuilder.append("AND ");
				storyBuilder.append(selection);
			}
			if (!TextUtils.isEmpty(sortOrder)) {
				storyBuilder.append(" ORDER BY " + sortOrder);
			}
			return db.rawQuery(storyBuilder.toString(), userArgument);
		default:
			throw new UnsupportedOperationException("Unknown URI: " + uri);
		}
	}

	@Override
	public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
		final SQLiteDatabase db = databaseHelper.getWritableDatabase();
		
		switch (uriMatcher.match(uri)) {
        case ALL_FEEDS:
            return db.update(DatabaseConstants.FEED_TABLE, values, null, null);
		case INDIVIDUAL_FEED:
			return db.update(DatabaseConstants.FEED_TABLE, values, DatabaseConstants.FEED_ID + " = ?", new String[] { uri.getLastPathSegment() });
		case INDIVIDUAL_SOCIAL_FEED:
			return db.update(DatabaseConstants.SOCIALFEED_TABLE, values, DatabaseConstants.SOCIAL_FEED_ID + " = ?", new String[] { uri.getLastPathSegment() });	
		case SOCIALFEED_STORIES:
			return db.update(DatabaseConstants.SOCIALFEED_TABLE, values, DatabaseConstants.FEED_ID + " = ?", new String[] { uri.getLastPathSegment() });	
		case INDIVIDUAL_STORY:
			return db.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_ID + " = ?", new String[] { uri.getLastPathSegment() });
			// In order to run a raw SQL query whereby we make decrement the column we need to a dynamic reference - something the usual content provider can't easily handle. Hence this circuitous hack. 
		case FEED_COUNT: 
			db.execSQL("UPDATE " + DatabaseConstants.FEED_TABLE + " SET " + selectionArgs[0] + " = " + selectionArgs[0] + " - 1 WHERE " + DatabaseConstants.FEED_ID + " = " + selectionArgs[1]);
			return 0;
		case SOCIALFEED_COUNT: 
			db.execSQL("UPDATE " + DatabaseConstants.SOCIALFEED_TABLE + " SET " + selectionArgs[0] + " = " + selectionArgs[0] + " - 1 WHERE " + DatabaseConstants.SOCIAL_FEED_ID + " = " + selectionArgs[1]);
			return 0;	
        case STARRED_STORIES_COUNT:
            int rows = db.update(DatabaseConstants.STARRED_STORY_COUNT_TABLE, values, null, null);
            if (rows == 0 ) {
                db.insertWithOnConflict(DatabaseConstants.STARRED_STORY_COUNT_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
            }
            return 1;
		default:
			throw new UnsupportedOperationException("Unknown URI: " + uri);
		}
	}

}
