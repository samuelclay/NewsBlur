require 'open3'
require 'rexml/document'
STDOUT.sync = true

# test_remembered_view.rb exercises the shared preference using the installed app, without instrumentation.
# Run with List selected (or with no preference): ruby test_remembered_view.rb <serial>
ADB = ['adb', '-s', ARGV.fetch(0)]
def run(*args)
  output, error, status = Open3.capture3(*ADB, *args)
  abort(output + error) unless status.success?
  output
end
def snapshot
  3.times do
    run('shell', 'rm', '-f', '/sdcard/newsblur-view-mode.xml')
    output, error, status = Open3.capture3(*ADB, 'shell', 'uiautomator', 'dump', '/sdcard/newsblur-view-mode.xml')
    if status.success? && output.include?('dumped to:')
      return REXML::XPath.match(REXML::Document.new(run('exec-out', 'cat', '/sdcard/newsblur-view-mode.xml')), '//node')
    end
  end
  abort('FAIL: could not capture current UI')
end
def find_control(attribute, value)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20
  loop do
    node = snapshot.find { |n| n.attributes[attribute] == value && n.attributes['bounds'] != '[0,0][0,0]' }
    return node if node
    abort("FAIL: missing #{attribute}: #{value}") if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
  end
end
def tap_control(attribute, value)
  node = find_control(attribute, value)
  x1,y1,x2,y2 = node.attributes['bounds'].scan(/\d+/).map(&:to_i)
  run('shell', 'input', 'tap', ((x1+x2)/2).to_s, ((y1+y2)/2).to_s)
end
def assert_mode(mode)
  action = mode == 'list' ? 'Show grid' : 'Show list'
  find_control('content-desc', action)
  puts "PASS: #{mode} mode selected"
end
def back
  run('shell', 'input', 'keyevent', '4')
  snapshot
end
def cold_launch
  run('shell', 'am', 'force-stop', 'com.newsblur')
  run('shell', 'monkey', '-p', 'com.newsblur', '-c', 'android.intent.category.LAUNCHER', '1')
  find_control('resource-id', 'com.newsblur:id/main_add_button')
end
def open_discovery
  tap_control('resource-id', 'com.newsblur:id/main_add_button')
  tap_control('text', 'Popular')
end

cold_launch
open_discovery
assert_mode('list')
tap_control('content-desc', 'Show grid')
assert_mode('grid')
back
open_discovery
assert_mode('grid')
puts 'PASS: Add + Discover remembers Grid after closing and reopening'
cold_launch
open_discovery
assert_mode('grid')
puts 'PASS: Grid survives process restart'
back
tap_control('text', 'Slashdot')
tap_control('content-desc', 'Related Sites')
assert_mode('grid')
tap_control('content-desc', 'Show list')
assert_mode('list')
back
tap_control('content-desc', 'Related Sites')
assert_mode('list')
puts 'PASS: Related Sites shares the preference and remembers List on reopening'
back
back
open_discovery
assert_mode('list')
puts 'PASS: Related Sites selection updates Add + Discover'
cold_launch
open_discovery
assert_mode('list')
puts 'PASS: List survives process restart'
run('shell', 'rm', '-f', '/sdcard/newsblur-view-mode.xml')
