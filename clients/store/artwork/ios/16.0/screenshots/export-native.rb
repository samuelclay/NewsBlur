#!/usr/bin/env ruby
# export-native.rb renders Sage panels offline and preserves existing approved exports.
require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'time'
require 'tmpdir'
require_relative 'verify-native-pixels'

root = File.expand_path(__dir__)
options = {}
OptionParser.new do |parser|
  parser.banner = 'Usage: export-native.rb --language CODE --size WIDTHxHEIGHT'
  parser.on('--language CODE') { |value| options[:language] = value }
  parser.on('--size SIZE') { |value| options[:size] = value }
end.parse!
language, size = options.values_at(:language, :size)
abort 'An explicit canonical language and supported size are required.' unless
  Dir.glob(File.join(root, 'copy', '*.json')).any? { |p| File.basename(p, '.json') == language } &&
  %w[1320x2868 1206x2622 2064x2752].include?(size)
destination = File.join(root, 'exports', language, size)
abort "Existing export set is preserved: #{destination}" if Dir.glob(File.join(destination, 'panel-*.png')).any?
device = size == '2064x2752' ? 'ipad' : 'iphone'
captures = %w[stories feeds reader saved].map do |view|
  "captures/#{language == 'en' ? '' : "localized/#{language}/"}#{device}-#{view}.png"
end
source_paths = ['native-render.swift', 'export-native.rb', "copy/#{language}.json",
  '../selected/assets/icon.png', "../selected/assets/#{device == 'ipad' ? 'ipad-pro-m5' : 'iphone-18-pro-max'}.png", *captures]
source_hashes = source_paths.to_h do |path|
  full = File.join(root, path)
  abort "Missing source: #{full}" unless File.file?(full)
  [path, Digest::SHA256.file(full).hexdigest]
end

def run!(*args)
  output, status = Open3.capture2e(*args)
  abort "Command failed: #{args.first}\n#{output}" unless status.success?
  output
end

Dir.mktmpdir('newsblur-sage-', '/tmp') do |temporary|
  binary = File.join(temporary, 'render')
  run!('swiftc', File.join(root, 'native-render.swift'), '-o', binary)
  width, height = size.split('x').map(&:to_i)
  evidence = []
  records = (1..4).map do |panel|
    output = File.join(temporary, "panel-#{panel}.png")
    run!(binary, '--root', root, '--language', language, '--size', size, '--panel', panel.to_s, '--output', output)
    item = JSON.parse(File.read(output.sub(/\.png$/, '.json')))
    bytes = File.binread(output)
    abort 'Invalid PNG signature or dimensions.' unless bytes.start_with?("\x89PNG\r\n\x1a\n".b) && bytes[16, 8].unpack('NN') == [width, height]
    abort 'PNG must be opaque.' unless run!('sips', '-g', 'hasAlpha', output).include?('hasAlpha: no')
    pixel = NativePixelCheck.check(output, File.join(root, item.fetch('capture')), item.fetch('capture_bounds'))
    relative = "exports/#{language}/#{size}/panel-#{panel}.png"
    evidence << item.merge('output' => relative, 'renderer' => 'CoreGraphics/CoreText offline Sage01',
      'capture_sha256' => source_hashes.fetch(item.fetch('capture')), 'source_sha256' => source_hashes,
      'output_sha256' => Digest::SHA256.hexdigest(bytes))
    { path: relative, panel: panel, width: width, height: height, opaque: true, bytes: bytes.bytesize,
      sha256: Digest::SHA256.hexdigest(bytes), native_pixel_check: pixel,
      visual_review: 'required', store_upload: 'unverified' }
  end
  source_hashes.each do |path, sha|
    abort "Source changed during rendering: #{path}" unless Digest::SHA256.file(File.join(root, path)).hexdigest == sha
  end
  # Produce a complete four-panel contact sheet for the required human review.
  filters = (0..3).map { |index| "[#{index}:v]scale=412:-1[p#{index}]" }.join(';') + ';[p0][p1][p2][p3]hstack=inputs=4[out]'
  contact = File.join(temporary, 'contact.png')
  run!('ffmpeg', '-v', 'error', '-y', *(1..4).flat_map { |panel| ['-i', File.join(temporary, "panel-#{panel}.png")] },
    '-filter_complex', filters, '-map', '[out]', '-frames:v', '1', contact)
  FileUtils.mkdir_p(destination)
  (1..4).each { |panel| FileUtils.cp(File.join(temporary, "panel-#{panel}.png"), destination) }
  FileUtils.cp(contact, File.join(destination, 'contact.png'))
  File.write(File.join(root, 'exports', language, "render-checks-#{size}.json"), JSON.pretty_generate(evidence) + "\n")
  manifest = { language: language, checked_at: Time.now.utc.iso8601, capture_format: 'CoreGraphics/CoreText opaque PNG',
    note: 'Technical validation does not establish visual approval or store persistence.', files: records }
  File.write(File.join(root, 'exports', language, "validation-#{size}.json"), JSON.pretty_generate(manifest) + "\n")
end
puts "Rendered and pixel-validated four #{language} #{size} panels. Visual review and staging remain required."
