package com.newsblur.domain;

import java.util.Date;

import android.content.ContentValues;
import android.database.Cursor;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class Reply {

    // new replies cannot possibly have the server-generated ID, so are inserted with partial info until reconciled
    public static final String PLACEHOLDER_COMMENT_ID = "__PLACEHOLDER_ID__";

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

    // not vended by API directly, but all replies come in the context of an enclosing comment
	public String commentId;

    // not vended by API, indicates this is a client-side placeholder for until we can get an ID from the server
    public boolean isPlaceholder = false;

	public ContentValues getValues() {
		ContentValues values = new ContentValues();
		values.put(DatabaseConstants.REPLY_DATE, date.getTime());
		values.put(DatabaseConstants.REPLY_SHORTDATE, shortDate);
		values.put(DatabaseConstants.REPLY_TEXT, text);
		values.put(DatabaseConstants.REPLY_COMMENTID, commentId);
		values.put(DatabaseConstants.REPLY_ID, id);
		values.put(DatabaseConstants.REPLY_USERID, userId);
		values.put(DatabaseConstants.REPLY_ISPLACEHOLDER, isPlaceholder ? "true" : "false");
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
		reply.isPlaceholder = Boolean.parseBoolean(cursor.getString(cursor.getColumnIndex(DatabaseConstants.REPLY_ISPLACEHOLDER)));
		return reply;	
	}

}
