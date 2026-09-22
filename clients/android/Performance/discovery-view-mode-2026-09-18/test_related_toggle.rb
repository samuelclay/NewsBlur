require 'open3'
require 'rexml/document'

# test_related_toggle.rb starts with Related Sites open and verifies its icon-only toggle.
adb = ['adb', '-s', ARGV.fetch(0)]
run = lambda do |*args|
  output, error, status = Open3.capture3(*adb, *args)
  abort(output + error) unless status.success?
  output
end
snapshot = lambda do
  run.call('shell', 'rm', '-f', '/sdcard/newsblur-related-toggle.xml')
  output = run.call('shell', 'uiautomator', 'dump', '/sdcard/newsblur-related-toggle.xml')
  abort('Could not capture current UI') unless output.include?('dumped to:')
  REXML::XPath.match(REXML::Document.new(run.call('exec-out', 'cat', '/sdcard/newsblur-related-toggle.xml')), '//node')
end
nodes = snapshot.call
abort('FAIL: Related Sites panel is missing') unless nodes.any? { |n| n.attributes['text'] == 'Related Sites' }
abort('FAIL: Related Sites uses a text GRID/LIST button') if nodes.any? { |n| %w[GRID LIST Grid List].include?(n.attributes['text']) }
button = nodes.find { |n| ['Show grid', 'Show list'].include?(n.attributes['content-desc']) }
abort('FAIL: Related Sites has no accessible shared grid/list icon') unless button
abort('FAIL: toggle still has visible text') unless button.attributes['text'].to_s.empty?
expected = button.attributes['content-desc'] == 'Show grid' ? 'Show list' : 'Show grid'
x1,y1,x2,y2 = button.attributes['bounds'].scan(/\d+/).map(&:to_i)
run.call('shell', 'input', 'tap', ((x1+x2)/2).to_s, ((y1+y2)/2).to_s)
abort('FAIL: icon toggle did not change view mode') unless snapshot.call.any? { |n| n.attributes['content-desc'] == expected }
puts 'PASS: Related Sites uses an accessible icon-only toggle that switches view mode'
run.call('shell', 'rm', '-f', '/sdcard/newsblur-related-toggle.xml')
