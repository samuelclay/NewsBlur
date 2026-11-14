require 'open3'
require 'rexml/document'
require 'fileutils'

# test_story_preview.rb starts on a discovery list with the supplied story title visible.
# It verifies that selecting that story opens the native feed reader at that exact story.
serial, title = ARGV
abort('Expected device serial and visible story title') unless title
adb = ['adb', '-s', serial]
run = lambda do |*args|
  output, error, status = Open3.capture3(*adb, *args)
  abort(output + error) unless status.success?
  output
end
snapshot = lambda do
  document = nil
  diagnostic = ''
  3.times do
    run.call('shell', 'rm', '-f', '/sdcard/newsblur-discovery-test.xml')
    output, error, status = Open3.capture3(*adb, 'shell', 'uiautomator', 'dump', '/sdcard/newsblur-discovery-test.xml')
    diagnostic = "#{output}#{error} (exit #{status.exitstatus})"
    if status.success? && output.include?('dumped to:')
      document = REXML::Document.new(run.call('exec-out', 'cat', '/sdcard/newsblur-discovery-test.xml'))
      break
    end
    # test_story_preview.rb retries fresh captures when Samsung UI automation races an activity transition.
    sleep 0.5
  end
  abort("FAIL: could not capture current UI: #{diagnostic}") unless document
  REXML::XPath.match(document, '//node')
end
capture = lambda do |name|
  if ENV['STORY_PROOF_DIR']
    FileUtils.mkdir_p(ENV['STORY_PROOF_DIR'])
    File.binwrite(File.join(ENV['STORY_PROOF_DIR'], "#{name}.png"), run.call('exec-out', 'screencap', '-p'))
  end
end
node = snapshot.call.find { |n| n.attributes['text'] == title }
abort("FAIL: missing visible discovery story: #{title}") unless node
capture.call('before')
x1, y1, x2, y2 = node.attributes['bounds'].scan(/\d+/).map(&:to_i)
run.call('shell', 'input', 'tap', ((x1 + x2) / 2).to_s, ((y1 + y2) / 2).to_s)
opened = false
40.times do
  focus = run.call('shell', 'dumpsys', 'window').lines.find { |line| line.include?('mCurrentFocus') }.to_s
  if focus.include?('.activity.FeedReading')
    opened = true
    break
  end
  sleep 0.25
end
abort('FAIL: tapping the discovery story did not open the native feed reader') unless opened
deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 25
loop do
  break if snapshot.call.any? { |n| n.attributes['text'] == title }
  abort('FAIL: reader did not open the selected story') if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
end
puts "PASS: discovery opens the exact selected story: #{title}"
capture.call('opened')
if ARGV.include?('--return') || ARGV.include?('--try')
  run.call('shell', 'input', 'keyevent', '4')
  feed_list = snapshot.call
  if ARGV.include?('--try')
    abort('FAIL: selected story was not opened in Try Feed') unless feed_list.any? { |n| n.attributes['text'] == 'Preview. Not yet subscribed.' }
    puts 'PASS: Back returns to the unsubscribed Try Feed list'
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 25
    until feed_list.any? { |n| n.attributes['resource-id'].to_s.match?(/:id\/story_(?:item|cluster)_title$/) }
      abort('FAIL: Try Feed has no story titles after returning from the article') if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      feed_list = snapshot.call
    end
    puts 'PASS: Try Feed displays story titles after returning from the selected article'
    capture.call('feed-list')
  end
  run.call('shell', 'input', 'keyevent', '4')
  returned = snapshot.call.find { |n| n.attributes['text'] == title }
  abort('FAIL: Back lost the selected discovery story or scroll position') unless returned
  ry1 = returned.attributes['bounds'].scan(/\d+/).map(&:to_i)[1]
  abort('FAIL: discovery scroll position changed on return') if (ry1 - y1).abs > 3
  selected = false
  cursor = returned
  while cursor.is_a?(REXML::Element)
    # test_story_preview.rb accepts Compose's accessibility mapping of selected buttons to checked nodes.
    selected ||= cursor.attributes['selected'] == 'true' || cursor.attributes['checked'] == 'true'
    cursor = cursor.parent
  end
  abort('FAIL: returned discovery story is not highlighted') unless selected
  puts 'PASS: discovery retains the selected row and scroll position on return'
  capture.call('returned')
end
run.call('shell', 'rm', '-f', '/sdcard/newsblur-discovery-test.xml')
