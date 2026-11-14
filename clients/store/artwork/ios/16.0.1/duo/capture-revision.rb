#!/usr/bin/env ruby
# capture-revision.rb captures actual closed/list and open/full-screen scenes; Device Hub controls pose.
require 'json'
require 'open3'
require 'fileutils'
require 'digest'
require 'time'
root = File.expand_path(__dir__)
repo = File.expand_path('../../../../../..', root)
scene = ARGV.shift
raise 'Usage: capture-revision.rb closed|fullscreen [locales...]' unless %w[closed fullscreen].include?(scene)
locales = ARGV.empty? ? JSON.parse(File.read(File.join(repo, 'localization/languages.json'))).keys : ARGV
closed = scene == 'closed'
udid = 'D570C816-B762-48E2-AC94-C592153A896D'
expected = closed ? [1398, 2034] : [2853, 2007]
system('swiftc', File.join(root, 'capture-ocr.swift'), '-o', '/tmp/duo-ocr', exception: true)
system('swiftc', File.join(repo, 'clients/ios/ScreenshotReadiness.swift'), '-o', '/tmp/newsblur-screenshot-readiness', exception: true)
locales.each do |locale|
  directory = File.join(root, 'revisions/v2/captures', locale)
  FileUtils.mkdir_p(directory)
  path = File.join(directory, "duo-#{scene}.png")
  record = File.join(directory, "#{scene}.json")
  next if File.exist?(record) && File.exist?(path)
  args = "-newsblur-ui-testing -newsblur-marketing-cooking -newsblur-marketing-assets #{repo}/clients/ios/MarketingCooking -newsblur-ui-test-screen #{closed ? 'reader-folder-tech' : 'reader-story-swift-1'} -newsblur-ui-test-story-titles-style standard -newsblur-ui-test-theme light -ApplePersistenceIgnoreState YES -newsblur_language #{locale} -duo_fullscreen_reader.Alex #{closed ? 'NO' : 'YES'}"
  args += " -newsblur-marketing-fullscreen" unless closed
  environment = {'IOS_SIM_DISPLAY' => closed ? '1' : '3', 'IOS_LAUNCH_ARGUMENTS' => args}
  base = ['python3', File.join(repo, 'clients/ios/run_ios.py'), '--udid', udid]
  candidate = "/tmp/newsblur-duo-v2-#{scene}-#{locale}.png"
  output, status = Open3.capture2e(environment, *base, 'terminate', 'launch', 'sleep:12', "screenshot:#{candidate}")
  raise output unless status.success?
  ready = false
  12.times do
    raise "Wrong active display or orientation: #{locale}/#{scene}" unless File.binread(candidate, 24)[16, 8].unpack('NN') == expected
    ocr, result = Open3.capture2('/tmp/duo-ocr', candidate)
    region = closed ? (%w[ar he].include?(locale) ? %w[0.02 0.12 0.12 0.5] : %w[0.65 0.12 0.12 0.5]) : %w[0.4 0.5 0.2 0.35]
    color, color_result = Open3.capture2('/tmp/newsblur-screenshot-readiness', candidate, *region)
    layout_ready = closed || !ocr.include?('The pantry staples')
    if result.success? && color_result.success? && ocr.include?('Pesto pasta') && color.to_f > 0.2 && layout_ready
      ready = true
      break
    end
    output, status = Open3.capture2e(environment, *base, 'sleep:4', "screenshot:#{candidate}")
    raise output unless status.success?
  end
  raise "Content not ready: #{locale}/#{scene}" unless ready
  output, status = Open3.capture2e(environment, *base, 'sleep:3', "screenshot:#{path}")
  raise output unless status.success?
  File.write(record, JSON.pretty_generate({locale: locale, scene: scene, udid: udid, display: environment['IOS_SIM_DISPLAY'], arguments: args, dimensions: expected, capture: File.basename(path), sha256: Digest::SHA256.file(path).hexdigest, captured_at: Time.now.utc.iso8601, visual_review: 'required'}) + "\n")
  puts "Captured #{locale}/#{scene}"
  STDOUT.flush
end
