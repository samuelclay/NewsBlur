#!/usr/bin/env ruby
# export-native.rb installs complete, source-hashed Android asset groups after technical validation.
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
  parser.banner = 'Usage: export-native.rb --language CODE --placement phoneScreenshots'
  parser.on('--language CODE') { |v| options[:language] = v }
  parser.on('--placement NAME') { |v| options[:placement] = v }
end.parse!
language, placement = options.values_at(:language, :placement)
placements = %w[icon featureGraphic phoneScreenshots sevenInchScreenshots tenInchScreenshots]
copy_path = File.join(root, 'copy', "#{language}.json")
abort 'An explicit canonical language and placement are required.' unless
  Dir.glob(File.join(root, 'copy', '*.json')).include?(copy_path) && placements.include?(placement)
locales = JSON.parse(File.read(File.join(root, '../../../locales.json'))).fetch('locales')
locale = locales.find { |item| item.fetch('language') == language }&.fetch('google')
abort 'Missing Google locale mapping.' unless locale
is_screenshot = placement.end_with?('Screenshots')
panels = is_screenshot ? (1..4).to_a : [1]
destination = File.join(root, 'exports', language, placement)
abort "Existing export set is preserved: #{destination}" if Dir.glob(File.join(destination, '*.png')).any?
device = { 'sevenInchScreenshots' => 'tablet7', 'tenInchScreenshots' => 'tablet10' }.fetch(placement, 'phone')
views = placement == 'featureGraphic' ? %w[stories reader] : placement == 'icon' ? [] : %w[stories feeds reader saved]
captures = views.map { |view| "captures/#{language}/#{device}-#{view}.png" }
source_paths = ['native-render.swift', 'export-native.rb', 'verify-native-pixels.rb', "copy/#{language}.json", 'assets/icon-source.png', *captures]
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

Dir.mktmpdir('newsblur-play-', '/tmp') do |temporary|
  # Cache only a binary whose filename includes the entire Swift source checksum.
  binary = File.join('/tmp', "newsblur-play-render-#{source_hashes.fetch('native-render.swift')[0, 20]}")
  run!('swiftc', File.join(root, 'native-render.swift'), '-o', binary) unless File.executable?(binary)
  records = panels.map do |panel|
    output = File.join(temporary, format('panel-%02d.png', panel))
    run!(binary, '--root', root, '--language', language, '--placement', placement, '--panel', panel.to_s, '--output', output)
    item = JSON.parse(File.read(output.sub(/\.png$/, '.json')))
    bytes = File.binread(output)
    width, height = item.values_at('width', 'height')
    abort 'Invalid PNG signature or dimensions.' unless bytes.start_with?("\x89PNG\r\n\x1a\n".b) && bytes[16, 8].unpack('NN') == [width, height]
    expected_alpha = placement == 'icon' ? 'yes' : 'no'
    abort 'PNG alpha channel does not match Play requirements.' unless
      run!('sips', '-g', 'hasAlpha', output).include?("hasAlpha: #{expected_alpha}")
    abort 'Screenshot exceeds basic Play dimensions.' if is_screenshot &&
      ([width, height].min < 320 || [width, height].max > 3840 || [width, height].max > [width, height].min * 2)
    abort 'Icon exceeds Play 1 MB limit.' if placement == 'icon' && bytes.bytesize > 1_048_576
    pixels = item.fetch('captures').map do |capture|
      NativePixelCheck.check(output, File.join(root, capture.fetch('path')), capture.fetch('bounds')).merge(capture: capture.fetch('path'))
    end
    relative = "#{language}/#{placement}/#{File.basename(output)}"
    {
      language: language, locale: locale, imageType: placement, position: panel, path: relative,
      sha256: Digest::SHA256.hexdigest(bytes), width: width, height: height, bytes: bytes.bytesize,
      source_sha256: source_hashes, native_pixel_checks: pixels, render: item.reject { |k, _| k == 'output' },
      visual_review: 'required', store_upload: 'unverified'
    }
  end
  source_hashes.each do |path, sha|
    abort "Source changed during rendering: #{path}" unless Digest::SHA256.file(File.join(root, path)).hexdigest == sha
  end
  FileUtils.mkdir_p(destination)
  panels.each { |panel| FileUtils.cp(File.join(temporary, format('panel-%02d.png', panel)), destination) }
  File.write(File.join(destination, 'validation.json'), JSON.pretty_generate({ checked_at: Time.now.utc.iso8601, assets: records }) + "\n")
end
# Rebuild only this exporter-owned asset inventory. Preserve any independently prepared video entries.
manifest_path = File.join(root, 'exports', 'manifest.json')
videos = File.file?(manifest_path) ? JSON.parse(File.read(manifest_path)).fetch('videos', []) : []
all_assets = Dir.glob(File.join(root, 'exports', '*', '*', 'validation.json')).sort.flat_map { |path| JSON.parse(File.read(path)).fetch('assets') }
File.write(manifest_path, JSON.pretty_generate({ packageName: 'com.newsblur', version: '16.0', assets: all_assets, videos: videos }) + "\n")
puts "Rendered and technically validated #{is_screenshot ? 4 : 1} #{language} #{placement} assets. Visual review remains required."
