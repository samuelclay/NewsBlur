# capture-resume.rb refuses to skip incomplete, mismatched or truncated captures.
require 'digest'
require 'json'
require 'open3'

module CaptureResume
  def self.still_complete?(image, expected)
    proof = image.sub(/\.png$/, '.json')
    xml = image.sub(/\.png$/, '.xml')
    return false unless [image, proof, xml].all? { |path| File.file?(path) }
    metadata = JSON.parse(File.read(proof))
    expected.all? { |key, value| metadata[key] == value } &&
      metadata['sha256'] == Digest::SHA256.file(image).hexdigest &&
      File.binread(image, 8) == "\x89PNG\r\n\x1a\n".b &&
      File.read(xml).include?('com.newsblur.storecapture')
  rescue JSON::ParserError, SystemCallError, TypeError
    false
  end

  def self.probe_video(path)
    out, err, status = Open3.capture3('ffprobe', '-v', 'error', '-select_streams', 'v:0', '-count_frames',
      '-show_entries', 'stream=width,height,codec_name,avg_frame_rate,nb_read_frames:format=duration', '-of', 'json', path)
    raise "Cannot inspect recording: #{err}" unless status.success?
    parsed = JSON.parse(out)
    stream = parsed.fetch('streams').first || {}
    { 'width' => stream.fetch('width'), 'height' => stream.fetch('height'), 'codec' => stream.fetch('codec_name'),
      'frame_rate' => stream.fetch('avg_frame_rate'), 'frame_count' => Integer(stream.fetch('nb_read_frames')),
      'duration' => Float(parsed.fetch('format').fetch('duration')) }
  end

  def self.valid_probe?(probe, dimensions)
    rate = probe.fetch('frame_rate').split('/').map { |value| Float(value) }
    probe.values_at('width', 'height') == dimensions && probe.fetch('codec') == 'h264' &&
      probe.fetch('duration').between?(1.5, 10) && probe.fetch('frame_count') >= 30 &&
      rate.length == 2 && rate.last.positive? && rate.first.positive?
  rescue KeyError, ArgumentError, TypeError
    false
  end

  def self.video_complete?(video, expected, still_hash, dimensions, probe: method(:probe_video))
    proof = video.sub(/\.mp4$/, '.json')
    hierarchy = video.sub(/\.mp4$/, '.xml')
    return false unless [video, proof, hierarchy].all? { |path| File.file?(path) }
    metadata = JSON.parse(File.read(proof))
    return false unless expected.all? { |key, value| metadata[key] == value } &&
      metadata['source_still_sha256'] == still_hash && metadata['sha256'] == Digest::SHA256.file(video).hexdigest &&
      metadata['hierarchy_sha256'] == Digest::SHA256.file(hierarchy).hexdigest
    actual = probe.call(video)
    actual == metadata['probe'] && valid_probe?(actual, dimensions)
  rescue JSON::ParserError, SystemCallError, RuntimeError, KeyError, ArgumentError, TypeError
    false
  end
end
