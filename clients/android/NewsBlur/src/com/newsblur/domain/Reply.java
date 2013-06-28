package com.newsblur.domain;

import java.util.Date;

import android.content.ContentValues;
import android.database.Cursor;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class Reply {
	@SerializedName("reply_id")
	public String id;

	@SerializedName("user_id")
	public String userId;

	@SerializedName("publish_date")
	public String shortDate; 

	@SerializedName("comments")
	public String text;

	@SerializedName("date")
	public Date date;

	public String commentId;

	public ContentValues getValues() {
		ContentValues values = new ContentValues();
		values.put(DatabaseConstants.REPLY_DATE, date.getTime());
		values.put(DatabaseConstants.REPLY_SHORTDATE, shortDate);
		values.put(DatabaseConstants.REPLY_TEXT, text);
		values.put(DatabaseConstants.REPLY_COMMENTID, commentId);
		values.put(DatabaseConstants.REPLY_ID, id);
		values.put(DatabaseConstants.REPLY_USERID, userId);
		return values;	
	}

	public static Reply fromCursor(Cursor cursor) {
		Reply reply = new Reply();
		reply.date = new Date(cursor.getLong(cursor.getColumnIndex(DatabaseConstants.REPLY_DATE))); 
		reply.shortDate = cursor.getString(cursor.getColumnIndex(DatabaseConstants.REPLY_SHORTDATE));
		reply.text = cursor.getString(cursor.getColumnIndex(DatabaseConstants.REPLY_TEXT));
		reply.commentId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.REPLY_COMMENTID));
		reply.id = cursor.getString(cursor.getColumnIndex(DatabaseConstants.REPLY_ID));
		reply.userId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.REPLY_USERID));
		return reply;	
	}
}