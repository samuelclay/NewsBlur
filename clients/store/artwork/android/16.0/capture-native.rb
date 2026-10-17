#!/usr/bin/env ruby
# capture-native.rb records the isolated cooking app without touching signed-in apps.
require 'json'
require 'fileutils'
require 'open3'
require 'digest'
require_relative 'capture-resume'

root = File.expand_path(__dir__)
serial, device, *languages = ARGV
abort 'Usage: capture-native.rb SERIAL phone|tablet7|tablet10 LANGUAGE...' unless serial && %w[phone tablet7 tablet10].include?(device) && !languages.empty?
supported = JSON.parse(File.read(File.expand_path('../../../../../localization/languages.json', root)))
abort 'Unsupported language' unless (languages - supported.keys).empty?
def command(*args)
  out, err, status = Open3.capture3(*args)
  raise "Command failed: #{args.inspect}: #{err}" unless status.success?
  out
end
adb = ['adb', '-s', serial]
languages.each do |language|
  %w[feeds stories reader saved].each do |scene|
    directory = File.join(root, 'captures', language)
    FileUtils.mkdir_p(directory)
    image = File.join(directory, "#{device}-#{scene}.png")
    proof = image.sub('.png', '.json')
    identity = { 'language' => language, 'device' => device, 'serial' => serial, 'scene' => scene, 'package' => 'com.newsblur.storecapture' }
    still_complete = CaptureResume.still_complete?(image, identity)
    footage = File.join(root, 'captures', 'footage', language)
    video = File.join(footage, "#{device}-#{scene}.mp4")
    if still_complete
      still_hash = Digest::SHA256.file(image).hexdigest
      dimensions = File.binread(image, 24)[16, 8].unpack('NN')
      next if device == 'tablet7' || CaptureResume.video_complete?(video, identity, still_hash, dimensions)
    end
    command(*adb, 'shell', 'am', 'force-stop', 'com.newsblur.storecapture')
    command(*adb, 'shell', 'am', 'start', '-W', '-n', 'com.newsblur.storecapture/com.newsblur.marketing.StoreCaptureActivity', '--es', 'language', language, '--es', 'screen', scene)
    ready = false
    12.times do
      sleep 1
      command(*adb, 'shell', 'uiautomator', 'dump', '/sdcard/newsblur-capture.xml')
      xml = command(*adb, 'shell', 'cat', '/sdcard/newsblur-capture.xml')
      expected = scene == 'feeds' ? 'A Bowl of Greens' : 'Pesto pasta with blistered tomatoes'
      if xml.include?(expected)
        File.write(image.sub('.png', '.xml'), xml) unless still_complete
        ready = true
        break
      end
    end
    raise "Native content never became ready: #{language}/#{device}/#{scene}" unless ready
    sleep 2
    unless still_complete
      File.binwrite(image, command(*adb, 'exec-out', 'screencap', '-p'))
      File.write(proof, JSON.pretty_generate(identity.merge('captured_at' => Time.now.utc.to_s, 'sha256' => Digest::SHA256.file(image).hexdigest, 'native_readiness' => 'expected fixture content visible', 'visual_review' => 'required')) + "\n")
      puts "Captured #{language}/#{device}/#{scene}"
      $stdout.flush
    end
    next if device == 'tablet7'
    FileUtils.mkdir_p(footage)
    remote = '/sdcard/newsblur-capture.mp4'
    # capture-native.rb uses a real swipe in the observed content area, at normal speed.
    pid = Process.spawn(*adb, 'shell', 'screenrecord', '--bit-rate', '10000000', '--time-limit', '6', remote, out: File::NULL)
    sleep 1
    width, height = File.binread(image)[16, 8].unpack('NN')
    x = (width * (device == 'tablet10' && scene == 'reader' ? 0.75 : 0.45)).to_i
    command(*adb, 'shell', 'input', 'swipe', x.to_s, (height * 0.72).to_i.to_s, x.to_s, (height * 0.47).to_i.to_s, '1200')
    Process.wait(pid)
    raise 'Recording failed' unless $?.success?
    command(*adb, 'pull', remote, video)
    probe = CaptureResume.probe_video(video)
    raise "Recording probe failed: #{video}" unless CaptureResume.valid_probe?(probe, [width, height])
    File.write(video.sub(/\.mp4$/, '.xml'), xml)
    video_proof = identity.merge('captured_at' => Time.now.utc.to_s, 'sha256' => Digest::SHA256.file(video).hexdigest,
      'probe' => probe, 'source_still_sha256' => Digest::SHA256.file(image).hexdigest,
      'hierarchy_sha256' => Digest::SHA256.hexdigest(xml), 'visual_review' => 'required')
    File.write(video.sub(/\.mp4$/, '.json'), JSON.pretty_generate(video_proof) + "\n")
    puts "Recorded #{language}/#{device}/#{scene}"
    $stdout.flush
  end
end
