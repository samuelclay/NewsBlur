#!/usr/bin/env ruby
# verify-native-pixels.rb detects missing browser painting by comparing the captured screen with its native PNG.
require 'json'
require 'open3'

module NativePixelCheck
  def self.sample(path, bounds)
    x, y, width, height = bounds.values_at('x', 'y', 'width', 'height')
    # Exclude rounded screen corners and hardware overlays; compare the central 80%.
    crop = [width * 0.8, height * 0.8, x + width * 0.1, y + height * 0.1].map(&:round)
    bytes, error, status = Open3.capture3('ffmpeg', '-v', 'error', '-i', path,
      '-vf', "crop=#{crop.join(':')},scale=64:64:flags=area", '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-')
    raise "Cannot decode screenshot pixels: #{error}" unless status.success? && bytes.bytesize == 64 * 64 * 3
    bytes.bytes
  end

  def self.check(render, capture, bounds)
    header = File.binread(capture, 24)
    raise 'Native capture must be PNG.' unless header.start_with?("\x89PNG\r\n\x1a\n".b)
    width, height = header[16, 8].unpack('NN')
    expected = sample(capture, { 'x' => 0, 'y' => 0, 'width' => width, 'height' => height })
    actual = sample(render, bounds)
    errors = actual.zip(expected).map { |a, b| (a - b).abs }
    mean = errors.sum / errors.length.to_f
    tiles = Array.new(16, 0.0)
    errors.each_with_index { |error, index| pixel = index / 3; tiles[(pixel / 64 / 16) * 4 + pixel % 64 / 16] += error / (16.0 * 16 * 3) }
    result = { mean_absolute_rgb_error: mean.round(4), largest_tile_error: tiles.max.round(4), mean_limit: 12, tile_limit: 25 }
    raise "Rendered native content mismatch: #{JSON.generate(result)}" if mean > 12 || tiles.max > 25
    result.merge(status: 'passed')
  end
end

if $PROGRAM_NAME == __FILE__
  abort 'Usage: verify-native-pixels.rb RENDER NATIVE X,Y,WIDTH,HEIGHT' unless ARGV.length == 3
  bounds = %w[x y width height].zip(ARGV[2].split(',').map { |v| Float(v) }).to_h
  puts JSON.pretty_generate(NativePixelCheck.check(ARGV[0], ARGV[1], bounds))
end
