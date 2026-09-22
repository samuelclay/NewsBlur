require 'open3'
require 'rexml/document'

# test_add_site_sheet.rb drives the actual plus button without installing an instrumentation APK.
# Start on the feed list, then run: ruby test_add_site_sheet.rb <adb serial> [--routes]
adb = ['adb', '-s', ARGV.fetch(0)]
run = lambda do |*args|
  output, status = Open3.capture2e(*adb, *args)
  abort(output) unless status.success?
  output
end
snapshot = lambda do
  run.call('shell', 'rm', '-f', '/sdcard/newsblur-add-site-test.xml')
  output = run.call('shell', 'uiautomator', 'dump', '/sdcard/newsblur-add-site-test.xml')
  abort("FAIL: could not capture current UI: #{output}") unless output.include?('dumped to:')
  REXML::Document.new(run.call('exec-out', 'cat', '/sdcard/newsblur-add-site-test.xml'))
end
find = lambda do |document, attribute, value|
  REXML::XPath.first(document, "//node[@#{attribute}='#{value}']")
end
tap = lambda do |node|
  abort('FAIL: required control is missing') unless node
  x1, y1, x2, y2 = node.attributes['bounds'].scan(/\d+/).map(&:to_i)
  run.call('shell', 'input', 'tap', ((x1 + x2) / 2).to_s, ((y1 + y2) / 2).to_s)
end

tap.call(find.call(snapshot.call, 'resource-id', 'com.newsblur:id/main_add_button'))
sheet = snapshot.call
focus = run.call('shell', 'dumpsys', 'window').lines.grep(/mCurrentFocus/).join
abort('FAIL: plus opened the full discovery activity instead of the compact Add Site sheet') if focus.include?('DiscoverSitesActivity')
abort('FAIL: URL input missing from Add Site sheet') unless find.call(sheet, 'content-desc', 'https:// or search')
abort('FAIL: folder input missing from Add Site sheet') unless find.call(sheet, 'text', '— Top Level —')
abort('FAIL: discovery shortcuts missing from Add Site sheet') unless find.call(sheet, 'text', 'Discover more to read')
%w[Popular Reddit].each do |label|
  abort("FAIL: #{label} shortcut missing") unless find.call(sheet, 'text', label)
end
keyboard = run.call('shell', 'dumpsys', 'input_method')
abort('FAIL: keyboard opened before tapping an input') if keyboard.include?('mInputShown=true')
puts 'PASS: plus opens the compact Add Site sheet with inputs and discovery shortcuts, keyboard closed'

if ARGV.include?('--routes')
  {
    'Trending' => 'Search', 'Web Feed' => 'Web Feed', 'Popular' => 'Popular',
    'YouTube' => 'YouTube', 'Reddit' => 'Reddit', 'Newsletters' => 'Newsletters',
    'Podcasts' => 'Podcasts', 'Google News' => 'Google News'
  }.each_with_index do |(label, tab), index|
    if index > 0
      tap.call(find.call(snapshot.call, 'resource-id', 'com.newsblur:id/main_add_button'))
      sheet = snapshot.call
    end
    target = find.call(sheet, 'text', label)
    4.times do
      break if target
      scroll = REXML::XPath.match(sheet, '//node').find { |node| node.attributes['scrollable'] == 'true' }
      abort("FAIL: #{label} shortcut unreachable") unless scroll
      x1, y1, x2, y2 = scroll.attributes['bounds'].scan(/\d+/).map(&:to_i)
      x = ((x1 + x2) / 2).to_s
      # test_add_site_sheet.rb stays clear of Samsung's bottom system gesture area.
      margin = [(y2 - y1) / 4, 150].min
      run.call('shell', 'input', 'swipe', x, (y2 - margin).to_s, x, (y1 + margin).to_s, '400')
      sheet = snapshot.call
      target = find.call(sheet, 'text', label)
    end
    tap.call(target)
    page = snapshot.call
    focus = run.call('shell', 'dumpsys', 'window').lines.grep(/mCurrentFocus/).join
    abort("FAIL: #{label} did not open full discovery") unless focus.include?('DiscoverSitesActivity')
    chip = find.call(page, 'text', tab)
    abort("FAIL: #{label} did not select #{tab}") unless chip && chip.parent.attributes['checked'] == 'true'
    if label == 'Trending'
      abort('FAIL: Trending did not open Trending this week') unless find.call(page, 'text', 'Trending this week')
    end
    run.call('shell', 'input', 'keyevent', 'KEYCODE_BACK')
    returned = snapshot.call
    abort("FAIL: Back from #{label} did not return to feed list") unless find.call(returned, 'resource-id', 'com.newsblur:id/main_add_button')
    abort("FAIL: #{label} left the compact sheet behind") if find.call(returned, 'text', 'Discover more to read')
    puts "PASS: #{label} opens #{tab}, and Back returns directly to feeds"
  end
end
run.call('shell', 'rm', '-f', '/sdcard/newsblur-add-site-test.xml')
