package com.newsblur.util;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;

import com.squareup.okhttp.OkHttpClient;
import com.squareup.okhttp.Request;
import com.squareup.okhttp.Response;

import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.util.concurrent.TimeUnit;

import okio.BufferedSink;
import okio.Okio;

public class NetworkUtils {

    private static OkHttpClient httpClient = new OkHttpClient();

    static {
        // By default OkHttpClient follows redirects (inc HTTP -> HTTPS and HTTPS -> HTTP).
        httpClient.setConnectTimeout(10, TimeUnit.SECONDS);
        httpClient.setReadTimeout(30, TimeUnit.SECONDS);
    }

	public static boolean isOnline(Context context) {
		ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
		NetworkInfo netInfo = cm.getActiveNetworkInfo();
		return (netInfo != null && netInfo.isConnected());
	}

    public static long loadURL(URL url, File file) throws IOException {
        long bytesRead = 0;
        try {
            Request.Builder requestBuilder = new Request.Builder().url(url);
            Response response = httpClient.newCall(requestBuilder.build()).execute();
            if (response.isSuccessful()) {
                BufferedSink sink = Okio.buffer(Okio.sink(file));
                bytesRead = sink.writeAll(response.body().source());
                sink.close();
            }
        } catch (Throwable t) {
            // a huge number of things could go wrong fetching and storing an image. don't spam logs with them
        }
        return bytesRead;
    }
}
