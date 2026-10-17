#!/usr/bin/env ruby
# capture-tablet.rb composes only real native panes, after the isolated harness has seeded its account.
require 'json'
require 'fileutils'
require 'open3'
require 'digest'

root = File.expand_path(__dir__)
serial, device, *languages = ARGV
abort 'Usage: capture-tablet.rb SERIAL tablet7|tablet10 LANGUAGE...' unless serial && %w[tablet7 tablet10].include?(device) && !languages.empty?
supported = JSON.parse(File.read(File.expand_path('../../../../../localization/languages.json', root)))
abort 'Unsupported language' unless (languages - supported.keys).empty?
def command(*args)
  out, err, status = Open3.capture3(*args)
  raise "Command failed: #{args.inspect}: #{err}" unless status.success?
  out
end
adb = ['adb', '-s', serial]
def read_window(adb)
  command(*adb, 'shell', 'uiautomator', 'dump', '/sdcard/newsblur-capture.xml')
  command(*adb, 'shell', 'cat', '/sdcard/newsblur-capture.xml')
end
def await_content(adb, expected)
  12.times do
    sleep 1
    xml = read_window(adb)
    return xml if xml.include?(expected)
  end
  raise "Native content never became ready: #{expected}"
end
languages.each do |language|
  rtl = %w[ar he].include?(language)
  %w[feeds stories reader saved].each do |scene|
    directory = File.join(root, 'captures', language)
    FileUtils.mkdir_p(directory)
    image = File.join(directory, "#{device}-#{scene}.png")
    proof = image.sub('.png', '.json')
    video = File.join(root, 'captures', 'footage', language, "#{device}-#{scene}.mp4")
    next if File.exist?(image) && File.exist?(proof) && JSON.parse(File.read(proof))['tablet_composition'] == 'populated_native_split' && (device == 'tablet7' || File.exist?(video))
    command(*adb, 'shell', 'am', 'force-stop', 'com.newsblur.storecapture')
    launch_scene = scene == 'feeds' ? 'reader' : scene
    command(*adb, 'shell', 'am', 'start', '-W', '-n', 'com.newsblur.storecapture/com.newsblur.marketing.StoreCaptureActivity', '--es', 'language', language, '--es', 'screen', launch_scene)
    await_content(adb, 'Pesto pasta with blistered tomatoes')
    sleep 2
    screenshot = command(*adb, 'exec-out', 'screencap', '-p')
    width, height = screenshot[16, 8].unpack('NN')
    if scene == 'feeds'
      # The native story-list back button opens the real feed drawer over its populated reader.
      # Android's native split keeps its 40% list pane on the left in RTL too.
      command(*adb, 'shell', 'input', 'tap', (rtl ? (width * 0.4).to_i - 39 : 39).to_s, '78')
      xml = await_content(adb, 'A Bowl of Greens')
    elsif %w[stories saved].include?(scene)
      # Select the first real story in the list rather than presenting the tablet placeholder pane.
      command(*adb, 'shell', 'input', 'tap', (width * 0.2).to_i.to_s, '202')
      xml = await_content(adb, 'Pesto pasta with blistered tomatoes')
    else
      xml = read_window(adb)
    end
    sleep 2
    File.write(image.sub('.png', '.xml'), xml)
    File.binwrite(image, command(*adb, 'exec-out', 'screencap', '-p'))
    File.write(proof, JSON.pretty_generate({language: language, device: device, serial: serial, scene: scene, package: 'com.newsblur.storecapture', captured_at: Time.now.utc.to_s, sha256: Digest::SHA256.file(image).hexdigest, native_readiness: 'expected fixture content visible', tablet_composition: 'populated_native_split', visual_review: 'required'}) + "\n")
    puts "Captured #{language}/#{device}/#{scene}"
    $stdout.flush
    next if device == 'tablet7'
    footage = File.join(root, 'captures', 'footage', language)
    FileUtils.mkdir_p(footage)
    remote = '/sdcard/newsblur-capture.mp4'
    pid = Process.spawn(*adb, 'shell', 'screenrecord', '--bit-rate', '10000000', '--time-limit', '6', remote, out: File::NULL)
    sleep 1
    ratio = scene == 'reader' ? 0.75 : 0.2
    x = (width * ratio).to_i
    command(*adb, 'shell', 'input', 'swipe', x.to_s, (height * 0.72).to_i.to_s, x.to_s, (height * 0.47).to_i.to_s, '1200')
    Process.wait(pid)
    raise 'Recording failed' unless $?.success?
    command(*adb, 'pull', remote, File.join(footage, "#{device}-#{scene}.mp4"))
    puts "Recorded #{language}/#{device}/#{scene}"
    $stdout.flush
  end
end
