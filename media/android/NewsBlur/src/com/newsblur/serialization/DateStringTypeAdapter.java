package com.newsblur.serialization;

import java.lang.reflect.Type;
import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;

import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonParseException;

public class DateStringTypeAdapter implements JsonDeserializer<Date> {
	// 2012-07-23 02:43:02
	private final DateFormat df = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

	@Override
	public Date deserialize(JsonElement element, Type type, JsonDeserializationContext arg2) throws JsonParseException {
			try {
				return df.parse(element.getAsString());
			} catch (ParseException e) {
				throw new JsonParseException(e);
			}
	}

}
