#!/usr/bin/env ruby
# verify-revision.rb reconciles revised Duo artwork with preserved originals and reloaded store evidence.
require 'digest'
require 'json'
require 'optparse'
require 'time'
require_relative '../../16.0/screenshots/verify-native-pixels'

options = { revision: 'v2' }
OptionParser.new do |parser|
  parser.banner = 'Usage: verify-revision.rb [--revision v2]'
  parser.on('--revision NAME') { |value| options[:revision] = value }
end.parse!
revision = options[:revision]
abort 'Invalid revision name.' unless revision.match?(/\A[a-z][a-z0-9-]*\z/)
root = File.expand_path(__dir__)
revision_root = File.join(root, 'revisions', revision)
locales = JSON.parse(File.read(File.expand_path('../../../../../../localization/languages.json', root))).keys

def checked(condition, message)
  raise message unless condition
end

def read_json(path)
  JSON.parse(File.read(path))
end

def png_dimensions(path)
  header = File.binread(path, 24)
  checked(header.start_with?("\x89PNG\r\n\x1a\n".b), "Not a PNG: #{path}")
  header[16, 8].unpack('NN')
end

records = locales.map do |locale|
  directory = File.join(revision_root, 'exports', locale)
  validation = read_json(File.join(directory, 'validation.json'))
  checked(validation.fetch('language') == locale && validation.fetch('revision') == revision, "Wrong validation locale/revision: #{locale}")
  files = validation.fetch('files')
  checked(files.map { |item| item.fetch('panel') } == [1, 2, 3, 4], "Panel order/count failed: #{locale}")
  render_checks = read_json(File.join(directory, 'render-checks.json'))
  checked(render_checks.map { |item| item.fetch('panel') } == [1, 4], "Unexpected rendered panels: #{locale}")
  review = read_json(File.join(directory, 'independent-review.json'))
  checked(review.fetch('status') == 'passed', "Revision review failed: #{locale}")
  original_review = read_json(File.join(root, 'exports', locale, 'independent-review.json'))
  checked(original_review.fetch('status') == 'passed', "Original review failed: #{locale}")

  captures = %w[closed fullscreen].to_h do |scene|
    metadata = read_json(File.join(revision_root, 'captures', locale, "#{scene}.json"))
    expected_dimensions = scene == 'closed' ? [1398, 2034] : [2853, 2007]
    expected_display = scene == 'closed' ? '1' : '3'
    checked(metadata.fetch('locale') == locale && metadata.fetch('scene') == scene, "Wrong capture scene/locale: #{locale}/#{scene}")
    checked(metadata.fetch('display').to_s == expected_display, "Wrong capture display: #{locale}/#{scene}")
    checked(metadata.fetch('capture') == "duo-#{scene}.png", "Unexpected capture filename: #{locale}/#{scene}")
    path = File.join(revision_root, 'captures', locale, metadata.fetch('capture'))
    checked(metadata.fetch('dimensions') == expected_dimensions && png_dimensions(path) == expected_dimensions,
      "Wrong native dimensions: #{locale}/#{scene}")
    checked(Digest::SHA256.file(path).hexdigest == metadata.fetch('sha256'), "Native capture changed: #{locale}/#{scene}")
    Time.iso8601(metadata.fetch('captured_at'))
    arguments = metadata.fetch('arguments')
    mode = scene == 'closed' ? 'NO' : 'YES'
    checked(arguments.include?("-duo_fullscreen_reader.Alex #{mode}"), "Wrong fullscreen state: #{locale}/#{scene}")
    [scene, metadata.merge('absolute_path' => path)]
  end

  verified_files = files.map do |item|
    panel = item.fetch('panel')
    name = if [2, 3].include?(panel)
      "newsblur-16.0.1-#{locale}-duo-inner-2853x2007-#{format('%02d', panel)}.png"
    else
      pose = panel == 1 ? 'closed' : 'inner'
      "newsblur-16.0.1-#{locale}-duo-#{pose}-2853x2007-#{format('%02d', panel)}-#{revision}.png"
    end
    expected_path = [2, 3].include?(panel) ? "exports/#{locale}/#{name}" : "revisions/#{revision}/exports/#{locale}/#{name}"
    checked(item.fetch('path') == expected_path, "Unexpected export path: #{locale}/#{panel}")
    path = File.join(root, expected_path)
    sha = Digest::SHA256.file(path).hexdigest
    checked(sha == item.fetch('sha256'), "Export changed: #{name}")
    checked(png_dimensions(path) == [2853, 2007], "Wrong export dimensions: #{name}")
    checked(review.fetch('files').any? { |entry| entry.fetch('filename') == name && entry.fetch('sha256') == sha }, "Unreviewed revision bytes: #{name}")
    if [2, 3].include?(panel)
      checked(item.fetch('disposition') == 'original_preserved_byte_for_byte', "Original replacement forbidden: #{name}")
      checked(original_review.fetch('files').any? { |entry| entry.fetch('filename') == name && entry.fetch('sha256') == sha }, "Original export changed: #{name}")
    else
      capture = captures.fetch(panel == 1 ? 'closed' : 'fullscreen')
      render = render_checks.find { |entry| entry.fetch('panel') == panel }
      checked(render.fetch('output') == expected_path && render.fetch('output_sha256') == sha, "Render evidence mismatch: #{name}")
      checked(render.fetch('capture_sha256') == capture.fetch('sha256') &&
        File.realpath(render.fetch('capture')) == File.realpath(capture.fetch('absolute_path')), "Wrong embedded capture: #{name}")
      checked(render.fetch('frame_pose') == (panel == 1 ? 'closed' : 'open'), "Wrong frame pose: #{name}")
      render.fetch('source_sha256').each do |source, source_sha|
        checked(Digest::SHA256.file(source).hexdigest == source_sha, "Render source changed: #{source}")
      end
      checked(item.fetch('native_pixel_check').fetch('status') == 'passed', "Missing pixel check: #{name}")
      NativePixelCheck.check(path, capture.fetch('absolute_path'), render.fetch('capture_bounds'))
    end
    { filename: name, sha256: sha, panel: panel }
  end
  names = verified_files.map { |item| item.fetch(:filename) }
  checked(review.fetch('files').map { |item| item.fetch('filename') }.sort == names.sort, "Review must cover exactly four files: #{locale}")
  checked(verified_files.map { |item| item.fetch(:sha256) }.uniq.length == 4, "Duplicate export bytes: #{locale}")
  readback = File.read(File.join(directory, 'store-readback.txt'))
  checked(readback.include?('verified_after_reload'), "Readback lacks reload verification: #{locale}")
  checked(readback.include?('4 of 10 App Screenshots'), "Store screenshot count failed: #{locale}")
  persisted_names = readback.scan(/newsblur-16\.0\.1-[^\s"<>]+\.png/).uniq
  checked(persisted_names == names, "Store filename order/count failed: #{locale}")
  { locale: locale, files: verified_files, capture_sha256: captures.transform_values { |item| item.fetch('sha256') },
    independent_visual_review: 'passed', store_placement: 'verified_after_reload' }
end

# verify-revision.rb writes success only after every locale passes; original draft evidence remains untouched.
report = { verified_at: Time.now.utc.iso8601, version: '16.0.1', revision: revision,
  screenshot_count: records.length * 4, replaced_screenshot_count: records.length * 2, locale_count: records.length,
  store_url: 'https://appstoreconnect.apple.com/apps/463981119/distribution/ios/version/inflight',
  scope: 'Screenshot revision only; this report does not verify release submission, approval or public availability.', locales: records }
File.write(File.join(revision_root, 'draft-verification.json'), JSON.pretty_generate(report) + "\n")
puts "Verified #{records.length * 4} revised placements in #{records.length} locales; original panels 2 and 3 preserved."
