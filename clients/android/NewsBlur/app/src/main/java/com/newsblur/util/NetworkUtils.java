package com.newsblur.util;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Build;

import com.newsblur.di.ImageOkHttpClient;

import java.io.File;
import java.io.UnsupportedEncodingException;
import java.net.URL;
import java.net.URLEncoder;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

import okio.BufferedSink;
import okio.Okio;

public class NetworkUtils {

    private NetworkUtils() {} // util class - no instances

	public static boolean isOnline(Context context) {
		ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
		NetworkInfo netInfo = cm.getActiveNetworkInfo();
		return (netInfo != null && netInfo.isConnected());
	}

    public static long loadURL(@ImageOkHttpClient OkHttpClient imageOkHttpClient, URL url, File file) {
        long bytesRead = 0;
        try {
            Request.Builder requestBuilder = new Request.Builder().url(url);
            Response response = imageOkHttpClient.newCall(requestBuilder.build()).execute();
            if (response.isSuccessful()) {
                BufferedSink sink = Okio.buffer(Okio.sink(file));
                try {
                    bytesRead = sink.writeAll(response.body().source());
                } finally {
                    sink.close();
                    response.close();
                }
            }
        } catch (Throwable t) {
            Log.d("NetworkUtils.loadURL", t.getMessage());
            // a huge number of things could go wrong fetching and storing an image. don't spam logs with them
        }
        return bytesRead;
    }

    public static String encodeURL(String s) {
        try {
            return URLEncoder.encode(s, "UTF-8");
        } catch (UnsupportedEncodingException ueex) {
            android.util.Log.wtf("device does not support UTF-8", ueex);
            return null;
        }
    }

    public static String getCustomUserAgent(String appVersion) {
        return "NewsBlur Android app (" +
                Build.MANUFACTURER +
                " " +
                Build.MODEL +
                " " +
                Build.VERSION.RELEASE +
                " " +
                appVersion +
                ")";
    }

}
