package com.newsblur.view;

import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.text.TextUtils;
import android.util.Base64;
import android.view.View;
import android.widget.ImageView;
import android.widget.SimpleCursorTreeAdapter.ViewBinder;

import com.newsblur.database.DatabaseConstants;

public class FolderTreeViewBinder implements ViewBinder {

	@Override
	public boolean setViewValue(View view, Cursor cursor, int columnIndex) {
		if (TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.FEED_FAVICON) && cursor.getBlob(columnIndex) != null) {
			final byte[] data = Base64.decode(cursor.getBlob(columnIndex), Base64.DEFAULT);
			Bitmap bitmap = BitmapFactory.decodeByteArray(data, 0, data.length);
			((ImageView) view).setImageBitmap(bitmap);
			return true;
		}
		return false;
	}

}
