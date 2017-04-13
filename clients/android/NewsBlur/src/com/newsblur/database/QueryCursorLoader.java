package com.newsblur.database;

import android.content.AsyncTaskLoader;
import android.content.Context;
import android.database.Cursor;
import android.os.CancellationSignal;
import android.os.OperationCanceledException;
import android.util.Log;

import com.newsblur.util.AppConstants;

/**
 * A partial copy of android.content.CursorLoader with the bits related to ContentProviders
 * gutted out so plain old SQLiteDatabase queries can be used where a ContentProvider is
 * contraindicated. (Why this isn't in core Android I will never understand) Also fixes
 * several bugs with how LoaderManagers interact with AsyncTaskLoaders on several platforms.
 */
public abstract class QueryCursorLoader extends AsyncTaskLoader<Cursor> {

    // we hold onto a copy of any cursor vended so we can auto-close it, per the contract of a Loader
    private Cursor cursor;
    // we create and manage a cancellation hook since SQLite support it and it lets us quickly catch up when behind
    protected CancellationSignal cancellationSignal;

    public QueryCursorLoader(Context context) {
        super(context);
    }

    /**
     * Subclasses (generally anonymous) must actually provide the code to load the cursor, we just
     * handly lifecyle management.
     */
    protected abstract Cursor createCursor();

    // this is the method that AsyncTaskLoader actually calls to the the data object
    @Override
    public Cursor loadInBackground() {
        synchronized (this) {
            if (isLoadInBackgroundCanceled()) {
                throw new OperationCanceledException();
            }
            cancellationSignal = new CancellationSignal();
        }
        try {
            long startTime = System.nanoTime();
            int count = -1;
            Cursor c = createCursor();
            if (c != null) {
                // this call to getCount is *not* just for the instrumentation, it ensures the cursor is fully ready before
                // being called back.  if the instrumentation is ever removed, do not remove this call.
                count = c.getCount();
            }
            if (AppConstants.VERBOSE_LOG) {
                long time = System.nanoTime() - startTime;
                com.newsblur.util.Log.d(this.getClass().getName(), "cursor load: " + (time/1000000L) + "ms to load " + count + " rows");
            }
            return c;
        } finally {
            synchronized (this) {
                cancellationSignal = null;
            }
        }
    }

    // this is a hook to try and actively cancel an in-flight load. cancellation flagging is handled elsewhere
    @Override
    public void cancelLoadInBackground() {
        super.cancelLoadInBackground();
        synchronized (this) {
            if (cancellationSignal != null) {
                cancellationSignal.cancel();
                cancellationSignal = null;
            }
        }
    }

    // a hook for when data are delivered that lets us snag a copy so we can manage it
    @Override
    public void deliverResult(Cursor cursor) {
        if (isReset()) {
        clearCursor();
            return;
        }
        if (this.cursor != cursor) {
            clearCursor();
        }
        this.cursor = cursor;
        if (isStarted()) {
            super.deliverResult(cursor);
        }
    } 

    @Override
    protected void onStartLoading() {
        if (cursor != null) {
            // if we already have a cursor and haven't been reset, use it!
            deliverResult(cursor);
        } else {
            takeContentChanged();
            forceLoad();
        }
    }

    @Override
    protected void onStopLoading() {
        // not that we do *not* clear data in this hook. the framework may tell us to stop loading
        // but still request our data later.  this isn't a reset.
        cancelLoad();
    }

    @Override
    public void onCanceled(Cursor cursor) {
        // many some other loaders mysteriously deliver results when they are cancelled and
        // *very importantly*, some LoaderManager implementations rely upon this fact. do not
        // remove this seemingly incorrect side-effect without rigorously testing many combinations
        // of LoaderManager call patterns on all supported platforms.
        // not that this may also require double-checking that adapters close cursors to prevent
        // cursor leakage
        if (cursor != null) {
            deliverResult(cursor);
        }
    }

    @Override
    protected void onReset() {
        super.onReset();
        clearCursor();
    }

    private void clearCursor() {
        if (cursor != null && !cursor.isClosed()) {
            cursor.close();
        }
        cursor = null;
    }

}
