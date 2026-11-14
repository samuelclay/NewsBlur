require 'open3'
require 'tmpdir'

# test_menu_entrance.rb checks real intermediate frames in a stable patch of the Settings menu.
# Capture in light theme on the 1080x2340 Samsung using record_menu.rb, then pass the MP4 here.
video = ARGV.fetch(0)
mode = ARGV[1]
Dir.mktmpdir('newsblur-menu-motion') do |dir|
  metadata = File.join(dir, 'luma.txt')
  _out, err, status = Open3.capture3(
    'ffmpeg', '-hide_banner', '-loglevel', 'error', '-i', video,
    '-vf', "crop=40:40:700:600,signalstats,metadata=print:file=#{metadata}",
    '-fps_mode', 'passthrough', '-f', 'null', '-'
  )
  abort(err) unless status.success?
  frames = []
  time = nil
  File.foreach(metadata) do |line|
    time = line[/pts_time:(\S+)/, 1].to_f if line.start_with?('frame:')
    frames << [time, line.split('=').last.to_f] if line.start_with?('lavfi.signalstats.YAVG=')
  end
  abort('FAIL: recording contains too few frames') if frames.length < 4
  initial, final = frames.first.last, frames.last.last
  if mode == '--steady'
    low, high = frames.map(&:last).minmax
    abort("FAIL: open menu faded during update (luma range #{(high - low).round(2)})") if high - low > 4
    puts "PASS: open menu stayed opaque during update (luma range #{(high - low).round(2)})"
    next
  end
  abort('FAIL: menu did not change the sampled area') if (final - initial).abs < 8
  intermediate = frames.select do |_time, value|
    progress = (value - initial) / (final - initial)
    progress > 0.15 && progress < 0.85
  end
  duration = intermediate.empty? ? 0 : intermediate.last.first - intermediate.first.first
  if mode == '--instant'
    abort('FAIL: menu animated with system animations disabled') unless intermediate.empty?
    puts 'PASS: menu is immediately visible with system animations disabled'
    next
  end
  abort("FAIL: menu jumps into place (#{intermediate.length} intermediate frames, #{duration.round(3)}s)") unless intermediate.length >= 3 && duration >= 0.025
  puts "PASS: menu entrance has #{intermediate.length} intermediate frames spanning #{duration.round(3)}s"
end
