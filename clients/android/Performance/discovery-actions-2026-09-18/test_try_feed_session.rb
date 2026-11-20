#!/usr/bin/env ruby
# test_try_feed_session.rb executes the compiled DatabaseConstants.java SQL against an isolated SQLite fixture.
# Run after :app:testDebugUnitTest (or compileDebugJavaWithJavac); requires the JDK and sqlite3 already used locally.
require 'json'
require 'open3'
require 'tmpdir'

android = File.expand_path('../../NewsBlur', __dir__)
classes = File.join(android, 'app/build/intermediates/javac/debug/compileDebugJavaWithJavac/classes')
gson = Dir[File.join(Dir.home, '.gradle/caches/modules-2/files-2.1/com.google.code.gson/gson/**/*.jar')]
  .reject { |path| path.match?(/-(sources|javadoc)\.jar$/) }.sort.last
abort 'Compile the debug Java classes first and ensure the Gradle Gson dependency is cached.' unless File.directory?(classes) && gson
java_home = ENV.fetch('JAVA_HOME', '/Applications/Android Studio.app/Contents/jbr/Contents/Home')

Dir.mktmpdir('try-feed-session') do |dir|
  source = File.join(dir, 'DumpSessionSql.java')
  File.write(source, <<~JAVA)
    import java.lang.reflect.Field;
    import java.util.LinkedHashMap;
    public class DumpSessionSql {
      public static void main(String[] args) throws Exception {
        Class<?> constants = Class.forName("com.newsblur.database.DatabaseConstants");
        var values = new LinkedHashMap<String, String>();
        for (String name : new String[]{"STORY_SQL", "FEED_SQL", "READING_SESSION_SQL", "SESSION_STORY_QUERY_BASE", "SINGLE_FEED_SESSION_STORY_QUERY"}) {
          Field field;
          try { field = constants.getDeclaredField(name); }
          catch (NoSuchFieldException baseline) { field = constants.getDeclaredField("SESSION_STORY_QUERY_BASE"); }
          field.setAccessible(true);
          values.put(name, (String)field.get(null));
        }
        System.out.print(new com.google.gson.Gson().toJson(values));
      }
    }
  JAVA
  stdout, stderr, status = Open3.capture3(File.join(java_home, 'bin/java'), '--class-path', [classes, gson].join(File::PATH_SEPARATOR), source)
  abort stderr unless status.success?
  values = JSON.parse(stdout)
  schema = %w[STORY_SQL FEED_SQL READING_SESSION_SQL].map { |key| "#{values.fetch(key)};" }.join("\n")
  fixture = <<~SQL
    #{schema}
    INSERT INTO stories (story_hash, feed_id, title, timestamp) VALUES ('42:first', 42, 'First', 200), ('42:second', 42, 'Second', 100);
    INSERT INTO reading_session (session_story_hash) VALUES ('42:first'), ('42:second');
  SQL
  single = values.fetch('SINGLE_FEED_SESSION_STORY_QUERY')
  broader = values.fetch('SESSION_STORY_QUERY_BASE')
  cases = {
    'preview without feed metadata returns both stories' => [fixture, "SELECT count(*) FROM (#{single});", '2'],
    'preview query does not create a subscription record' => [fixture, "#{single}; SELECT count(*) FROM feeds;", '0'],
    'broader queries still require feed metadata' => [fixture, "SELECT count(*) FROM (#{broader});", '0'],
    'subscribed single-feed query keeps the title and both stories' => [fixture + "INSERT INTO feeds (_id, feed_name) VALUES (42, 'Subscribed feed');", "SELECT count(*) FROM (#{single}) WHERE feed_name = 'Subscribed feed';", '2'],
    'subscribed broader query retains both stories' => [fixture + "INSERT INTO feeds (_id, feed_name) VALUES (42, 'Subscribed feed');", "SELECT count(*) FROM (#{broader});", '2'],
  }
  failures = cases.filter_map do |name, (setup, query, expected)|
    output, error, result = Open3.capture3('sqlite3', ':memory:', stdin_data: "#{setup}\n#{query}\n")
    actual = output.lines.last&.strip
    if result.success? && actual == expected
      puts "PASS: #{name}"
      nil
    else
      "FAIL: #{name}: expected #{expected.inspect}, got #{actual.inspect} #{error}"
    end
  end
  abort failures.join("\n") unless failures.empty?
end
