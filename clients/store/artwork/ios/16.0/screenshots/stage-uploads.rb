#!/usr/bin/env ruby
# stage-uploads.rb stages explicitly reviewed screenshots under unambiguous App Store upload names.
require 'digest'
require 'fileutils'
require 'json'
require 'optparse'

root = File.expand_path(__dir__)
repository = File.expand_path('../../../../../..', root)
options = { destination: '/tmp/newsblur-ios16-ready-uploads' }
OptionParser.new do |parser|
  parser.banner = 'Usage: stage-uploads.rb --language CODE --size WIDTHxHEIGHT --reviewed'
  parser.on('--language CODE') { |value| options[:language] = value }
  parser.on('--size SIZE') { |value| options[:size] = value }
  parser.on('--destination PATH') { |value| options[:destination] = File.expand_path(value) }
  parser.on('--reviewed', 'Confirm this exact four-panel set was visually inspected') { options[:reviewed] = true }
end.parse!
abort 'Explicit --language, --size, and --reviewed are required.' unless options.values_at(:language, :size, :reviewed).all?
language, size = options.values_at(:language, :size)
abort 'Unsupported locale or size.' unless Dir.glob(File.join(root, 'copy', '*.json')).any? { |p| File.basename(p, '.json') == language } && %w[1320x2868 1206x2622 2064x2752].include?(size)
validation = JSON.parse(File.read(File.join(root, 'exports', language, "validation-#{size}.json")))
expected = (1..4).map { |panel| "exports/#{language}/#{size}/panel-#{panel}.png" }
abort 'Validation must contain exactly the requested four panels.' unless validation.fetch('files').map { |entry| entry.fetch('path') }.sort == expected.sort
records = validation.fetch('files').map do |entry|
  source = File.join(root, entry.fetch('path'))
  bytes = File.binread(source)
  digest = Digest::SHA256.hexdigest(bytes)
  abort "Source changed after validation: #{source}" unless digest == entry.fetch('sha256')
  abort "Invalid PNG dimensions: #{source}" unless bytes.start_with?("\x89PNG\r\n\x1a\n".b) && bytes[16, 8].unpack('NN') == size.split('x').map(&:to_i) && entry['opaque']
  upload = File.join(options[:destination], format('newsblur-16.0-%s-%s-%02d.png', language, size, entry.fetch('panel')))
  { 'kind' => 'screenshot', 'language' => language, 'display' => size,
    'source' => source.delete_prefix(repository + '/'), 'upload_file' => upload, 'sha256' => digest, 'store_placement' => 'unverified' }
end
FileUtils.mkdir_p(options[:destination])
File.open(File.join(options[:destination], '.manifest.lock'), 'w') do |lock|
  lock.flock(File::LOCK_EX)
  manifest_path = File.join(options[:destination], 'manifest.json')
  manifest = File.exist?(manifest_path) ? JSON.parse(File.read(manifest_path)) : []
  records.each do |record|
    existing = manifest.find { |row| row['upload_file'] == record['upload_file'] }
    record = existing.merge(record).merge('store_placement' => existing['store_placement']) if existing && existing['sha256'] == record['sha256']
    source = File.join(repository, record.fetch('source'))
    FileUtils.cp(source, record.fetch('upload_file'))
    abort 'Staged checksum mismatch.' unless Digest::SHA256.file(record.fetch('upload_file')).hexdigest == record.fetch('sha256')
    manifest.reject! { |row| row['upload_file'] == record['upload_file'] }
    manifest << record
  end
  temporary = "#{manifest_path}.tmp"
  File.write(temporary, JSON.pretty_generate(manifest) + "\n")
  File.rename(temporary, manifest_path)
end
puts "Staged four reviewed #{language} #{size} screenshots with unique filenames; store placement remains unverified."
