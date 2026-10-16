#!/usr/bin/env ruby
# finalize-exports.rb converts CUA screenshot bytes without resizing and validates store PNGs.
require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'time'
require_relative 'verify-native-pixels'

root = File.expand_path(__dir__)
options = { raw_root: '/tmp/newsblur-store-screenshot-renders', sizes: %w[1320x2868 1206x2622 2064x2752] }
OptionParser.new do |parser|
  parser.banner = 'Usage: finalize-exports.rb --language CODE [--size WIDTHxHEIGHT] [--validate-only]'
  parser.on('--language CODE') { |value| options[:language] = value }
  parser.on('--size SIZE') { |value| options[:sizes] = [value] }
  parser.on('--raw-root PATH') { |value| options[:raw_root] = File.expand_path(value) }
  parser.on('--validate-only') { options[:validate_only] = true }
end.parse!
language = options.fetch(:language) { abort 'An explicit --language is required.' }
abort 'Unknown language.' unless Dir.glob(File.join(root, 'copy', '*.json')).map { |p| File.basename(p, '.json') }.include?(language)
abort 'Unsupported export size.' unless (options[:sizes] - %w[1320x2868 1206x2622 2064x2752]).empty?

def image_properties(path)
  output, status = Open3.capture2e('sips', '-g', 'pixelWidth', '-g', 'pixelHeight', '-g', 'hasAlpha', path)
  abort "Cannot inspect #{path}: #{output}" unless status.success?
  { width: output[/pixelWidth: (\d+)/, 1].to_i, height: output[/pixelHeight: (\d+)/, 1].to_i,
    opaque: output[/hasAlpha: (\w+)/, 1] == 'no' }
end

records = options[:sizes].flat_map do |size|
  width, height = size.split('x').map(&:to_i)
  evidence_path = File.join(root, 'exports', language, "render-checks-#{size}.json")
  evidence = File.exist?(evidence_path) ? JSON.parse(File.read(evidence_path)) : []
  (1..4).map do |panel|
    destination = File.join(root, 'exports', language, size, "panel-#{panel}.png")
    unless options[:validate_only]
      source = File.join(options[:raw_root], language, size, "panel-#{panel}.jpg")
      abort "Missing CUA screenshot: #{source}" unless File.file?(source)
      abort "Expected genuine JPEG bytes: #{source}" unless File.binread(source, 3).bytes == [255, 216, 255]
      source_properties = image_properties(source)
      abort "Wrong CUA screenshot dimensions: #{source}" unless source_properties.values_at(:width, :height) == [width, height]
      FileUtils.mkdir_p(File.dirname(destination))
      temporary = "#{destination}.tmp.png"
      output, status = Open3.capture2e('sips', '-s', 'format', 'png', source, '--out', temporary)
      abort "PNG conversion failed: #{output}" unless status.success?
      File.rename(temporary, destination)
    end
    abort "Missing export: #{destination}" unless File.file?(destination)
    bytes = File.binread(destination)
    abort "Invalid PNG: #{destination}" unless bytes.start_with?("\x89PNG\r\n\x1a\n".b)
    abort "Invalid PNG dimensions: #{destination}" unless bytes[16, 8].unpack('NN') == [width, height]
    properties = image_properties(destination)
    abort "Alpha channel is not allowed: #{destination}" unless properties[:opaque]
    render = evidence.find { |entry| entry['panel'] == panel }
    pixel_check = { status: 'not_available_requires_visual_review' }
    if render && render['capture_bounds']
      capture = File.join(root, render.fetch('capture'))
      abort "Native capture changed since rendering: #{capture}" unless Digest::SHA256.file(capture).hexdigest == render.fetch('capture_sha256')
      pixel_check = NativePixelCheck.check(destination, capture, render.fetch('capture_bounds'))
    end
    { path: destination.delete_prefix(root + '/'), panel: panel, **properties,
      bytes: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes), native_pixel_check: pixel_check,
      visual_review: 'required', store_upload: 'unverified' }
  end
end
manifest = { language: language, checked_at: Time.now.utc.iso8601,
  capture_format: 'CUA JPEG screenshot converted to opaque PNG without resizing',
  note: 'Encoding checks do not establish correct native content, visual approval, or store persistence.', files: records }
File.write(File.join(root, 'exports', language, "validation-#{options[:sizes].join('_')}.json"), JSON.pretty_generate(manifest) + "\n")
puts "Validated #{records.length} opaque PNG exports for #{language}: #{options[:sizes].join(', ')}."
