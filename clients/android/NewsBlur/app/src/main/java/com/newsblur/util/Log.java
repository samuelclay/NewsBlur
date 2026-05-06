package com.newsblur.util;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Queue;
import java.util.TimeZone;
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
    private static final String LOG_NAME_ATTACHMENT = "logbuffer-email.txt";
    private static final int MAX_QUEUE_SIZE = 10;
    private static final int MAX_LINE_SIZE = 2 * 1024;
    private static final int TRIM_LINES = 1000;                 // trim the log down to 1000 lines
    private static final long MAX_SIZE = 2000L * MAX_LINE_SIZE; // when it is at least 2000 lines long

    private static final Object FILE_LOCK = new Object();
    private static Queue<String> q;
    private static ExecutorService executor;
    private static volatile File logloc = null;
    static {
        q = new ConcurrentLinkedQueue<String>();
        executor = Executors.newFixedThreadPool(1);
    }
    private static DateFormat dateFormat = null;
    static {
        dateFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
        dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
    }

    private Log() {} // util class - no instances

    public static void d(Object src, String m) {
        d(src.getClass().getName(), m);
    }

    public static void i(Object src, String m) {
        i(src.getClass().getName(), m);
    }

    public static void w(Object src, String m) {
        w(src.getClass().getName(), m);
    }

    public static void e(Object src, String m) {
        e(src.getClass().getName(), m);
    }

    public static void e(Object src, String m, Throwable t) {
        e(src.getClass().getName(), m, t);
    }

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
        if (q.size() < MAX_QUEUE_SIZE) {
            if (m != null && m.length() > MAX_LINE_SIZE) m = m.substring(0, MAX_LINE_SIZE);
            StringBuilder s = new StringBuilder();
            synchronized (dateFormat) {s.append(dateFormat.format(new Date()));}
            s.append(" ")
             .append(lvl)
             .append(tag)
             .append(" ");
            s.append(m);
            if (t != null) {
                s.append(" ");
                s.append(t.getMessage());
                s.append(" ");
                s.append(android.util.Log.getStackTraceString(t));
            }
            q.offer(s.toString());
        }
        Runnable r = Log::proc;
        executor.execute(r);
    }

    public static void offerContext(final Context c) {
        File cacheDir = c.getExternalCacheDir();
        if (cacheDir == null) cacheDir = c.getCacheDir();
        logloc = cacheDir;
        executor.execute(Log::proc);
    }

    private static void proc() {
        if (logloc == null) return; // not yet spun up
        synchronized (FILE_LOCK) {
            for (String line = q.poll(); line != null; line = q.poll()) {
                writeLine(line);
            }
        }
    }

    private static void writeLine(String line) {
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
        try {
            writeLatestLinesForAttachment(f, f, TRIM_LINES);
        } catch (Throwable t) {;}
    }

    static void writeLatestLinesForAttachment(File source, File target, int maxLines) throws IOException {
        List<String> lines = new ArrayList<String>(TRIM_LINES * 2);
        if (source.exists()) {
            try (BufferedReader r = new BufferedReader(new FileReader(source))) {
                for (String l = r.readLine(); l != null; l = r.readLine()) {
                    lines.add(l);
                }
            }
        }
        int offset = Math.max(0, lines.size() - maxLines);
        try (BufferedWriter w = new BufferedWriter(new FileWriter(target, false))) {
            for (int i = offset; i < lines.size(); i++) {
                w.append(lines.get(i));
                w.newLine();
            }
        }
    }

    public static File getLogfile() {
        if (logloc == null) return null;
        proc();
        synchronized (FILE_LOCK) {
            File source = new File(logloc, LOG_NAME_INTERNAL);
            File attachment = new File(logloc, LOG_NAME_ATTACHMENT);
            try {
                writeLatestLinesForAttachment(source, attachment, TRIM_LINES);
                return attachment;
            } catch (Throwable t) {
                return source;
            }
        }
    }

}
