require 'open3'
require 'rexml/document'

# test_action_row.rb checks visible discovery card geometry on the actual device.
serial, folder = ARGV
folder ||= 'Top Level'
adb = ['adb', '-s', serial || abort('Expected device serial')]
run = lambda do |*args|
  output, error, status = Open3.capture3(*adb, *args)
  abort(output + error) unless status.success?
  output
end
run.call('shell', 'rm', '-f', '/sdcard/newsblur-discovery-row.xml')
output = run.call('shell', 'uiautomator', 'dump', '/sdcard/newsblur-discovery-row.xml')
abort(output) unless output.include?('dumped to:')
nodes = REXML::XPath.match(REXML::Document.new(run.call('exec-out', 'cat', '/sdcard/newsblur-discovery-row.xml')), '//node')
bounds = lambda { |node| node.attributes['bounds'].scan(/\d+/).map(&:to_i) }
center_y = lambda { |node| b = bounds.call(node); (b[1] + b[3]) / 2 }
adds = nodes.select { |n| n.attributes['text'] == 'Add' }
abort('FAIL: no visible unsubscribed card Add button') if adds.empty?
abort('FAIL: redundant folder title label remains visible') if nodes.any? { |n| n.attributes['text'].to_s.match?(/\AAdd to:?\s*\z/) }
adds.each do |add|
  row = nodes.select { |n| (center_y.call(n) - center_y.call(add)).abs < 24 }
  try = row.find { |n| n.attributes['text'] == 'Try' }
  picker = row.find { |n| n.attributes['text'] == folder }
  abort('FAIL: Try and shared folder are not beside Add') unless try && picker
  t, f, a = [try, picker, add].map { |n| bounds.call(n) }
  abort('FAIL: row is not ordered Try, folder, Add') unless t[2] < f[0] && f[2] < a[0]
end
puts "PASS: #{adds.length} visible rows have Try, unlabeled #{folder} folder, Add"
run.call('shell', 'rm', '-f', '/sdcard/newsblur-discovery-row.xml')
