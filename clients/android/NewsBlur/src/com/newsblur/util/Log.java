package com.newsblur.util;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.util.ArrayList;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;

import android.content.Context;

/**
 * A low-overhead, fail-fast, dependency-free, file-backed log collector.  This utility
 * will persist debug messages in a file in such a way that sacrifices any guarantees
 * in order to have as few side-effects as possible.  The resulting log file will have
 * as many of the messages sent here as possible, but should not be expected to have
 * all of them.  The file is trimmed down to a set number of lines if it grows too big.
 */
public class Log {

    private static final String D = "DEBUG ";
    private static final String I = "INFO  ";
    private static final String W = "WARN  ";
    private static final String E = "ERROR ";

    private static final String LOG_NAME_INTERNAL = "logbuffer.txt";
    private static final int MAX_LINE_SIZE = 4 * 1024;
    private static final int TRIM_LINES = 256;                 // trim the log down to 256 lines
    private static final long MAX_SIZE = 512L * MAX_LINE_SIZE; // when it is at least 512 lines long

    private static Queue<String> q;
    private static ExecutorService executor;
    private static File logloc = null;
    static {
        q = new ConcurrentLinkedQueue<String>();
        executor = Executors.newFixedThreadPool(1);
    }

    private Log() {} // util class - no instances

    public static void d(String tag, String m) {
        if (AppConstants.VERBOSE_LOG) android.util.Log.d(tag, m);
        add(D, tag, m, null);
    }

    public static void i(String tag, String m) {
        android.util.Log.i(tag, m);
        add(I, tag, m, null);
    }

    public static void w(String tag, String m) {
        android.util.Log.w(tag, m);
        add(W, tag, m, null);
    }

    public static void e(String tag, String m) {
        android.util.Log.e(tag, m);
        add(E, tag, m, null);
    }

    public static void e(String tag, String m, Throwable t) {
        android.util.Log.e(tag, m, t);
        add(E, tag, m, t);
    }

    private static void add(String lvl, String tag, String m, Throwable t) {
        if (q.size() > TRIM_LINES) return;
        if (m != null && m.length() > MAX_LINE_SIZE) m = m.substring(0, MAX_LINE_SIZE);
        StringBuilder s = new StringBuilder();
        s.append(Long.toString(System.currentTimeMillis()))
         .append(" ")
         .append(lvl)
         .append(tag)
         .append(" ");
        if (t != null) {
            s.append(t.getMessage());
            s.append(" ");
        }
        s.append(m);
        q.offer(s.toString());
        Runnable r = new Runnable() {
            public void run() {
                proc();
            }
        };
        executor.execute(r);
    }

    public static void offerContext(Context c) {
        logloc = c.getExternalCacheDir();
    }

    private static void proc() {
        synchronized (q) {
            if (logloc == null) return; // not yet spun up
            String line = q.poll();
            if (line == null) return;
            File f = new File(logloc, LOG_NAME_INTERNAL);
            try (BufferedWriter w = new BufferedWriter(new FileWriter(f, true))) {
                w.append(line);
                w.newLine();
            } catch (Throwable t) {
                ; // explicitly do nothing, log nothing, and fail fast. this is a utility to
                  // provice as much info as possible while having absolute minimal impact or
                  // side effect on performance or app operation
            }
            if (f.length() < MAX_SIZE) return;
            android.util.Log.i(Log.class.getName(), "trimming");
            List<String> lines = new ArrayList<String>(TRIM_LINES * 2);
            try (BufferedReader r = new BufferedReader(new FileReader(f))) {
                for (String l = r.readLine(); l != null; l = r.readLine()) {
                    lines.add(l);
                }
            } catch (Throwable t) {;}
            int offset = lines.size() - TRIM_LINES;
            try (BufferedWriter w = new BufferedWriter(new FileWriter(f, false))) {
                for (int i = offset; i < lines.size(); i++) {
                    w.append(lines.get(i));
                    w.newLine();
                }
            } catch (Throwable t) {;}
        }
    }

    public static File getLogfile() {
        return new File(logloc, LOG_NAME_INTERNAL);
    }

}

