package com.newsblur.util;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.text.TextUtils;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.Story;
import com.newsblur.fragment.ReadingActionConfirmationFragment;
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
        if (storyImageCache == null) {
            storyImageCache = FileCache.asStoryImageCache(context.getApplicationContext());
        }
        if (thumbnailLoader == null) {
            thumbnailLoader = ImageLoader.asThumbnailLoader(context.getApplicationContext(), storyImageCache);
        }
    }

    public static void triggerSync(Context c) {
        // NB: when our minSDKversion hits 28, it could be possible to start the service via the JobScheduler
        // with the setImportantWhileForeground() flag via an enqueue() and get rid of all legacy startService
        // code paths
        Intent i = new Intent(c, NBSyncService.class);
        c.startService(i);
    }

    public static void dropAndRecreateTables() {
        dbHelper.dropAndRecreateTables();
    }

    public static void prepareReadingSession(final FeedSet fs, final boolean resetFirst) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                try {
                    if (resetFirst) NBSyncService.resetReadingSession(dbHelper);
                    NBSyncService.prepareReadingSession(dbHelper, fs);
                } catch (Exception e) {
                    ; // this is a UI hinting call and might fail if the DB is being reset, but that is fine
                }
                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

	public static void setStorySaved(final Story story, final boolean saved, final Context context) {
        setStorySaved(story.storyHash, saved, context);
    }

	public static void setStorySaved(final String storyHash, final boolean saved, final Context context) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                ReadingAction ra = (saved ? ReadingAction.saveStory(storyHash) : ReadingAction.unsaveStory(storyHash));
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
        try {
            // this shouldn't throw errors, but crash logs suggest something is racing it for DB resources.
            // capture logs in hopes of finding the correlated action
            dbHelper.touchStory(story.storyHash);
        } catch (Exception e) {
            com.newsblur.util.Log.e(FeedUtils.class.getName(), "error touching story state in DB", e);
        }
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

    /**
     * Mark a story (un)read when only the hash is known. This can and will cause a brief mismatch in
     * unread counts, or a longer mismatch if offline.  This method should only be used from outside
     * the app, such as from a notifiation handler.  You must use setStoryReadState(Story, Context, boolean)
     * when calling from within the UI.
     */
    public static void setStoryReadStateExternal(String storyHash, Context context, boolean read) {
        ReadingAction ra = (read ? ReadingAction.markStoryRead(storyHash) : ReadingAction.markStoryUnread(storyHash));
        dbHelper.enqueueAction(ra);

        String feedId = inferFeedId(storyHash);
        FeedSet impactedFeed = FeedSet.singleFeed(feedId);
        NBSyncService.addRecountCandidates(impactedFeed);

        triggerSync(context);
    }

    /**
     * Marks some or all of the stories in a FeedSet as read for an activity, handling confirmation dialogues as necessary.
     */
    public static void markRead(NbActivity activity, FeedSet fs, Long olderThan, Long newerThan, int choicesRid, boolean finishAfter) {
        ReadingAction ra = null;
        if (fs.isAllNormal() && (olderThan != null || newerThan != null)) {
            // the mark-all-read API doesn't support range bounding, so we need to pass each and every
            // feed ID to the API instead.
            FeedSet newFeedSet = FeedSet.folder("all", dbHelper.getAllActiveFeeds());
            ra = ReadingAction.markFeedRead(newFeedSet, olderThan, newerThan);
        } else {
            if (fs.getSingleFeed() != null) {
                if (!fs.isMuted()) {
                    ra = ReadingAction.markFeedRead(fs, olderThan, newerThan);
                } else {
                    // this should not be possible if appropriate menus have been altered. 
                    com.newsblur.util.Log.w(activity, "disregarding mark-read for muted feed.");
                    return;
                }
            } else if (fs.isFolder()) {
                Set<String> feedIds = fs.getMultipleFeeds();
                Set<String> allActiveFeedIds = dbHelper.getAllActiveFeeds();
                Set<String> activeFeedIds = new HashSet<String>();
                activeFeedIds.addAll(feedIds);
                activeFeedIds.retainAll(allActiveFeedIds);
                FeedSet filteredFs = FeedSet.folder(fs.getFolderName(), activeFeedIds);
                ra = ReadingAction.markFeedRead(filteredFs, olderThan, newerThan);
            } else {
                ra = ReadingAction.markFeedRead(fs, olderThan, newerThan);
            }
        }
        // is it okay to just do the mark? otherwise we will seek confirmation
        boolean doImmediate = true;
        // if set, this message will be displayed instead of the options to actually mark read. used in
        // situations where marking all read is almost certainly not what the user wants to do
        String optionalOverrideMessage = null;
        if ((olderThan != null) || (newerThan != null)) {
            // if this is a range mark, check that option
            if (PrefsUtils.isConfirmMarkRangeRead(activity)) doImmediate = false;
        } else {
            // if this is an all mark, check that option
            MarkAllReadConfirmation confirmation = PrefsUtils.getMarkAllReadConfirmation(activity);
            if (confirmation.feedSetRequiresConfirmation(fs)) doImmediate = false;
        }
        // marks hit all stories, even when filtering via search, so warn
        if (fs.getSearchQuery() != null) {
            doImmediate = false;
            optionalOverrideMessage = activity.getResources().getString(R.string.search_mark_read_warning);
        }
        if (doImmediate) {
            doAction(ra, activity);
            if (finishAfter) {
                activity.finish();
            }
        } else {
            String title = null;
            if (fs.isAllNormal()) {
                title = activity.getResources().getString(R.string.all_stories);
            } else if (fs.isFolder()) {
                title = fs.getFolderName();
            } else if (fs.isSingleSocial()) {
                title = FeedUtils.getSocialFeed(fs.getSingleSocialFeed().getKey()).feedTitle;
            } else {
                title = FeedUtils.getFeed(fs.getSingleFeed()).title;
            }
            ReadingActionConfirmationFragment dialog = ReadingActionConfirmationFragment.newInstance(ra, title, optionalOverrideMessage, choicesRid, finishAfter);
            dialog.show(activity.getSupportFragmentManager(), "dialog");
        }
    }

    public static void disableNotifications(Context context, Feed feed) {
        updateFeedNotifications(context, feed, false, false);
    }

    public static void enableUnreadNotifications(Context context, Feed feed) {
        updateFeedNotifications(context, feed, true, false);
    }
    public static void enableFocusNotifications(Context context, Feed feed) {
        updateFeedNotifications(context, feed, true, true);
    }

    private static void updateFeedNotifications(final Context context, final Feed feed, final boolean enable, final boolean focusOnly) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                if (focusOnly) {
                    feed.setNotifyFocus();
                } else {
                    feed.setNotifyUnread();
                }
                feed.enableAndroidNotifications(enable);
                dbHelper.updateFeed(feed);
                ReadingAction ra = ReadingAction.setNotify(feed.feedId, feed.notificationTypes, feed.notificationFilter);
                doAction(ra, context);
                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }
        
    public static void doAction(final ReadingAction ra, final Context context) {
        if (ra == null) throw new IllegalArgumentException("ReadingAction must not be null");
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                dbHelper.enqueueAction(ra);
                int impact = ra.doLocal(dbHelper);
                NbActivity.updateAllActivities(impact);
                triggerSync(context);
                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

    public static void updateClassifier(String feedId, Classifier classifier, FeedSet fs, Context context) {
        ReadingAction ra = ReadingAction.updateIntel(feedId, classifier, fs);
        doAction(ra, context);
    }

    public static void sendStoryBrief(Story story, Context context) {
        if (story == null ) { return; } 
        Intent intent = new Intent(android.content.Intent.ACTION_SEND);
        intent.setType("text/plain");
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.putExtra(Intent.EXTRA_SUBJECT, UIUtils.fromHtml(story.title).toString());
        intent.putExtra(Intent.EXTRA_TEXT, String.format(context.getResources().getString(R.string.send_brief), new Object[]{UIUtils.fromHtml(story.title), story.permalink}));
        context.startActivity(Intent.createChooser(intent, "Send using"));
    }

    public static void sendStoryFull(Story story, Context context) {
        if (story == null ) { return; } 
        String body = getStoryContent(story.storyHash);
        Intent intent = new Intent(android.content.Intent.ACTION_SEND);
        intent.setType("text/plain");
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.putExtra(Intent.EXTRA_SUBJECT, UIUtils.fromHtml(story.title).toString());
        intent.putExtra(Intent.EXTRA_TEXT, String.format(context.getResources().getString(R.string.send_full), new Object[]{story.permalink, UIUtils.fromHtml(story.title), UIUtils.fromHtml(body)}));
        context.startActivity(Intent.createChooser(intent, "Send using"));
    }

    public static void shareStory(Story story, String comment, String sourceUserId, Context context) {
        if (story.sourceUserId != null) {
            sourceUserId = story.sourceUserId;
        }
        ReadingAction ra = ReadingAction.shareStory(story.storyHash, story.id, story.feedId, sourceUserId, comment);
        dbHelper.enqueueAction(ra);
        ra.doLocal(dbHelper);
        NbActivity.updateAllActivities(NbActivity.UPDATE_SOCIAL | NbActivity.UPDATE_STORY);
        triggerSync(context);
    }

    public static void renameFeed(Context context, String feedId, String newFeedName) {
        ReadingAction ra = ReadingAction.renameFeed(feedId, newFeedName);
        dbHelper.enqueueAction(ra);
        int impact = ra.doLocal(dbHelper);
        NbActivity.updateAllActivities(impact);
        triggerSync(context);
    }

    public static void unshareStory(Story story, Context context) {
        ReadingAction ra = ReadingAction.unshareStory(story.storyHash, story.id, story.feedId);
        dbHelper.enqueueAction(ra);
        ra.doLocal(dbHelper);
        NbActivity.updateAllActivities(NbActivity.UPDATE_SOCIAL | NbActivity.UPDATE_STORY);
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

    public static void updateReply(Context context, Story story, String commentUserId, String replyId, String replyText) {
        ReadingAction ra = ReadingAction.updateReply(story.id, story.feedId, commentUserId, replyId, replyText);
        dbHelper.enqueueAction(ra);
        ra.doLocal(dbHelper);
        NbActivity.updateAllActivities(NbActivity.UPDATE_SOCIAL);
        triggerSync(context);
    }

    public static void deleteReply(Context context, Story story, String commentUserId, String replyId) {
        ReadingAction ra = ReadingAction.deleteReply(story.id, story.feedId, commentUserId, replyId);
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

    public static void muteFeeds(final Context context, final Set<String> feedIds) {
        updateFeedActiveState(context, feedIds, false);
    }

    public static void unmuteFeeds(final Context context, final Set<String> feedIds) {
        updateFeedActiveState(context, feedIds, true);
    }

    private static void updateFeedActiveState(final Context context, final Set<String> feedIds, final boolean active) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                Set<String> activeFeeds = dbHelper.getAllActiveFeeds();
                for (String feedId : feedIds) {
                    if (active) {
                        activeFeeds.add(feedId);
                    } else {
                        activeFeeds.remove(feedId);
                    }
                }

                ReadingAction ra = null;
                if (active) {
                    ra = ReadingAction.unmuteFeeds(activeFeeds, feedIds);
                } else {
                    ra = ReadingAction.muteFeeds(activeFeeds, feedIds);
                }

                dbHelper.enqueueAction(ra);
                ra.doLocal(dbHelper);

                NbActivity.updateAllActivities(NbActivity.UPDATE_METADATA);
                triggerSync(context);

                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

    public static void instaFetchFeed(Context context, String feedId) {
        ReadingAction ra = ReadingAction.instaFetch(feedId);
        dbHelper.enqueueAction(ra);
        ra.doLocal(dbHelper);
        NbActivity.updateAllActivities(NbActivity.UPDATE_METADATA);
        triggerSync(context);
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

    /**
     * Because story objects have to join on the feeds table to get feed metadata, there are times
     * where standalone stories are missing this info and it must be re-fetched.  This is costly
     * and should be avoided where possible.
     */
    public static String getFeedTitle(String feedId) {
        return getFeed(feedId).title;
    }

    public static Feed getFeed(String feedId) {
        return dbHelper.getFeed(feedId);
    }

    public static SocialFeed getSocialFeed(String feedId) {
        return dbHelper.getSocialFeed(feedId);
    }

}
