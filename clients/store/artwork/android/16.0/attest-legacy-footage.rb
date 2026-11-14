#!/usr/bin/env ruby
# attest-legacy-footage.rb documents already-recorded clips without inventing capture-time metadata.
require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'time'
require 'tmpdir'
require_relative 'capture-resume'
require_relative 'verify-native-pixels'

root = File.expand_path(__dir__)
serial, device, *languages = ARGV
abort 'Usage: attest-legacy-footage.rb SERIAL phone|tablet10 LANGUAGE...' unless serial && %w[phone tablet10].include?(device) && !languages.empty?
supported = JSON.parse(File.read(File.join(root, '../../../../../localization/languages.json')))
abort 'Unsupported language.' unless (languages - supported.keys).empty?
legacy_commit = 'cfad20329'
legacy_path = 'clients/store/artwork/android/16.0/capture-native.rb'
legacy_source, error, status = Open3.capture3('git', '-C', root, 'show', "#{legacy_commit}:#{legacy_path}")
abort "Cannot read attested recorder source: #{error}" unless status.success?
languages.each do |language|
  %w[feeds stories reader saved].each do |scene|
    video = File.join(root, 'captures/footage', language, "#{device}-#{scene}.mp4")
    proof_path = video.sub(/\.mp4$/, '.json')
    next unless File.file?(video)
    next if File.exist?(proof_path)
    # Do not inspect a file still being pulled by the active capture process.
    next if Time.now - File.mtime(video) < 10
    image = File.join(root, 'captures', language, "#{device}-#{scene}.png")
    identity = { 'language' => language, 'device' => device, 'serial' => serial, 'scene' => scene, 'package' => 'com.newsblur.storecapture' }
    abort "Invalid related still: #{image}" unless CaptureResume.still_complete?(image, identity)
    metadata = JSON.parse(File.read(image.sub(/\.png$/, '.json')))
    width, height = File.binread(image, 24)[16, 8].unpack('NN')
    before_hash = Digest::SHA256.file(video).hexdigest
    probe = CaptureResume.probe_video(video)
    abort "Invalid clip duration/dimensions: #{video}" unless CaptureResume.valid_probe?(probe, [width, height])
    # The null muxer's coarse timebase can flag valid Android VFR timestamps as duplicates.
    # Assign output-only sequential timestamps while decoding every source frame; never rewrite the clip.
    _, decode_error, decoded = Open3.capture3('ffmpeg', '-v', 'error', '-threads', '1', '-i', video,
      '-vf', 'setpts=N/30/TB', '-r', '30', '-f', 'null', '-')
    abort "Clip fails full decode: #{decode_error}" unless decoded.success? && decode_error.empty?
    first_frame_check = Dir.mktmpdir('newsblur-clip-attestation-') do |temporary|
      frame = File.join(temporary, 'first-frame.png')
      _, frame_error, extracted = Open3.capture3('ffmpeg', '-v', 'error', '-threads', '1', '-i', video, '-frames:v', '1', frame)
      abort "Cannot inspect first frame: #{frame_error}" unless extracted.success?
      NativePixelCheck.check(frame, image, { 'x' => 0, 'y' => 0, 'width' => width, 'height' => height })
    end
    abort "Clip changed during verification: #{video}" unless Digest::SHA256.file(video).hexdigest == before_hash
    xml = File.binread(image.sub(/\.png$/, '.xml'))
    hierarchy = video.sub(/\.mp4$/, '.xml')
    abort "Existing hierarchy differs: #{hierarchy}" if File.exist?(hierarchy) && File.binread(hierarchy) != xml
    File.binwrite(hierarchy, xml)
    proof = identity.merge(
      'recorded_by' => { 'script' => legacy_path, 'commit' => legacy_commit, 'source_sha256' => Digest::SHA256.hexdigest(legacy_source) },
      'sidecar_attested_at' => Time.now.utc.iso8601,
      'attestation_basis' => 'Coordinator-confirmed serialized legacy capture batch; related still and observed UI hierarchy, matching first frame, full decode and fresh ffprobe verified retrospectively.',
      'source_still_captured_at' => metadata.fetch('captured_at'),
      'recording_file_mtime' => File.mtime(video).utc.iso8601,
      'recording_timestamp_note' => 'Filesystem mtime is recorded separately; no exact recording timestamp was written by the legacy capture process.',
      'sha256' => before_hash, 'source_still_sha256' => metadata.fetch('sha256'),
      'hierarchy_sha256' => Digest::SHA256.hexdigest(xml), 'hierarchy_source' => 'related still observed before recording',
      'probe' => probe, 'full_decode' => 'passed', 'first_frame_native_pixels' => first_frame_check,
      'visual_review' => 'required'
    )
    File.open(proof_path, File::WRONLY | File::CREAT | File::EXCL, 0o644) { |file| file.write(JSON.pretty_generate(proof) + "\n") }
    puts "Retrospectively attested #{language}/#{device}/#{scene}"
    $stdout.flush
  end
end
