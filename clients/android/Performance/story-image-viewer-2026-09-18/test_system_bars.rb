require 'open3'

# test_system_bars.rb checks a real device with a story image viewer already open.
# Run: ruby test_system_bars.rb <adb serial>
adb = ['adb', '-s', ARGV.fetch(0)]
run = lambda do |*args|
  output, status = Open3.capture2e(*adb, *args)
  abort(output) unless status.success?
  output
end
run.call('shell', 'rm', '-f', '/sdcard/newsblur-image-bars.xml')
run.call('shell', 'uiautomator', 'dump', '/sdcard/newsblur-image-bars.xml')
hierarchy = run.call('exec-out', 'cat', '/sdcard/newsblur-image-bars.xml')
run.call('shell', 'rm', '-f', '/sdcard/newsblur-image-bars.xml')
abort('Open a story image first') unless hierarchy.include?('content-desc="Close image"')
display = run.call('shell', 'dumpsys', 'window', 'displays')
%w[statusBars navigationBars].each do |type|
  sources = display.lines.select { |line| line.include?("type=#{type} ") }
  abort("FAIL: #{type} hidden while image viewer is open") if sources.empty? || sources.any? { |line| !line.include?('visible=true') }
end
puts 'PASS: image viewer keeps status and navigation bars visible'
