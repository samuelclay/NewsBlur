#!/usr/bin/env ruby
# test_folder_identity.rb inserts Folder.java values into its compiled SQLite schema, including colliding display paths.
require 'json'
require 'open3'
require 'tmpdir'
require 'fileutils'

android = File.expand_path('../../NewsBlur', __dir__)
classes = File.join(android, 'app/build/intermediates/javac/debug/compileDebugJavaWithJavac/classes')
gson = Dir[File.join(Dir.home, '.gradle/caches/modules-2/files-2.1/com.google.code.gson/gson/**/*.jar')]
  .reject { |path| path.match?(/-(sources|javadoc)\.jar$/) }.sort.last
android_jar = Dir[File.join(Dir.home, 'Library/Android/sdk/platforms/android-*/android.jar')].sort.last
abort 'Compile debug Java classes first and cache Gson plus the Android SDK.' unless File.directory?(classes) && gson && android_jar
java_home = ENV.fetch('JAVA_HOME', '/Applications/Android Studio.app/Contents/jbr/Contents/Home')

Dir.mktmpdir('folder-identity') do |dir|
  package_dir = File.join(dir, 'android/content')
  FileUtils.mkdir_p(package_dir)
  content_values = File.join(package_dir, 'ContentValues.java')
  File.write(content_values, <<~JAVA)
    package android.content;
    public class ContentValues {
      public final java.util.Map<String, String> values = new java.util.LinkedHashMap<>();
      public void put(String key, String value) { values.put(key, value); }
    }
  JAVA
  _, error, status = Open3.capture3(File.join(java_home, 'bin/javac'), '-d', dir, content_values)
  abort error unless status.success?

  source = File.join(dir, 'DumpFolderValues.java')
  File.write(source, <<~JAVA)
    import java.lang.reflect.Field;
    import java.util.List;
    import com.newsblur.domain.Folder;
    public class DumpFolderValues {
      public static void main(String[] args) throws Exception {
        Field schema = Class.forName("com.newsblur.database.DatabaseConstants").getDeclaredField("FOLDER_SQL");
        schema.setAccessible(true);
        var result = new java.util.LinkedHashMap<String, Object>();
        result.put("schema", schema.get(null));
        Folder literal = new Folder(); literal.name = "A ▸ B"; literal.feedIds = List.of("1");
        Folder nested = new Folder(); nested.name = "B"; nested.parents = List.of("A"); nested.feedIds = List.of("2");
        Folder escaped = new Folder(); escaped.name = "Quotes \\\" and \\\\ slash"; escaped.feedIds = List.of("3");
        result.put("rows", List.of(literal.getValues().values, nested.getValues().values, escaped.getValues().values));
        System.out.print(new com.google.gson.Gson().toJson(result));
      }
    }
  JAVA
  output, error, status = Open3.capture3(File.join(java_home, 'bin/java'), '--class-path',
    [dir, classes, gson, android_jar].join(File::PATH_SEPARATOR), source)
  abort error unless status.success?
  fixture = JSON.parse(output)
  quote = ->(value) { "'#{value.gsub("'", "''")}'" }
  inserts = fixture.fetch('rows').map do |row|
    "INSERT INTO folders (#{row.keys.join(',')}) VALUES (#{row.values.map(&quote).join(',')});"
  end
  sql = ([".bail on", fixture.fetch('schema') + ';'] + inserts + [
    "SELECT count(*) FROM folders;",
    "SELECT count(*) FROM folders WHERE folder_path = 'A ▸ B';",
    "SELECT folder_feedids FROM folders WHERE folder_name = 'B';",
  ]).join("\n")
  output, error, status = Open3.capture3('sqlite3', ':memory:', stdin_data: sql)
  abort "FAIL: SQLite folder round trip: #{error}" unless status.success?
  abort "FAIL: Unexpected rows #{output.inspect}" unless output.lines.map(&:strip) == ['3', '2', '["2"]']
  puts 'PASS: SQLite preserves both identical display paths and their distinct feeds, including escaped folder names.'
end
