#!/usr/bin/env ruby
# regenerate.rb reproduces the Google Maven graphics-path binaries before pairing DWARF.
require "digest"
require "fileutils"
require "open3"
require "tmpdir"

commit = "56a7bc0fd3521a28152fb509a3a745ff5a67daab"
artifact = "https://dl.google.com/dl/android/maven2/androidx/graphics/graphics-path/1.0.1/graphics-path-1.0.1.aar"
module_url = "https://android.googlesource.com/platform/frameworks/support/+archive/#{commit}/graphics/graphics-path.tar.gz"
library = "libandroidx.graphics.path.so"
abis = %w[arm64-v8a armeabi-v7a x86 x86_64]
output = File.expand_path(ARGV.fetch(0))
sdk = File.realpath(ENV.fetch("ANDROID_HOME"))
ndk = File.join(sdk, "ndk/25.2.9519653")
cmake_dir = File.join(sdk, "cmake/3.22.1/bin")
llvm = Dir[File.join(ndk, "toolchains/llvm/prebuilt/*/bin")].fetch(0)

def run(*args)
  stdout, stderr, status = Open3.capture3(*args, binmode: true)
  raise "#{args.first} failed: #{stderr}\n#{stdout}" unless status.success?
  stdout
end

def hash256(file)
  Digest::SHA256.file(file).hexdigest
end

def note_offset(bytes)
  signature = [4, 20, 3].pack("V3") + "GNU\0"
  start = bytes.index(signature)
  raise "Expected one SHA-1 GNU build ID" unless start && !bytes.index(signature, start + 1)
  start + signature.bytesize
end

Dir.mktmpdir("graphics-path") do |tmp|
  # Resolve symlinks so the paths supplied to Clang match its real working directory.
  tmp = File.realpath(tmp)
  aar = File.join(tmp, "graphics-path.aar")
  archive = File.join(tmp, "source.tar.gz")
  source = File.join(tmp, "source")
  FileUtils.mkdir_p(source)
  run("curl", "-fLsS", artifact, "-o", aar)
  raise "Unexpected Google Maven archive" unless hash256(aar) == "8ca4032b6d79b351f0b59ad4b580eddbb9423e1652f7c958830687f1eee2ec03"
  run("curl", "-fLsS", module_url, "-o", archive)
  run("tar", "-xzf", archive, "-C", source)

  # Verify Gitiles' module tree object independently of tar metadata and compression.
  run("git", "-C", source, "init", "-q")
  run("git", "-C", source, "-c", "core.autocrlf=false", "add", "-f", ".")
  tree = run("git", "-C", source, "write-tree").strip
  raise "Unexpected AndroidX source tree #{tree}" unless tree == "bffccdb1f1492bfb77aca159e101f437f469aea3"
  flags = File.read(File.join(source, "build.gradle")).match(/cppFlags\.addAll\(\[(.*?)\]\)/m)[1].scan(/"([^"]+)"/).flatten
  # The shipped release has the NDK strong stack protector enabled.
  flags.concat(["-fstack-protector-strong", "-fdebug-compilation-dir=.",
                "-fdebug-prefix-map=#{source}=graphics/graphics-path",
                "-fdebug-prefix-map=#{ndk}=ndk/r25c",
                "-fdebug-prefix-map=#{tmp}=build"])
  originals = {}
  builds = {}
  manifests = []
  proofs = []
  abis.each do |abi|
    build_dir = File.join(tmp, abi)
    originals[abi] = original = File.join(tmp, "#{abi}.orig")
    File.binwrite(original, run("unzip", "-p", aar, "jni/#{abi}/#{library}"))
    cmake = File.join(cmake_dir, "cmake")
    run(cmake, "-S", File.join(source, "src/main/cpp"), "-B", build_dir, "-G", "Ninja",
        "-DCMAKE_TOOLCHAIN_FILE=#{ndk}/build/cmake/android.toolchain.cmake",
        "-DANDROID_ABI=#{abi}", "-DANDROID_PLATFORM=android-21",
        "-DCMAKE_MAKE_PROGRAM=#{cmake_dir}/ninja", "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
        "-DCMAKE_CXX_FLAGS=#{flags.join(' ')}",
        "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=16384")
    run(cmake, "--build", build_dir)
    builds[abi] = rebuilt = File.join(build_dir, library)
    stripped = "#{rebuilt}.compare"
    run("#{llvm}/llvm-strip", "--strip-all", "--keep-section=.comment", "-o", stripped, rebuilt)
    vendor, comparison = [original, stripped].map { |f| File.binread(f) }
    start = note_offset(vendor)
    raise "#{abi} has a different build ID offset" unless start == note_offset(comparison)
    # Compare the entire stripped ELF including headers, code, all data, unwind and relocations.
    # Ignore exactly the 20-byte descriptor. Only this in-memory buffer is normalized.
    comparison[start, 20] = vendor.byteslice(start, 20)
    raise "#{abi} has different bytes outside its build ID" unless comparison == vendor
  end

  # Only pair companions after all four ABIs pass the full binary comparison.
  abis.each do |abi|
    original = originals.fetch(abi)
    rebuilt = builds.fetch(abi)
    companion = File.join(tmp, "#{abi}.dbg")
    # LLD 14 leaves zero-address entries for functions eliminated by --gc-sections.
    # Discard those entries before validating the remaining DWARF.
    cleaned = "#{rebuilt}.cleaned"
    run(ENV.fetch("LLVM_DWARFUTIL", "llvm-dwarfutil"), "--garbage-collection",
        "--tombstone=exec", "-j", "1", "--verify", rebuilt, cleaned)
    run("#{llvm}/llvm-objcopy", "--only-keep-debug", cleaned, companion)
    original_bytes = File.binread(original)
    symbols = File.binread(companion)
    start = note_offset(symbols)
    original_id = original_bytes.byteslice(note_offset(original_bytes), 20)
    rebuilt_id = symbols.byteslice(start, 20)
    symbols[start, 20] = original_id
    File.binwrite(companion, symbols)
    raise "Local path in #{abi} debug info" if symbols.include?(tmp) || symbols.include?(Dir.home + "/")
    run("#{llvm}/llvm-dwarfdump", "--verify", companion)
    readelf = run("#{llvm}/llvm-readelf", "-n", companion)
    raise "Wrong companion ID" unless readelf.include?(original_id.unpack1("H*"))
    before = run("#{llvm}/llvm-nm", "--print-size", "--numeric-sort", "--defined-only", rebuilt)
    after = run("#{llvm}/llvm-nm", "--print-size", "--numeric-sort", "--defined-only", companion)
    functions = before.lines.grep(/ [tT] /)
    raise "Function ranges changed" unless functions == after.lines.grep(/ [tT] /)
    # Symbolize private functions from the actual released instruction addresses.
    sample = functions.grep(/_ZN12PathIterator5countEv/).fetch(0).split.first
    line = run("#{llvm}/llvm-addr2line", "-C", "-f", "-e", companion, "0x#{sample}").strip.lines.map(&:strip)
    raise "Missing private function/source line" unless line[0] == "PathIterator::count()" && line[1].match?(%r{graphics/graphics-path/src/main/cpp/PathIterator\.cpp:[1-9]})
    proofs << [abi, original_id.unpack1("H*"), rebuilt_id.unpack1("H*"), functions.size, sample, line.join(" at ")].join("\t")
    manifests << "#{abi}.library=#{hash256(original)}"
    manifests << "#{abi}.symbols=#{hash256(companion)}"
  end
  abis.each do |abi|
    FileUtils.mkdir_p(File.join(output, abi))
    destination = File.join(output, abi, "#{library}.dbg")
    FileUtils.cp(File.join(tmp, "#{abi}.dbg"), destination)
    File.chmod(0o644, destination)
  end
  File.write(File.join(output, "checksums.properties"), manifests.join("\n") + "\n")
  puts "abi\tvendor/companion build ID\trebuild build ID\tfunction ranges\taddress\tprivate symbol and source"
  puts proofs
end
