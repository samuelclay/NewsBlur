require 'open3'
require 'rexml/document'
ADB=['/Users/sclay/Library/Android/sdk/platform-tools/adb','-s','emulator-5554']
PROOF=File.expand_path(__dir__)
def cmd(*args)
 out,err,status=Open3.capture3(*ADB,*args)
 abort(out+err) unless status.success?
 out
end
def nodes
 cmd('shell','uiautomator','dump','/sdcard/nb-scroll-test.xml')
 xml=cmd('exec-out','cat','/sdcard/nb-scroll-test.xml')
 REXML::XPath.match(REXML::Document.new(xml),'//node')
end
def header
 node=nodes.find { |n| n.attributes['text']=='Add site' }
 node && node.attributes['bounds'].scan(/\d+/).map(&:to_i)
end
prefix=ARGV.fetch(0,'after')
2.times { cmd('shell','input','swipe','540','2140','540','1690','350') }
sleep 0.5
before=header
before_results=nodes.select { |n| n.attributes['text'].start_with?('http') }.map { |n| [n.attributes['text'], n.attributes['bounds']] }
abort 'Precondition: open Add site and search kottke before running' unless before
File.binwrite("#{PROOF}/#{prefix}-scroll-at-bottom.png",cmd('exec-out','screencap','-p'))
cmd('shell','input','swipe','540','1770','540','2050','700')
sleep 0.5
after=header
after_results=nodes.select { |n| n.attributes['text'].start_with?('http') }.map { |n| [n.attributes['text'], n.attributes['bounds']] }
File.binwrite("#{PROOF}/#{prefix}-scroll-back.png",cmd('exec-out','screencap','-p'))
puts "Header before=#{before.inspect}, after=#{after.inspect}"
abort 'FAIL: scrolling up through results moved or dismissed the sheet' unless after && (after[1]-before[1]).abs <= 2
abort 'FAIL: downward gesture did not scroll the results back up' if before_results == after_results
puts 'PASS: sheet stayed anchored during downward list scrolling'
