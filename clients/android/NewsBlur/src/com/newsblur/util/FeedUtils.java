package com.newsblur.util;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.text.Html;
import android.text.TextUtils;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.Story;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.service.NBSyncService;

public class FeedUtils {

    private FeedUtils() {} // util class - no instances

    // these are app-level singletons stored here for convenience. however, they
    // cannot be created lazily or via static init, they have to be created when
    // the main app context is created and it offers a reference
    public static BlurDatabaseHelper dbHelper;
    public static ImageLoader iconLoader;
    public static ImageLoader thumbnailLoader;
    public static FileCache storyImageCache;

    public static void offerInitContext(Context context) {
        if (dbHelper == null) {
            dbHelper = new BlurDatabaseHelper(context.getApplicationContext());
        }
        if (iconLoader == null) {
            iconLoader = ImageLoader.asIconLoader(context.getApplicationContext());
        }
        if (thumbnailLoader == null) {
            thumbnailLoader = ImageLoader.asThumbnailLoader(context.getApplicationContext());
        }
        if (storyImageCache == null) {
            storyImageCache = FileCache.asStoryImageCache(context.getApplicationContext());
        }
    }

    private static void triggerSync(Context c) {
        Intent i = new Intent(c, NBSyncService.class);
        c.startService(i);
    }

    public static void dropAndRecreateTables() {
        dbHelper.dropAndRecreateTables();
    }

    public static void clearStorySession() {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                try {
                    dbHelper.clearStorySession();
                } catch (Exception e) {
                    ; // TODO: this can evade DB-ready gating and crash. figure out how to
                      // defer this call until the DB-ready broadcast is received, as this
                      // can mask important errors
                }
                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

	public static void setStorySaved(final Story story, final boolean saved, final Context context) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                ReadingAction ra = (saved ? ReadingAction.saveStory(story.storyHash) : ReadingAction.unsaveStory(story.storyHash));
                ra.doLocal(dbHelper);
                NbActivity.updateAllActivities(NbActivity.UPDATE_STORY);
                dbHelper.enqueueAction(ra);
                triggerSync(context);
                return null;
            }
        }.execute();
    }

    public static void deleteFeed(final String feedId, final String folderName, final Context context, final APIManager apiManager) {
        new AsyncTask<Void, Void, NewsBlurResponse>() {
            @Override
            protected NewsBlurResponse doInBackground(Void... arg) {
                return apiManager.deleteFeed(feedId, folderName);
            }
            @Override
            protected void onPostExecute(NewsBlurResponse result) {
                // TODO: we can't check result.isError() because the delete call sets the .message property on all calls. find a better error check
                dbHelper.deleteFeed(feedId);
                NbActivity.updateAllActivities(NbActivity.UPDATE_METADATA);
            }
        }.execute();
    }

    public static void deleteSocialFeed(final String userId, final Context context, final APIManager apiManager) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                apiManager.unfollowUser(userId);
                return null;
            }
            @Override
            protected void onPostExecute(Void result) {
                // TODO: we can't check result.isError() because the delete call sets the .message property on all calls. find a better error check
                dbHelper.deleteSocialFeed(userId);
                NbActivity.updateAllActivities(NbActivity.UPDATE_METADATA);
            }
        }.execute();
    }

    public static void markStoryUnread(final Story story, final Context context) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                setStoryReadState(story, context, false);
                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

    public static void markStoryAsRead(final Story story, final Context context) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                setStoryReadState(story, context, true);
                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

    private static void setStoryReadState(Story story, Context context, boolean read) {
        dbHelper.touchStory(story.storyHash);
        if (story.read == read) { return; }

        // tell the sync service we need to mark read
        ReadingAction ra = (read ? ReadingAction.markStoryRead(story.storyHash) : ReadingAction.markStoryUnread(story.storyHash));
        dbHelper.enqueueAction(ra);

        // update unread state and unread counts in the local DB
        Set<FeedSet> impactedFeeds = dbHelper.setStoryReadState(story, read);
        NbActivity.updateAllActivities(NbActivity.UPDATE_STORY);

        triggerSync(context);
        NBSyncService.addRecountCandidates(impactedFeeds);
    }

    public static void markFeedsRead(final FeedSet fs, final Long olderThan, final Long newerThan, final Context context) {
        dbHelper.markStoriesRead(fs, olderThan, newerThan);
        dbHelper.updateLocalFeedCounts(fs);
        NbActivity.updateAllActivities(NbActivity.UPDATE_METADATA | NbActivity.UPDATE_STORY);
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                ReadingAction ra = ReadingAction.markFeedRead(fs, olderThan, newerThan);
                if (fs.isAllNormal() && (olderThan != null || newerThan != null)) {
                    // the mark-all-read API doesn't support range bounding, so we need to pass each and every
                    // feed ID to the API instead.
                    FeedSet newFeedSet = FeedSet.folder("all", dbHelper.getAllFeeds());
                    ra = ReadingAction.markFeedRead(newFeedSet, olderThan, newerThan);
                }
                dbHelper.enqueueAction(ra);
                triggerSync(context);
                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

    public static void updateClassifier(final String feedId, final String key, final Classifier classifier, final int classifierType, final int classifierAction, final Context context) {
        // first, update the server
        new AsyncTask<Void, Void, NewsBlurResponse>() {
            @Override
            protected NewsBlurResponse doInBackground(Void... arg) {
                APIManager apiManager = new APIManager(context);
                return apiManager.trainClassifier(feedId, key, classifierType, classifierAction);
            }
            @Override
            protected void onPostExecute(NewsBlurResponse result) {
                if (result.isError()) {
                    Toast.makeText(context, result.getErrorMessage(context.getString(R.string.error_saving_classifier)), Toast.LENGTH_LONG).show();
                }
            }
        }.execute();

        // next, update the local DB
        classifier.getMapForType(classifierType).put(key, classifierAction);
        classifier.feedId = feedId;
        dbHelper.clearClassifiersForFeed(feedId);
        dbHelper.insertClassifier(classifier);
    }

    public static void sendStoryBrief(Story story, Context context) {
        if (story == null ) { return; } 
        Intent intent = new Intent(android.content.Intent.ACTION_SEND);
        intent.setType("text/plain");
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.putExtra(Intent.EXTRA_TEXT, String.format(context.getResources().getString(R.string.send_brief), new Object[]{Html.fromHtml(story.title), story.permalink}));
        context.startActivity(Intent.createChooser(intent, "Send using"));
    }

    public static void sendStoryFull(Story story, Context context) {
        if (story == null ) { return; } 
        String body = getStoryContent(story.storyHash);
        Intent intent = new Intent(android.content.Intent.ACTION_SEND);
        intent.setType("text/plain");
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.putExtra(Intent.EXTRA_SUBJECT, Html.fromHtml(story.title).toString());
        intent.putExtra(Intent.EXTRA_TEXT, String.format(context.getResources().getString(R.string.send_full), new Object[]{story.permalink, Html.fromHtml(story.title), Html.fromHtml(body)}));
        context.startActivity(Intent.createChooser(intent, "Send using"));
    }

	public static void shareStory(Story story, String comment, String sourceUserId, Context context) {
        if (story.sourceUserId != null) {
            sourceUserId = story.sourceUserId;
        }
        ReadingAction ra = ReadingAction.shareStory(story.storyHash, story.id, story.feedId, sourceUserId, comment);
        dbHelper.enqueueAction(ra);
        ra.doLocal(dbHelper);
        NbActivity.updateAllActivities(NbActivity.UPDATE_SOCIAL);
        triggerSync(context);
    }

    public static void likeComment(Story story, String commentUserId, Context context) {
        ReadingAction ra = ReadingAction.likeComment(story.id, commentUserId, story.feedId);
        dbHelper.enqueueAction(ra);
        ra.doLocal(dbHelper);
        NbActivity.updateAllActivities(NbActivity.UPDATE_SOCIAL);
        triggerSync(context);
    }

    public static void unlikeComment(Story story, String commentUserId, Context context) {
        ReadingAction ra = ReadingAction.unlikeComment(story.id, commentUserId, story.feedId);
        dbHelper.enqueueAction(ra);
        ra.doLocal(dbHelper);
        NbActivity.updateAllActivities(NbActivity.UPDATE_SOCIAL);
        triggerSync(context);
    }
    
    public static void replyToComment(String storyId, String feedId, String commentUserId, String replyText, Context context) {
        ReadingAction ra = ReadingAction.replyToComment(storyId, feedId, commentUserId, replyText);
        dbHelper.enqueueAction(ra);
        ra.doLocal(dbHelper);
        NbActivity.updateAllActivities(NbActivity.UPDATE_SOCIAL);
        triggerSync(context);
    }

    public static void moveFeedToFolders(final Context context, final String feedId, final Set<String> toFolders, final Set<String> inFolders) {
        if (toFolders.size() < 1) return;
        new AsyncTask<Void, Void, NewsBlurResponse>() {
            @Override
            protected NewsBlurResponse doInBackground(Void... arg) {
                APIManager apiManager = new APIManager(context);
                return apiManager.moveFeedToFolders(feedId, toFolders, inFolders);
            }
            @Override
            protected void onPostExecute(NewsBlurResponse result) {
                NBSyncService.forceFeedsFolders();
                triggerSync(context);
            }
        }.execute();
    }

    public static FeedSet feedSetFromFolderName(String folderName) {
        return FeedSet.folder(folderName, getFeedIdsRecursive(folderName));
    }

    private static Set<String> getFeedIdsRecursive(String folderName) {
        Folder folder = dbHelper.getFolder(folderName);
        if (folder == null) return Collections.emptySet();
        Set<String> feedIds = new HashSet<String>(folder.feedIds.size());
        for (String id : folder.feedIds) feedIds.add(id);
        for (String child : folder.children) feedIds.addAll(getFeedIdsRecursive(child));
        return feedIds;
    }

    public static String getStoryText(String hash) {
        return dbHelper.getStoryText(hash);
    }

    public static String getStoryContent(String hash) {
        return dbHelper.getStoryContent(hash);
    }

    /**
     * Infer the feed ID for a story from the story's hash.  Useful for APIs
     * that takes a feed ID and story ID and only the story hash is known.
     *
     * TODO: this has a smell to it. can't all APIs just accept story hashes?
     */
    public static String inferFeedId(String storyHash) {
        String[] parts = TextUtils.split(storyHash, ":");
        if (parts.length != 2) return null;
        return parts[0];
    }

    public static Feed getFeed(String feedId) {
        return dbHelper.getFeed(feedId);
    }

    public static SocialFeed getSocialFeed(String feedId) {
        return dbHelper.getSocialFeed(feedId);
    }

}
