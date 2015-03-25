package com.newsblur.util;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;

import com.squareup.okhttp.OkHttpClient;
import com.squareup.okhttp.Request;
import com.squareup.okhttp.Response;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URL;
import java.util.concurrent.TimeUnit;

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

    public static int loadURL(URL url, OutputStream outputStream) throws IOException {
        int bytesRead = 0;
        try {
            Request.Builder requestBuilder = new Request.Builder().url(url);
            Response response = httpClient.newCall(requestBuilder.build()).execute();
            if (response.isSuccessful()) {
                InputStream inputStream = response.body().byteStream();
                byte[] b = new byte[1024];
                int read;
                while ((read = inputStream.read(b)) != -1) {
                    outputStream.write(b, 0, read);
                    bytesRead += read;
                }
            }

        } catch (Throwable t) {
            // a huge number of things could go wrong fetching and storing an image. don't spam logs with them
        }
        return bytesRead;
    }
}
