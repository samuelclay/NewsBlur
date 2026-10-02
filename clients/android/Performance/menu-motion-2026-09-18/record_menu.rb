require 'open3'
require 'fileutils'

# record_menu.rb records the supplied menu control without an instrumentation APK.
# Run with its menu closed: ruby record_menu.rb <serial> <output.mp4> <x> <y> [hold_ms]
serial, output, x, y, hold = ARGV
abort('Expected serial, output.mp4, x, y, optional hold_ms') unless y
adb = ['adb', '-s', serial]
remote = '/sdcard/newsblur-menu-motion.mp4'
run = lambda do |*args|
  out, err, status = Open3.capture3(*adb, *args)
  abort(out + err) unless status.success?
  out
end
FileUtils.mkdir_p(File.dirname(output))
pid = Process.spawn(*adb, 'shell', 'screenrecord', '--time-limit', '5', '--bit-rate', '12000000', remote)
sleep 1
if hold
  run.call('shell', 'input', 'swipe', x, y, x, y, hold)
else
  run.call('shell', 'input', 'tap', x, y)
end
Process.wait(pid)
run.call('pull', remote, output)
run.call('shell', 'rm', '-f', remote)
puts output
