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
 * contraindicated. (Why this isn't in core Android I will never understand)
 */
public abstract class QueryCursorLoader extends AsyncTaskLoader<Cursor> {

    private Cursor cursor;
    protected CancellationSignal cancellationSignal;

    public QueryCursorLoader(Context context) {
        super(context);
    }

    protected abstract Cursor createCursor();

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
            if (AppConstants.VERBOSE_LOG_DB) {
                long time = System.nanoTime() - startTime;
                Log.d(this.getClass().getName(), "cursor load: " + (time/1000000L) + "ms to load " + count + " rows");
            }
            return c;
        } finally {
            synchronized (this) {
                cancellationSignal = null;
            }
        }
    }

    @Override
    public void cancelLoadInBackground() {
        super.cancelLoadInBackground();
        synchronized (this) {
            if (cancellationSignal != null) {
                cancellationSignal.cancel();
            }
        }
    }

    @Override
    public void deliverResult(Cursor cursor) {
        if (isReset()) {
            if (cursor != null) {
                cursor.close();
            }
            return;
        }
        Cursor oldCursor = cursor;
        cursor = cursor;
        if (isStarted()) {
            super.deliverResult(cursor);
        }
        if (oldCursor != null && oldCursor != cursor && !oldCursor.isClosed()) {
            oldCursor.close();
        }
    } 

    @Override
    protected void onStartLoading() {
        if (cursor != null) {
            deliverResult(cursor);
        }
        if (takeContentChanged() || cursor == null) {
            forceLoad();
        }
    }

    @Override
    protected void onStopLoading() {
        cancelLoad();
    }

    @Override
    public void onCanceled(Cursor cursor) {
        if (cursor != null && !cursor.isClosed()) {
            cursor.close();
        }
    }

    @Override
    protected void onReset() {
        super.onReset();
        onStopLoading();
        if (cursor != null && !cursor.isClosed()) {
            cursor.close();
        }
        cursor = null;
    }

}
