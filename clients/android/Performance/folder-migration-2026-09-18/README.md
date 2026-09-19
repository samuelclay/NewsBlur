# Folder database migration regression

PR #2139 review identified a valid version 6 cache containing both a top-level folder named `A ▸ B` and a folder `B` inside `A`. Both produce the display path `A ▸ B`, so using that display path as a database primary key made the upgrade throw a uniqueness error. `Folder.equals()` also conflated these folders when parsing the server response.

The database now uses a separate JSON array of exact path segments as its primary key. Display paths, folder names, parent lists, and API strings remain unchanged. Database version 9 migrates existing versions 6, 7, and 8 while preserving the other cached tables and queued actions. Equality and hashing use the same segment identity, so the parser retains both folders.

Validation:

- Before the fix, `Test_FolderMigration.test_version_six_migration_preserves_distinct_folders_with_the_same_display_path` failed with `UNIQUE constraint failed: folders.folder_path (A ▸ B)`. The parser regression retained one folder instead of two.
- After the fix, all 15 focused migration, hierarchy/parser, and folder API tests pass.
- `test_folder_identity.rb` uses the compiled production `Folder.getValues()` and database schema with an isolated real SQLite database. It reproduced the same uniqueness failure before the fix, then verified both display paths and their distinct feed memberships after the fix, including names containing quotes and backslashes.
- The SQLite fixture does not open or alter the connected phone's database.

Run from `clients/android/NewsBlur`:

```sh
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest --tests 'com.newsblur.database.Test_FolderMigration' --tests 'com.newsblur.domain.FolderHierarchyTest' --tests 'com.newsblur.network.FolderApiPathTest'
ruby ../Performance/folder-migration-2026-09-18/test_folder_identity.rb
```
