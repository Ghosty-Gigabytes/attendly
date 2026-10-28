package dev.attendly.server;
import java.util.*;
import tools.jackson.databind.json.JsonMapper;
final class Json {
 static final JsonMapper MAPPER = JsonMapper.builder().build();
 static String write(Object value) { return MAPPER.writeValueAsString(value); }
 @SuppressWarnings("unchecked") static Map<String,Object> read(String value) { return MAPPER.readValue(value, Map.class); }
}
