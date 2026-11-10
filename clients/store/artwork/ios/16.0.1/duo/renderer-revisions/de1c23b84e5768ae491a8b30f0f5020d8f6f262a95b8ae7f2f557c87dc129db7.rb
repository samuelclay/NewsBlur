#!/usr/bin/env ruby
# export-native.rb renders and pixel-validates Duo Sage sets before installing their unique filenames.
require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'time'
require 'tmpdir'
require_relative '../../16.0/screenshots/verify-native-pixels'

root = File.expand_path(__dir__)
options = {}
OptionParser.new do |parser|
  parser.banner = 'Usage: export-native.rb --language CODE (or --all)'
  parser.on('--language CODE') { |value| options[:language] = value }
  parser.on('--all') { options[:all] = true }
end.parse!
abort 'Choose either --language CODE or --all.' if !!options[:all] == !!options[:language]
supported = JSON.parse(File.read(File.expand_path('../../../../../../localization/languages.json', root))).keys
languages = options[:all] ? supported : [options[:language]]
abort 'Unsupported canonical language.' unless (languages - supported).empty?

# Refuse partial replacement of previously reviewed or uploaded files.
languages.each do |language|
  destination = File.join(root, 'exports', language)
  abort "Existing export set is preserved: #{destination}" if Dir.glob(File.join(destination, '*.png')).any?
  %w[stories feeds reader saved].each do |view|
    capture = File.join(root, 'captures', language, "duo-#{view}.png")
    abort "Missing capture: #{capture}" unless File.file?(capture)
  end
end

def run!(*args)
  output, status = Open3.capture2e(*args)
  abort "Command failed: #{args.first}\n#{output}" unless status.success?
  output
end

Dir.mktmpdir('newsblur-duo-sage-', '/tmp') do |temporary|
  binary = File.join(temporary, 'render')
  run!('swiftc', File.join(root, 'native-render.swift'), '-o', binary)
  languages.each do |language|
    captures = %w[stories feeds reader saved].map { |view| "captures/#{language}/duo-#{view}.png" }
    source_paths = ['native-render.swift', 'export-native.rb', "../../16.0/screenshots/copy/#{language}.json",
      '../../16.0/screenshots/verify-native-pixels.rb', '../../16.0/selected/assets/icon.png',
      'assets/iphone-duo-inner-landscape.png', *captures]
    source_hashes = source_paths.to_h { |path| [path, Digest::SHA256.file(File.join(root, path)).hexdigest] }
    evidence = []
    records = (1..4).map do |panel|
      name = "newsblur-16.0.1-#{language}-duo-inner-2853x2007-#{format('%02d', panel)}.png"
      output = File.join(temporary, name)
      run!(binary, '--root', root, '--language', language, '--size', '2853x2007', '--panel', panel.to_s, '--output', output)
      item = JSON.parse(File.read(output.sub(/\.png$/, '.json')))
      bytes = File.binread(output)
      abort 'Invalid PNG signature or dimensions.' unless bytes.start_with?("\x89PNG\r\n\x1a\n".b) && bytes[16, 8].unpack('NN') == [2853, 2007]
      abort 'PNG must be opaque.' unless run!('sips', '-g', 'hasAlpha', output).include?('hasAlpha: no')
      pixel = NativePixelCheck.check(output, File.join(root, item.fetch('capture')), item.fetch('capture_bounds'))
      relative = "exports/#{language}/#{name}"
      evidence << item.merge('output' => relative, 'renderer' => 'CoreGraphics/CoreText Duo Sage',
        'capture_sha256' => source_hashes.fetch(item.fetch('capture')), 'source_sha256' => source_hashes,
        'output_sha256' => Digest::SHA256.hexdigest(bytes))
      { path: relative, panel: panel, width: 2853, height: 2007, opaque: true, bytes: bytes.bytesize,
        sha256: Digest::SHA256.hexdigest(bytes), native_pixel_check: pixel,
        visual_review: 'required', store_upload: 'unverified' }
    end
    source_hashes.each do |path, sha|
      abort "Source changed during rendering: #{path}" unless Digest::SHA256.file(File.join(root, path)).hexdigest == sha
    end
    # A 2 x 2 contact sheet retains enough screen detail for visual review.
    filters = (0..3).map { |index| "[#{index}:v]scale=856:-1[p#{index}]" }.join(';') +
      ';[p0][p1][p2][p3]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0[out]'
    contact = File.join(temporary, "contact-#{language}.png")
    run!('ffmpeg', '-v', 'error', '-y', *records.flat_map { |record| ['-i', File.join(temporary, File.basename(record[:path]))] },
      '-filter_complex', filters, '-map', '[out]', '-frames:v', '1', contact)
    destination = File.join(root, 'exports', language)
    FileUtils.mkdir_p(destination)
    records.each { |record| FileUtils.cp(File.join(temporary, File.basename(record[:path])), destination) }
    FileUtils.cp(contact, File.join(destination, 'contact.png'))
    File.write(File.join(destination, 'render-checks.json'), JSON.pretty_generate(evidence) + "\n")
    manifest = { language: language, checked_at: Time.now.utc.iso8601, capture_format: 'CoreGraphics/CoreText opaque PNG',
      note: 'Technical validation does not establish visual approval or store persistence.', files: records }
    File.write(File.join(destination, 'validation.json'), JSON.pretty_generate(manifest) + "\n")
    puts "Rendered and pixel-validated four #{language} Duo panels. Visual review and store readback remain required."
    $stdout.flush
  end
end
