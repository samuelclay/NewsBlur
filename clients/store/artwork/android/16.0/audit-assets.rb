#!/usr/bin/env ruby
# audit-assets.rb independently rechecks the uploader inventory and native pixels.
require 'digest'
require 'json'
require 'open3'
require 'optparse'
require 'rexml/document'
require 'time'
require_relative 'verify-native-pixels'

root = File.expand_path(__dir__)
options = { manifest: File.join(root, 'exports/manifest.json') }
OptionParser.new do |parser|
  parser.banner = 'Usage: audit-assets.rb --output PROOF.json [--partial] [--allow-unreviewed]'
  parser.on('--manifest PATH') { |value| options[:manifest] = File.expand_path(value) }
  parser.on('--output PATH') { |value| options[:output] = File.expand_path(value) }
  parser.on('--partial') { options[:partial] = true }
  parser.on('--language CODE') { |value| options[:language] = value; options[:partial] = true }
  parser.on('--allow-unreviewed') { options[:allow_unreviewed] = true }
end.parse!
abort 'A new --output path is required.' unless options[:output] && !File.exist?(options[:output])
manifest_path = options.fetch(:manifest)
manifest = JSON.parse(File.read(manifest_path))
abort 'Wrong app/version.' unless manifest.values_at('packageName', 'version') == ['com.newsblur', '16.0']
locales = JSON.parse(File.read(File.join(root, '../../../locales.json'))).fetch('locales').to_h do |row|
  [row.fetch('language'), row.fetch('google')]
end
languages = JSON.parse(File.read(File.join(root, '../../../../../localization/languages.json'))).keys
abort 'Canonical app/store language mismatch.' unless locales.keys.sort == languages.sort && locales.values.uniq.size == 21
types = %w[icon featureGraphic phoneScreenshots sevenInchScreenshots tenInchScreenshots]
assets = manifest.fetch('assets')
if options[:language]
  abort 'Unknown audit language.' unless languages.include?(options[:language])
  assets = assets.select { |row| row.fetch('language') == options[:language] }
end
groups = assets.group_by { |row| [row.fetch('language'), row.fetch('imageType')] }
expected_groups = languages.product(types)
missing = expected_groups - groups.keys
abort 'Unexpected asset groups.' unless (groups.keys - expected_groups).empty?
abort "Missing groups: #{missing.inspect}" unless missing.empty? || options[:partial]
abort 'Full inventory must contain exactly 294 assets.' if missing.empty? && assets.size != 294
abort 'No assets available to audit.' if assets.empty?
seen_paths = []
results = []
locale_resources = {}
groups.each do |(language, type), rows|
  count = %w[icon featureGraphic].include?(type) ? 1 : 4
  abort "Incomplete/duplicate positions: #{language}/#{type}" unless rows.map { |row| row.fetch('position') }.sort == (1..count).to_a
  validation = JSON.parse(File.read(File.join(root, 'exports', language, type, 'validation.json'))).fetch('assets')
  abort "Aggregate differs from group validation: #{language}/#{type}" unless rows.sort_by { |row| row['position'] } == validation.sort_by { |row| row['position'] }
  copy = JSON.parse(File.read(File.join(root, 'copy', "#{language}.json")))
  abort "Copy language mismatch: #{language}" unless copy.fetch('language') == language
  rows.each do |row|
    position = row.fetch('position')
    expected_path = format('%s/%s/panel-%02d.png', language, type, position)
    abort "Locale/path mismatch: #{expected_path}" unless row.fetch('locale') == locales.fetch(language) && row.fetch('path') == expected_path
    abort "Duplicate output path: #{expected_path}" if seen_paths.include?(expected_path)
    seen_paths << expected_path
    output = File.join(File.dirname(manifest_path), expected_path)
    bytes = File.binread(output)
    abort "Output checksum mismatch: #{expected_path}" unless Digest::SHA256.hexdigest(bytes) == row.fetch('sha256')
    abort "Invalid PNG: #{expected_path}" unless bytes.start_with?("\x89PNG\r\n\x1a\n".b)
    width, height = bytes[16, 8].unpack('NN')
    abort "Dimension evidence mismatch: #{expected_path}" unless [width, height] == row.values_at('width', 'height')
    color_type = bytes.getbyte(25)
    abort "Wrong PNG color/alpha format: #{expected_path}" unless color_type == (type == 'icon' ? 6 : 2)
    if type == 'icon'
      abort 'Invalid icon dimensions/size.' unless [width, height] == [512, 512] && bytes.bytesize <= 1_048_576
    elsif type == 'featureGraphic'
      abort 'Invalid feature dimensions.' unless [width, height] == [1024, 500]
    elsif type == 'phoneScreenshots'
      abort 'Invalid phone export dimensions.' unless [width, height] == [1080, 1920]
    else
      abort 'Invalid native tablet dimensions.' unless [width, height].min >= 320 && [width, height].max <= 3840 && [width, height].max <= 2 * [width, height].min
    end
    abort "Visual review pending: #{expected_path}" unless options[:allow_unreviewed] || row.fetch('visual_review') == 'approved'
    source_hashes = row.fetch('source_sha256')
    required = ['native-render.swift', 'export-native.rb', 'verify-native-pixels.rb', "copy/#{language}.json", 'assets/icon-source.png']
    abort "Incomplete source provenance: #{expected_path}" unless (required - source_hashes.keys).empty?
    source_hashes.each do |path, checksum|
      abort "Source changed after render: #{path}" unless Digest::SHA256.file(File.join(root, path)).hexdigest == checksum
    end
    render = row.fetch('render')
    abort "Render identity mismatch: #{expected_path}" unless render.values_at('language', 'placement', 'panel', 'width', 'height') == [language, type, position, width, height]
    expected_text = case type
    when 'phoneScreenshots' then ['NewsBlur', copy.fetch('headlines').fetch(position - 1)]
    when 'featureGraphic' then ['NewsBlur', copy.fetch('feature_headline'), copy.fetch('feature_subheadline')]
    else []
    end
    abort "Caption language/content mismatch: #{expected_path}" unless render.fetch('text').map { |text| text.fetch('text') } == expected_text
    view = %w[stories feeds reader saved].fetch(position - 1)
    device = { 'sevenInchScreenshots' => 'tablet7', 'tenInchScreenshots' => 'tablet10' }.fetch(type, 'phone')
    expected_captures = case type
    when 'icon' then []
    when 'featureGraphic' then %w[stories reader].map { |name| "captures/#{language}/phone-#{name}.png" }
    else ["captures/#{language}/#{device}-#{view}.png"]
    end
    captures = render.fetch('captures')
    abort "Wrong locale/device native source: #{expected_path}" unless captures.map { |capture| capture.fetch('path') } == expected_captures
    fresh_pixels = captures.map do |capture|
      path = capture.fetch('path')
      abort "Missing capture checksum: #{path}" unless source_hashes.key?(path)
      native_path = File.join(root, path)
      capture_metadata = JSON.parse(File.read(native_path.sub(/\.png$/, '.json')))
      expected_scene = File.basename(path, '.png').split('-', 2).last
      expected_device = File.basename(path, '.png').split('-', 2).first
      abort "Capture provenance mismatch: #{path}" unless capture_metadata.values_at('language', 'device', 'scene', 'package', 'sha256') ==
        [language, expected_device, expected_scene, 'com.newsblur.storecapture', source_hashes.fetch(path)]
      xml_path = native_path.sub(/\.png$/, '.xml')
      xml = File.read(xml_path)
      hierarchy = REXML::Document.new(xml)
      labels = REXML::XPath.match(hierarchy, '//node').flat_map { |node| [node.attributes['text'], node.attributes['content-desc']] }.compact.reject(&:empty?)
      required_label_key = { 'feeds' => 'all_stories_title', 'stories' => 'all_stories_title', 'saved' => 'saved_stories_title' }[expected_scene]
      if required_label_key
        qualifier = { 'pt-BR' => 'pt-rBR', 'zh-Hans' => 'b+zh+Hans', 'zh-Hant' => 'b+zh+Hant' }.fetch(language, language)
        directory = language == 'en' ? 'values' : "values-#{qualifier}"
        resources = locale_resources[language] ||= REXML::Document.new(File.read(File.join(root, "../../../../android/NewsBlur/app/src/main/res/#{directory}/strings.xml")))
        expected_label = REXML::XPath.first(resources, "/resources/string[@name='#{required_label_key}']")&.text&.gsub("\\'", "'")&.gsub('\\"', '"')
        abort "Native interface locale label mismatch: #{path}, #{required_label_key}" unless expected_label && labels.include?(expected_label)
      end
      native_width, native_height = File.binread(native_path, 24)[16, 8].unpack('NN')
      abort "Capture size evidence mismatch: #{path}" unless [native_width, native_height] == capture.values_at('source_width', 'source_height')
      bounds = capture.fetch('bounds')
      if type.include?('InchScreenshots')
        abort "Tablet was framed, cropped or resized: #{path}" unless [width, height] == [native_width, native_height] && bounds == { 'x' => 0, 'y' => 0, 'width' => width, 'height' => height }
      end
      NativePixelCheck.check(output, native_path, bounds).merge(capture: path, native_locale_label: required_label_key || 'manual_reader_review', hierarchy_sha256: Digest::SHA256.hexdigest(xml))
    end
    recommended_ratio = width * 16 == height * 9 || width * 9 == height * 16
    results << { path: expected_path, sha256: row.fetch('sha256'), source_hashes: 'passed', captions: 'passed', native_pixels: fresh_pixels,
      visual_review: row.fetch('visual_review'), recommended_screenshot_ratio: type.end_with?('Screenshots') ? recommended_ratio : nil }
  end
end
report = { checked_at: Time.now.utc.iso8601, packageName: 'com.newsblur', manifest_sha256: Digest::SHA256.file(manifest_path).hexdigest,
  asset_count: assets.size, expected_asset_count: 294, locale_count: groups.keys.map(&:first).uniq.size,
  group_count: groups.size, expected_group_count: 105, missing_groups: missing, complete: missing.empty?,
  all_visually_reviewed: assets.all? { |row| row['visual_review'] == 'approved' }, assets: results,
  manual_checks: ['Actual interface language and RTL direction', 'No cut-off text or missing glyphs', 'Correct phone/tablet navigation and cooked-content images', 'No debug errors, alerts, loaders or stale content', 'English story/feed content intentionally remains English', 'Store readback and YouTube playback remain separate checks'] }
File.write(options[:output], JSON.pretty_generate(report) + "\n")
puts JSON.generate(report.reject { |key, _| key == :assets })
