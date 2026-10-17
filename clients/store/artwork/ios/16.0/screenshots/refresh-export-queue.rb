#!/usr/bin/env ruby
# refresh-export-queue.rb reconciles verified staging with all canonical locale/size combinations.
require 'digest'
require 'json'
require 'optparse'
require 'time'

root = File.expand_path(__dir__)
staging = '/tmp/newsblur-ios16-ready-uploads'
options = { status: 'active_waiting_for_verified_captures' }
OptionParser.new do |parser|
  parser.on('--capture-status STATUS') { |value| options[:status] = value }
  parser.on('--capture-checkpoint SHA') { |value| options[:checkpoint] = value }
end.parse!
languages = Dir.glob(File.join(root, 'copy', '*.json')).map { |path| File.basename(path, '.json') }.sort
sizes = %w[1320x2868 1206x2622 2064x2752]
expected = languages.product(sizes)
manifest = File.open(File.join(staging, '.manifest.lock'), 'a') do |lock|
  lock.flock(File::LOCK_SH)
  JSON.parse(File.read(File.join(staging, 'manifest.json')))
end
groups = manifest.select { |row| row['kind'] == 'screenshot' }.group_by { |row| row.values_at('language', 'display') }
abort 'Staging contains unsupported screenshot locales or sizes.' unless (groups.keys - expected).empty?
completed = groups.sort.map do |(language, size), rows|
  filenames = (1..4).map { |panel| format('newsblur-16.0-%s-%s-%02d.png', language, size, panel) }
  abort "Incomplete or duplicate staging: #{language} #{size}" unless rows.map { |row| File.basename(row.fetch('upload_file')) }.sort == filenames
  validation = JSON.parse(File.read(File.join(root, 'exports', language, "validation-#{size}.json")))
  abort 'Validation does not contain four panels.' unless validation.fetch('files').map { |file| file.fetch('panel') }.sort == [1, 2, 3, 4]
  rows.each do |row|
    abort "Staged checksum mismatch: #{row['upload_file']}" unless Digest::SHA256.file(row.fetch('upload_file')).hexdigest == row.fetch('sha256')
    panel = File.basename(row.fetch('upload_file'))[/-(\d+)\.png$/, 1].to_i
    record = validation.fetch('files').find { |file| file.fetch('panel') == panel }
    abort 'Staged image differs from validation.' unless record.fetch('sha256') == row.fetch('sha256')
  end
  native = validation.fetch('files').all? { |file| file.dig('native_pixel_check', 'status') == 'passed' }
  { language: language, size: size, panels: 4, technical_validation: 'passed',
    native_pixel_check: native ? 'passed' : 'legacy_review_evidence', visual_review: 'passed',
    staged_upload_pattern: "#{staging}/newsblur-16.0-#{language}-#{size}-0[1-4].png" }
end
pending = (expected - groups.keys).map do |language, size|
  { language: language, size: size, device: size == '2064x2752' ? 'ipad' : 'iphone',
    status: 'waiting_for_verified_native_capture', reason: 'Capture operator must verify and commit all four source frames before export.' }
end
report = {
  updated_at: Time.now.utc.iso8601,
  renderer: 'CoreGraphics/CoreText canonical for unfinished sets; existing approved browser exports preserved',
  capture_status: pending.empty? ? 'complete' : options[:status],
  required_next_steps: pending.empty? ? ['Upload the prepared screenshots to each matching store locale and display size',
    'Verify persisted placement after a fresh store reload'] : ['Wait for a verified complete native capture group',
    'Run export-native.rb for each missing size', 'Visually inspect all four panels per size',
    'Stage reviewed files with unique locale, size and panel filenames'],
  store_placement_tracking: 'Coordinator owns resubmission.json and /tmp/newsblur-ios16-ready-uploads/manifest.json; preparation status here does not establish store placement.',
  completed_sets: completed, remaining_batch: pending,
  counts: { expected_panels: expected.length * 4, staged_panels: completed.length * 4, complete_sets: completed.length, pending_sets: pending.length }
}
report[:capture_checkpoint] = options[:checkpoint] if options[:checkpoint]
File.write(File.join(root, 'export-queue.json'), JSON.pretty_generate(report) + "\n")
puts JSON.pretty_generate(report[:counts])
