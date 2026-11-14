# test_footer_overlay.rb checks a logged-in device with a story list open, Bottom selected, and the keyboard closed.
require 'rexml/document'

device = ARGV.fetch(0)
adb = ['adb', '-s', device]
abort('Could not dump device UI') unless system(*adb, 'shell', 'uiautomator', 'dump', '/sdcard/footer-overlay.xml', out: File::NULL)
xml = IO.popen(adb + ['exec-out', 'cat', '/sdcard/footer-overlay.xml'], &:read)
nodes = REXML::Document.new(xml).get_elements('//node')
def bounds(node)
  abort('Required story-list view is missing') unless node
  node.attributes['bounds'].scan(/\d+/).map(&:to_i)
end
screen = bounds(nodes.first)
list = bounds(nodes.find { |node| node.attributes['resource-id'] == 'com.newsblur:id/itemgridfragment_grid' })
button = bounds(nodes.find { |node| node.attributes['content-desc'] == 'Search' })
abort("Story list stops at #{list[3]}; expected the screen bottom #{screen[3]}") unless list[3] == screen[3]
abort('The toolbar does not overlay the story-list viewport') unless button[1] > list[1] && button[3] < list[3]
puts "PASS: story list extends to #{list[3]}, behind floating controls at #{button[1]}–#{button[3]}"
