package com.newsblur.service;

import static com.newsblur.service.NBSyncReceiver.UPDATE_STATUS;

import android.os.Process;

import com.newsblur.NbApplication;
import com.newsblur.util.AppConstants;
import com.newsblur.util.Log;

import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.RejectedExecutionException;

/**
 * A utility construct to make NbSyncService a bit more modular by encapsulating sync tasks
 * that can be run fully asynchronously from the main sync loop.  Like all of the sync service,
 * flags and data used by these modules need to be static so that parts of the app without a
 * handle to the service object can access them.
 */
public abstract class SubService {

    protected NBSyncService parent;
    private ThreadPoolExecutor executor;
    private long cycleStartTime = 0L;

    private SubService() {
        ; // no default construction
    }

    SubService(NBSyncService parent) {
        this.parent = parent;
        executor = new ThreadPoolExecutor(1, 1, 0L, TimeUnit.MILLISECONDS, new LinkedBlockingQueue<Runnable>());
    }

    public void start() {
        Runnable r = new Runnable() {
            public void run() {
                if (parent.stopSync()) return;
                if (!NbApplication.isAppForeground()) {
                    Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND + Process.THREAD_PRIORITY_LESS_FAVORABLE );
                } else {
                    Process.setThreadPriority(Process.THREAD_PRIORITY_DEFAULT + Process.THREAD_PRIORITY_LESS_FAVORABLE + Process.THREAD_PRIORITY_LESS_FAVORABLE );
                }
                Thread.currentThread().setName(this.getClass().getName());
                exec_();
            }
        };
        try {
            executor.execute(r);
            // enqueue a check task that will run strictly after the real one, so the callback
            // can effectively check queue size to see if there are queued tasks
            executor.execute(new Runnable() {
                public void run() {
                    parent.checkCompletion();
                    parent.sendSyncUpdate(UPDATE_STATUS);
                }
            });
        } catch (RejectedExecutionException ree) {
            // this is perfectly normal, as service soft-stop mechanics might have shut down our thread pool
            // while peer subservices are still running
        }
    }

    private synchronized void exec_() {
        try {
            exec();
            cycleStartTime = 0;
        } catch (Exception e) {
            com.newsblur.util.Log.e(this.getClass().getName(), "Sync error.", e);
        } 
    }

    protected abstract void exec();

    public void shutdown() {
        Log.d(this, "SubService stopping");
        executor.shutdown();
        try {
            executor.awaitTermination(AppConstants.SHUTDOWN_SLACK_SECONDS, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        } finally {
            Log.d(this, "SubService stopped");
        }
    }

    public boolean isRunning() {
        // don't advise completion until there are no tasks, or just one check task left
        return (executor.getQueue().size() > 0);
    }

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

        if (NbApplication.isAppForeground()) {
            com.newsblur.util.Log.d(this.getClass().getName(), "Sleeping for : " + cooloffTimeMs + "ms to enforce max duty cycle.");
            try {
                Thread.sleep(cooloffTimeMs);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }



}
        
