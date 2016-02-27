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
    private long cycleStartTime = 0L;

    private SubService() {
        ; // no default construction
    }

    SubService(NBSyncService parent) {
        this.parent = parent;
        executor = Executors.newFixedThreadPool(1);
    }

    public void start(final int startId) {
        parent.incrementRunningChild();
        this.startId = startId;
        Runnable r = new Runnable() {
            public void run() {
                if (NbActivity.getActiveActivityCount() < 1) {
                    Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND + Process.THREAD_PRIORITY_LESS_FAVORABLE );
                } else {
                    Process.setThreadPriority(Process.THREAD_PRIORITY_DEFAULT + Process.THREAD_PRIORITY_LESS_FAVORABLE + Process.THREAD_PRIORITY_LESS_FAVORABLE );
                }
                Thread.currentThread().setName(this.getClass().getName());
                exec_();
                parent.decrementRunningChild(startId);
            }
        };
        executor.execute(r);
    }

    private synchronized void exec_() {
        try {
            //if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "SubService started");
            exec();
            //if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "SubService completed");
            cycleStartTime = 0;
        } catch (Exception e) {
            Log.e(this.getClass().getName(), "Sync error.", e);
        } finally {
            if (isRunning()) {
                setRunning(false);
                NbActivity.updateAllActivities(NbActivity.UPDATE_STATUS);
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
        NbActivity.updateAllActivities(NbActivity.UPDATE_STATUS);
    }

    protected void gotData(int updateType) {
        NbActivity.updateAllActivities(updateType);
    }

    protected abstract void setRunning(boolean running);
    protected abstract boolean isRunning();

    /**
     * If called at the beginning of an expensive loop in a SubService, enforces the maximum duty cycle
     * defined in AppConstants by sleeping for a short while so the SubService does not dominate system
     * resources.
     */
    protected void startExpensiveCycle() {
        if (cycleStartTime == 0) {
            cycleStartTime = System.nanoTime();
            return;
        }

        double lastCycleTime = (System.nanoTime() - cycleStartTime);
        if (lastCycleTime < 1) return;

        cycleStartTime = System.nanoTime();

        double cooloffTime = lastCycleTime * (1.0 - AppConstants.MAX_BG_DUTY_CYCLE);
        if (cooloffTime < 1) return;
        long cooloffTimeMs = Math.round(cooloffTime / 1000000.0);
        if (cooloffTimeMs > AppConstants.DUTY_CYCLE_BACKOFF_CAP_MILLIS) cooloffTimeMs = AppConstants.DUTY_CYCLE_BACKOFF_CAP_MILLIS;

        if (NbActivity.getActiveActivityCount() > 0 ) {
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "Sleeping for : " + cooloffTimeMs + "ms to enforce max duty cycle.");
            try {
                Thread.sleep(cooloffTimeMs);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }



}
        
