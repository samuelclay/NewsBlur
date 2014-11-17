package com.newsblur.database;

import android.content.AsyncTaskLoader;
import android.content.Context;
import android.database.Cursor;
import android.os.CancellationSignal;
import android.os.Build;
import android.os.OperationCanceledException;

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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                if (isLoadInBackgroundCanceled()) {
                    throw new OperationCanceledException();
                }
                cancellationSignal = new CancellationSignal();
            }
        }
        try {
            Cursor c = createCursor();
            if (c != null) {
                c.getCount();
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
