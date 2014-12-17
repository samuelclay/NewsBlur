package com.newsblur.service;

import android.os.Process;
import android.util.Log;

import com.newsblur.activity.NbActivity;
import com.newsblur.util.AppConstants;

import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * A utility construct to make NbSyncService a bit more modular by encapsulating sync tasks
 * that can be run fully asynchronously from the main sync loop.  Like all of the sync service,
 * flags and data used by these modules need to be static so that parts of the app without a
 * handle to the service object can access them.
 */
public abstract class SubService {

    protected NBSyncService parent;
    private ExecutorService executor;
    protected int startId;

    private SubService() {
        ; // no default construction
    }

    SubService(NBSyncService parent) {
        this.parent = parent;
        executor = Executors.newFixedThreadPool(1);
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "SubService created");
    }

    public void start(final int startId) {
        this.startId = startId;
        Runnable r = new Runnable() {
            public void run() {
                parent.incrementRunningChild();
                if (NbActivity.getActiveActivityCount() < 1) {
                    Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND + Process.THREAD_PRIORITY_LESS_FAVORABLE );
                } else {
                    Process.setThreadPriority(Process.THREAD_PRIORITY_DEFAULT + Process.THREAD_PRIORITY_LESS_FAVORABLE + Process.THREAD_PRIORITY_LESS_FAVORABLE );
                }
                exec_();
                parent.decrementRunningChild(startId);
            }
        };
        executor.execute(r);
    }

    private synchronized void exec_() {
        try {
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "SubService started");
            exec();
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "SubService completed");
        } catch (Exception e) {
            Log.e(this.getClass().getName(), "Sync error.", e);
        } finally {
            if (isRunning()) {
                setRunning(false);
                NbActivity.updateAllActivities(false);
            }
        }
    }

    protected abstract void exec();

    public void shutdown() {
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "SubService stopping");
        executor.shutdown();
        try {
            executor.awaitTermination(AppConstants.SHUTDOWN_SLACK_SECONDS, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        } finally {
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "SubService stopped");
        }
    }

    protected void gotWork() {
        setRunning(true);
        NbActivity.updateAllActivities(false);
    }

    protected void gotData() {
        NbActivity.updateAllActivities(true);
    }

    protected abstract void setRunning(boolean running);
    protected abstract boolean isRunning();

}
        
