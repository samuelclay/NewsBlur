package com.newsblur.serialization;

import java.io.IOException;

import com.google.gson.TypeAdapter;
import com.google.gson.stream.JsonReader;
import com.google.gson.stream.JsonToken;
import com.google.gson.stream.JsonWriter;

/**
 * A more forgiving type adapter to deserialize JSON booleans. Specifically, this implementation is
 * friendly to backend code that may send numeric 0s and 1s for boolean fields, on which the strict
 * GSON base impl would choke.
 */
public class BooleanTypeAdapter extends TypeAdapter<Boolean> {

    @Override
    public Boolean read(JsonReader in) throws IOException {
        JsonToken type = in.peek();
        if (type == JsonToken.NULL) {
            in.nextNull();
            return null;
        } else if (type == JsonToken.BOOLEAN) {
            return in.nextBoolean();
        } else if (type == JsonToken.NUMBER) {
            return in.nextInt() > 0;
        } else if (type == JsonToken.STRING) {
            return Boolean.parseBoolean(in.nextString());
        } else {
            throw new IOException( "Could not parse JSON boolean." );
        }
    }

    @Override
    public void write(JsonWriter out, Boolean b) throws IOException{
        if (b == null) {
            out.nullValue();
        } else {
            out.value(b);
        }
    }

}
