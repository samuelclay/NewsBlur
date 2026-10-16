# Run from the repository root after backing up simulator app/shared preferences.
# capture_locales.rb uses only run_ios.py for simulator interaction and never boots a device.
require "fileutils"
require "json"
require "open3"
require "time"

device, *locales = ARGV
devices = {"iphone" => "011EB534-697E-4855-BACA-4D4C6E4E92EF", "ipad" => "883650D4-245E-4265-84A5-97606867CB5B"}
abort "Usage: ruby capture_locales.rb iphone|ipad locale..." unless devices.key?(device) && !locales.empty?
base = "clients/store/artwork/ios/16.0/screenshots"
wrapper = ["python3", "clients/ios/run_ios.py", "--udid", devices.fetch(device)]

locales.each do |locale|
  abort "Unsupported locale: #{locale}" unless File.file?("clients/store/artwork/ios/16.0/selected/copy/#{locale}.json")
  captures = locale == "en" ? "#{base}/captures" : "#{base}/captures/localized/#{locale}"
  footage = locale == "en" ? "#{base}/footage/#{device}" : "#{base}/footage/localized/#{locale}/#{device}"
  abort "Preserve the existing recording before recapturing: #{footage}" if File.exist?("#{footage}/scroll.mp4")
  FileUtils.mkdir_p(captures)
  FileUtils.mkdir_p(footage)
  rtl = %w[ar he].include?(locale)
  screen = device == "ipad" ? "reader-folder-tech" : "reader"
  arguments = "-newsblur-ui-testing -newsblur-marketing-cooking -newsblur-marketing-assets #{Dir.pwd}/clients/ios/MarketingCooking -newsblur-ui-test-screen #{screen} -newsblur-ui-test-story-titles-style standard -newsblur-ui-test-theme light -newsblur-ui-test-animations -ApplePersistenceIgnoreState YES -newsblur_language #{locale}"
  arguments += " -newsblur-ui-test-fill-window" if device == "ipad"
  env = {"IOS_LAUNCH_ARGUMENTS" => arguments, "IOS_CAPTURE_CPU" => "0", "PYTHONUNBUFFERED" => "1"}
  puts "START #{device} #{locale} #{Time.now.utc.iso8601}"
  STDOUT.flush
  abort "Launch failed: #{locale}" unless system(env, *wrapper, "terminate", "launch")
  ready = false
  30.times do
    output, _, status = Open3.capture3(env, *wrapper, "describe")
    if status.success? && output.include?("Weeknight Kitchen")
      ready = true
      break
    end
    sleep 2
  end
  abort "Fixture content never appeared: #{locale}" unless ready
  abort "Settling failed" unless system(env, *wrapper, "sleep:6")
  screenshot = ->(state) { "screenshot:#{captures}/#{device}-#{state}.png" }
  if device == "iphone"
    back = rtl ? 420 : 25
    list_back = rtl ? 390 : 25
    photo_x = rtl ? 0.02 : 0.84
    list_ready = ["waittext:A generous salad for a sunny afternoon", "waitphoto:#{photo_x},0.18,0.14,0.60"]
    reader_ready = ["waittext:story-reader-back", "waitphoto:0.25,0.50,0.50,0.30"]
    actions = ["capture:#{footage}", "checkpoint:feeds", screenshot.call("feeds"), "sleep:5",
               "tap:120,240", *list_ready, "sleep:2", "checkpoint:stories", screenshot.call("stories"), "sleep:5",
               "tap:150,160", *reader_ready, "sleep:2", "checkpoint:reader", screenshot.call("reader"), "sleep:5",
               "swipe:300,700,300,500,0.8", "sleep:2", "tap:#{back},85", "sleep:1",
               "tap:#{list_back},85", "waittext:Breakfast Notebook", "sleep:1", "tap:150,655",
               "waittext:What to cook when autumn arrives", *list_ready, "sleep:2",
               "checkpoint:saved", screenshot.call("saved"), "sleep:5"]
  else
    sidebar = rtl ? 996 : 36
    close_sidebar = rtl ? 750 : 282
    expand = rtl ? 142 : 890
    story_x = rtl ? 872 : 160
    folder_x = rtl ? 922 : 110
    list_photo_x = rtl ? 0.63 : 0.32
    article_photo_x = rtl ? 0.10 : 0.60
    fullscreen_photo_x = rtl ? 0.70 : 0.10
    list_ready = ["waittext:A generous salad for a sunny afternoon", "waitphoto:#{list_photo_x},0.38,0.05,0.40"]
    article_ready = ["waitphoto:#{article_photo_x},0.40,0.30,0.40"]
    abort "iPad preparation failed" unless system(env, *wrapper, *list_ready, *article_ready,
                                                 "tap:#{expand},54", "sleep:2",
                                                 "waitphoto:#{fullscreen_photo_x},0.45,0.20,0.40",
                                                 "tap:#{expand},54", *list_ready, *article_ready, "sleep:2",
                                                 "tap:#{sidebar},54", "waittext:Breakfast Notebook", "sleep:2")
    actions = ["capture:#{footage}", "checkpoint:feeds", screenshot.call("feeds"), "sleep:5",
               "tap:#{close_sidebar},54", *list_ready, *article_ready, "sleep:2", "checkpoint:stories", screenshot.call("stories"), "sleep:5",
               "tap:#{story_x},145", "sleep:2", "tap:#{expand},54", "sleep:2",
               "waitphoto:#{fullscreen_photo_x},0.45,0.20,0.40",
               "checkpoint:reader", screenshot.call("reader"), "sleep:5",
               "swipe:750,1050,750,730,0.8", "sleep:2", "tap:#{expand},54",
               "waittext:A generous salad for a sunny afternoon", "sleep:2", "tap:#{sidebar},54", "waittext:Breakfast Notebook", "tap:#{folder_x},662",
               "waittext:What to cook when autumn arrives", *list_ready, "tap:#{story_x},540", *article_ready, "sleep:3",
               "checkpoint:saved", screenshot.call("saved"), "sleep:5"]
  end
  abort "Capture failed: #{locale}" unless system(env, *wrapper, *actions)
  puts "DONE #{device} #{locale}"
  STDOUT.flush
end
