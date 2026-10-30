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
  parser.on('--revision NAME', 'Create new panels 1 and 4; preserve the original export set') { |value| options[:revision] = value }
  parser.on('--revision-inputs PATH', 'JSON with closed_frame_spec and per-language closed/fullscreen captures') { |value| options[:inputs] = value }
end.parse!
abort 'Choose either --language CODE or --all.' if !!options[:all] == !!options[:language]
supported = JSON.parse(File.read(File.expand_path('../../../../../../localization/languages.json', root))).keys
languages = options[:all] ? supported : [options[:language]]
abort 'Unsupported canonical language.' unless (languages - supported).empty?

def run!(*args)
  output, status = Open3.capture2e(*args)
  abort "Command failed: #{args.first}\n#{output}" unless status.success?
  output
end

abort '--revision and --revision-inputs must be used together.' if !!options[:revision] != !!options[:inputs]
if options[:revision]
  revision = options[:revision]
  abort 'Revision must be a safe name such as v2.' unless revision.match?(/\A[a-z][a-z0-9-]*\z/)
  input_path = File.expand_path(options[:inputs])
  inputs = JSON.parse(File.read(input_path))
  resolve_input = ->(path) { File.expand_path(path, File.dirname(input_path)) }
  frame_spec = resolve_input.call(inputs.fetch('closed_frame_spec'))
  frame = JSON.parse(File.read(frame_spec))
  abort 'Panel 1 requires an explicitly measured closed frame.' unless frame.fetch('pose') == 'closed'
  frame_path = File.expand_path(frame.fetch('frame'), File.dirname(frame_spec))
  selected = languages.to_h do |language|
    captures = inputs.fetch('languages').fetch(language)
    closed = resolve_input.call(captures.fetch('closed_capture'))
    fullscreen = resolve_input.call(captures.fetch('fullscreen_capture'))
    original = (1..4).map do |panel|
      File.join(root, 'exports', language, "newsblur-16.0.1-#{language}-duo-inner-2853x2007-#{format('%02d', panel)}.png")
    end
    [frame_path, closed, fullscreen, *original].each { |path| abort "Missing source: #{path}" unless File.file?(path) }
    destination = File.join(root, 'revisions', revision, 'exports', language)
    abort "Existing revision is preserved: #{destination}" if File.exist?(destination)
    [language, { closed: closed, fullscreen: fullscreen, original: original, destination: destination }]
  end
  Dir.mktmpdir('newsblur-duo-revision-', '/tmp') do |temporary|
    binary = File.join(temporary, 'render')
    run!('swiftc', File.join(root, 'native-render.swift'), '-o', binary)
    selected.each do |language, source|
      paths = [input_path, frame_spec, frame_path, source[:closed], source[:fullscreen], *source[:original],
        File.join(root, 'native-render.swift'), __FILE__, File.join(root, "../../16.0/screenshots/copy/#{language}.json"),
        File.join(root, '../../16.0/screenshots/verify-native-pixels.rb'), File.join(root, '../../16.0/selected/assets/icon.png'),
        File.join(root, 'assets/iphone-duo-inner-landscape.png')].map { |path| File.expand_path(path) }.uniq
      hashes = paths.to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }
      evidence = []
      rendered = {}
      records = (1..4).map do |panel|
        original = source[:original][panel - 1]
        if [2, 3].include?(panel)
          next { path: original.delete_prefix(root + '/'), panel: panel, sha256: hashes.fetch(original),
            disposition: 'original_preserved_byte_for_byte', bytes: File.size(original) }
        end
        capture = panel == 1 ? source[:closed] : source[:fullscreen]
        pose = panel == 1 ? 'closed' : 'inner'
        name = "newsblur-16.0.1-#{language}-duo-#{pose}-2853x2007-#{format('%02d', panel)}-#{revision}.png"
        output = File.join(temporary, name)
        command = [binary, '--root', root, '--language', language, '--size', '2853x2007', '--panel', panel.to_s,
          '--capture', capture, '--output', output]
        command += ['--frame-spec', frame_spec] if panel == 1
        run!(*command)
        item = JSON.parse(File.read(output.sub(/\.png$/, '.json')))
        bytes = File.binread(output)
        abort 'Invalid PNG signature or dimensions.' unless bytes.start_with?("\x89PNG\r\n\x1a\n".b) && bytes[16, 8].unpack('NN') == [2853, 2007]
        abort 'PNG must be opaque.' unless run!('sips', '-g', 'hasAlpha', output).include?('hasAlpha: no')
        pixel = NativePixelCheck.check(output, capture, item.fetch('capture_bounds'))
        relative = "revisions/#{revision}/exports/#{language}/#{name}"
        sha = Digest::SHA256.hexdigest(bytes)
        evidence << item.merge('output' => relative, 'capture_sha256' => hashes.fetch(capture),
          'source_sha256' => hashes, 'output_sha256' => sha)
        rendered[panel] = output
        { path: relative, panel: panel, width: 2853, height: 2007, opaque: true, bytes: bytes.bytesize,
          sha256: sha, native_pixel_check: pixel, visual_review: 'required', store_upload: 'unverified' }
      end
      hashes.each { |path, sha| abort "Source changed: #{path}" unless Digest::SHA256.file(path).hexdigest == sha }
      contact = File.join(temporary, "contact-#{language}.png")
      filters = (0..3).map { |index| "[#{index}:v]scale=856:-1[p#{index}]" }.join(';') +
        ';[p0][p1][p2][p3]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0[out]'
      run!('ffmpeg', '-v', 'error', '-y', *records.flat_map { |record| ['-i', rendered.fetch(record[:panel], File.join(root, record[:path]))] },
        '-filter_complex', filters, '-map', '[out]', '-frames:v', '1', contact)
      FileUtils.mkdir_p(source[:destination])
      rendered.each_value { |path| FileUtils.cp(path, source[:destination]) }
      FileUtils.cp(contact, File.join(source[:destination], 'contact.png'))
      File.write(File.join(source[:destination], 'render-checks.json'), JSON.pretty_generate(evidence) + "\n")
      manifest = { language: language, revision: revision, checked_at: Time.now.utc.iso8601,
        note: 'Only panels 1 and 4 are new. Panels 2 and 3 reference unchanged original exports. Visual review and store readback remain required.', files: records }
      File.write(File.join(source[:destination], 'validation.json'), JSON.pretty_generate(manifest) + "\n")
      puts "Rendered and pixel-validated #{language} panels 1 and 4 (#{revision}); originals preserved."
      $stdout.flush
    end
  end
  exit
end

# Refuse partial replacement of previously reviewed or uploaded files.
languages.each do |language|
  destination = File.join(root, 'exports', language)
  abort "Existing export set is preserved: #{destination}" if Dir.glob(File.join(destination, '*.png')).any?
  %w[stories feeds reader saved].each do |view|
    capture = File.join(root, 'captures', language, "duo-#{view}.png")
    abort "Missing capture: #{capture}" unless File.file?(capture)
  end
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
