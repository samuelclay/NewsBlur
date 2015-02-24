package com.newsblur.util;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.util.Log;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public class NetworkUtils {
	
	public static boolean isOnline(Context context) {
		ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
		NetworkInfo netInfo = cm.getActiveNetworkInfo();
		return (netInfo != null && netInfo.isConnected());
	}

    /**
     * Attempt to load the given image URL into the (probably file-backed) output stream.
     * 
     * @return a new URL if a non-followable redirect was encountered or null if successful.
     */
    public static String loadURL(URL url, OutputStream outputStream) throws IOException {
        HttpURLConnection conn = null;
        try {
            conn = (HttpURLConnection)url.openConnection();
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(30000);
            conn.setInstanceFollowRedirects(true);
            int code = conn.getResponseCode();
            // we explicitly requested redirects, so if we still get one, it is because of a protocol
            // change. inform the caller by returning the new URL
            if ((code == HttpURLConnection.HTTP_MOVED_TEMP) || (code == HttpURLConnection.HTTP_MOVED_PERM)) {
                String loc = conn.getHeaderField("Location");
                return loc;
            }
            InputStream inputStream = conn.getInputStream();
            byte[] b = new byte[1024];
            int read;
            while ((read = inputStream.read(b)) != -1) {
                outputStream.write(b, 0, read);
            }
            return null;
        } catch (Throwable t) {
            // a huge number of things could go wrong fetching and storing an image. don't spam logs with them
            return null;
        } finally {
            closeQuietly(conn);
        }
    }

    public static void closeQuietly(HttpURLConnection conn) {
        if (conn == null) return;
        try {
            conn.disconnect();
        } catch (Throwable t) {
        }
    }

}
