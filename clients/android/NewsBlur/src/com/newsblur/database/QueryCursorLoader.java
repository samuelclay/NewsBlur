package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.os.CancellationSignal;
import android.os.OperationCanceledException;
import android.support.v4.content.AsyncTaskLoader;

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
        Cursor oldCursor = this.cursor;
        this.cursor = cursor;
        if (isStarted()) {
            super.deliverResult(cursor);
        }
        if (oldCursor != null && oldCursor != this.cursor && !oldCursor.isClosed()) {
            oldCursor.close();
        }
    } 

    @Override
    protected void onStartLoading() {
        if (cursor != null) {
            // if we already have a cursor and haven't been reset, use it!
            deliverResult(cursor);
        }
        // if we had nothing or have a pending change, reload
        if ((cursor == null) || takeContentChanged()) {
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
        clearCursor();
    }

    @Override
    protected void onReset() {
        super.onReset();
        onStopLoading();
        // note that the stock CursorLoader here closes the cursor early rather than waiting for the
        // rest of the reset->stop->cancel->cancelled cycle, which can cause contexts to briefly have
        // a closed cursor but no replacement.
    }

    private void clearCursor() {
        if (cursor != null && !cursor.isClosed()) {
            cursor.close();
        }
        cursor = null;
    }

}
