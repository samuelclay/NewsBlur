package com.newsblur.util;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;

import java.net.HttpURLConnection;

public class NetworkUtils {
	
	public static boolean isOnline(Context context) {
		ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
		NetworkInfo netInfo = cm.getActiveNetworkInfo();
		if (netInfo != null && netInfo.isConnectedOrConnecting()) {
			return true;
		}
		return false;
	}

    public static void closeQuietly(HttpURLConnection conn) {
        if (conn == null) return;
        try {
            conn.disconnect();
        } catch (Throwable t) {
        }
    }

}
