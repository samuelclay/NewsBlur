require 'json'
require 'digest'
require 'open3'

root = __dir__
languages = JSON.parse(File.read(File.expand_path('../../../../../../localization/languages.json', root))).keys.sort
copy_languages = Dir[File.join(root, 'copy', '*.json')].map { |file| File.basename(file, '.json') }.sort
raise 'Expected exactly the 21 supported copy locales' unless languages.length == 21 && copy_languages == languages

placements = {
  'header' => { extension: 'png', format: 'PNG', width: 3840, height: 1646, magic: "\x89PNG\r\n\x1a\n".b },
  'search' => { extension: 'jpg', format: 'JPEG', width: 3840, height: 2560, magic: "\xff\xd8\xff".b }
}

# validate.rb enumerates canonical names, so historical and trial exports cannot enter manifest.json.
rows = languages.flat_map do |language|
  JSON.parse(File.read(File.join(root, 'copy', "#{language}.json")))
  placements.map do |placement, spec|
    file = File.join(root, 'exports', "#{language}-#{placement}.#{spec.fetch(:extension)}")
    raise "Missing canonical export: #{file}" unless File.file?(file)
    raise "Wrong image signature: #{file}" unless File.binread(file, spec.fetch(:magic).bytesize) == spec.fetch(:magic)

    info, status = Open3.capture2e('sips', '-g', 'pixelWidth', '-g', 'pixelHeight', '-g', 'hasAlpha', '-g', 'format', file)
    raise "Cannot inspect #{file}: #{info}" unless status.success?
    width = info[/pixelWidth: (\d+)/, 1]&.to_i
    height = info[/pixelHeight: (\d+)/, 1]&.to_i
    raise "Wrong dimensions #{file}: #{width}x#{height}" unless [width, height] == spec.values_at(:width, :height)
    raise "Wrong decoded format: #{file}" unless info[/format: (\S+)/, 1]&.upcase == spec.fetch(:format)
    raise "Image must have no alpha channel: #{file}" unless info[/hasAlpha: (\S+)/, 1] == 'no'

    {
      file: File.basename(file), language: language, placement: placement,
      width: width, height: height, format: spec.fetch(:format), opaque: true,
      bytes: File.size(file), sha256: Digest::SHA256.file(file).hexdigest
    }
  end
end

raise "Expected 42 canonical assets, got #{rows.length}" unless rows.length == 42
File.write(File.join(root, 'exports', 'manifest.json'), JSON.pretty_generate(rows) + "\n")
puts 'Validated 42 canonical opaque assets: 21 PNG headers and 21 JPEG search images; wrote SHA-256 manifest.'
