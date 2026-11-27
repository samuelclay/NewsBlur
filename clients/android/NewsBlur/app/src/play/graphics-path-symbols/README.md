# AndroidX graphics-path native debug symbols

Google Maven distributes four stripped copies of `libandroidx.graphics.path.so` in `androidx.graphics:graphics-path:1.0.1`. The Play release uses each companion for its matching ABI. The SHA-256 of each shipping library and its companion are recorded in [checksums.properties](checksums.properties).

The source is the `graphics/graphics-path` module at AndroidX commit `56a7bc0fd3521a28152fb509a3a745ff5a67daab`. The regeneration script checks the Git tree object for the source and the SHA-256 for the published AAR. The native source is copyright 2006, 2013, 2017 and 2022 The Android Open Source Project and is distributed under the [Apache License 2.0](LICENSE.txt). [Source](https://android.googlesource.com/platform/frameworks/support/+/56a7bc0fd3521a28152fb509a3a745ff5a67daab/graphics/graphics-path/) · [Google Maven AAR](https://dl.google.com/dl/android/maven2/androidx/graphics/graphics-path/1.0.1/graphics-path-1.0.1.aar)

## Regenerate

The verified toolchain uses Android NDK r25c (25.2.9519653), Android SDK CMake 3.22.1, and llvm-dwarfutil 23.1.5. The latter removes debug entries for functions discarded by the release linker. Run with Ruby, Git, curl, tar and unzip installed. Set `ANDROID_HOME` to the SDK directory. Set `LLVM_DWARFUTIL` to the executable if it is outside your PATH.

```sh
sdkmanager --sdk_root="$ANDROID_HOME" 'ndk;25.2.9519653' 'cmake;3.22.1'
ruby regenerate.rb /tmp/newsblur-graphics-path-symbols
diff checksums.properties /tmp/newsblur-graphics-path-symbols/checksums.properties
```

For every ABI, [regenerate.rb](regenerate.rb) strips a fresh rebuild with the same settings as Google Maven, then compares the entire ELF against the Maven binary. The comparison permits a difference only in the 20-byte GNU build ID digest. This checks the program headers, code addresses and bytes, data, unwind tables, symbol boundaries visible in the shipped ELF, relocations and section table. Once all four comparisons pass, the script extracts the debug information and puts the published build ID into the companion. The bundled library keeps its original bytes.

Each companion passes LLVM DWARF verification, preserves all rebuilt text-symbol addresses and sizes, and resolves a private path iterator function to its source line. The source paths are relative to an AndroidX checkout. [Verification results](verification.tsv) include both IDs and the test addresses.
