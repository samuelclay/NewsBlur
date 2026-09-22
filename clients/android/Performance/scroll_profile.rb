#!/usr/bin/env ruby
# scroll_profile.rb records an existing logged-in emulator without installing tests or clearing data.
require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'

serial, output, scenario = ARGV
abort 'Usage: scroll_profile.rb SERIAL OUTPUT_DIRECTORY SCENARIO_JSON [--no-video]' unless scenario
record_video = !ARGV.include?('--no-video')
abort 'Invalid device serial' unless serial.match?(/\A[\w.:-]+\z/)
lock = File.open(File.join(Dir.tmpdir, "newsblur-profile-#{serial}.lock"), 'w')
abort 'Another profiling run owns this device' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
steps = JSON.parse(File.read(scenario))
FileUtils.mkdir_p(output)
adb = ['adb', '-s', serial]
def run(*args)
  stdout, stderr, status = Open3.capture3(*args)
  abort "#{args.first} failed: #{stderr}" unless status.success?
  stdout
end
abort 'Target must already be attached' unless run(*adb, 'get-state').strip == 'device'
abort 'Open NewsBlur before recording' if run(*adb, 'shell', 'pidof', 'com.newsblur').strip.empty?
def foreground(adb)
  run(*adb, 'shell', 'dumpsys', 'window').lines.find { |line| line.include?('mCurrentFocus=') }&.strip
end
initial_screen = foreground(adb)
abort 'NewsBlur must be in the foreground' unless initial_screen&.include?('com.newsblur/')
existing_recorders, = Open3.capture3(*adb, 'shell', 'pidof', 'screenrecord')
abort 'Finish the existing screen recording before profiling' unless existing_recorders.strip.empty?
File.write(File.join(output, 'device.txt'), run(*adb, 'shell', 'getprop', 'ro.build.fingerprint') +
  run(*adb, 'shell', 'wm', 'size') + run(*adb, 'shell', 'wm', 'density'))
config = <<~CONFIG
  buffers { size_kb: 65536 fill_policy: RING_BUFFER }
  duration_ms: 120000
  data_sources { config { name: "linux.ftrace" ftrace_config {
    buffer_size_kb: 8192
    drain_period_ms: 100
    ftrace_events: "sched/sched_switch"
    ftrace_events: "sched/sched_waking"
    atrace_categories: "gfx"
    atrace_categories: "view"
    atrace_categories: "input"
    atrace_categories: "wm"
    atrace_categories: "dalvik"
    atrace_categories: "webview"
    atrace_apps: "com.newsblur"
  } } }
  data_sources { config { name: "linux.process_stats" process_stats_config { scan_all_processes_on_start: true } } }
  data_sources { config { name: "android.surfaceflinger.frametimeline" } }
CONFIG
File.write(File.join(output, 'trace-config.txt'), config)
run(*adb, 'push', File.join(output, 'trace-config.txt'), '/data/local/tmp/nb-scroll-trace.txt')
File.binwrite(File.join(output, 'start.png'), run(*adb, 'exec-out', 'screencap', '-p'))
run(*adb, 'shell', 'dumpsys', 'gfxinfo', 'com.newsblur', 'reset')
trace_pid = run(*adb, 'shell', 'cat /data/local/tmp/nb-scroll-trace.txt | perfetto --background-wait --txt -c - -o /data/misc/perfetto-traces/nb-scroll.perfetto-trace').strip
abort "Unexpected Perfetto PID: #{trace_pid}" unless trace_pid.match?(/\A\d+\z/)
video_pid = Process.spawn(*adb, 'shell', 'screenrecord', '--bit-rate', '6000000', '--time-limit', '120', '/sdcard/nb-scroll.mp4', out: File.join(output, 'video.log'), err: [:child, :out]) if record_video
events = []
begin
  sleep 1
  steps.each do |step|
    events << step.merge('host_monotonic' => Process.clock_gettime(Process::CLOCK_MONOTONIC))
    if step.key?('wait')
      sleep step.fetch('wait')
    elsif step.key?('swipe')
      run(*adb, 'shell', 'input', 'swipe', *step.fetch('swipe').map(&:to_s))
    elsif step.key?('tap')
      run(*adb, 'shell', 'input', 'tap', *step.fetch('tap').map(&:to_s))
    else
      abort "Unknown gesture: #{step}"
    end
  end
  sleep 1
ensure
  File.write(File.join(output, 'gfxinfo.txt'), run(*adb, 'shell', 'dumpsys', 'gfxinfo', 'com.newsblur', 'framestats'))
  run(*adb, 'shell', 'kill', '-TERM', trace_pid)
  if video_pid
    recorders = run(*adb, 'shell', 'pidof', 'screenrecord').split
    recorders.each { |pid| run(*adb, 'shell', 'kill', '-INT', pid) }
    Process.wait(video_pid)
    run(*adb, 'pull', '/sdcard/nb-scroll.mp4', File.join(output, 'video.mp4'))
  end
  File.write(File.join(output, 'gestures.json'), JSON.pretty_generate(events))
  final_screen = foreground(adb)
  File.write(File.join(output, 'run-validity.json'), JSON.pretty_generate({
    same_screen: initial_screen == final_screen,
    initial_screen: initial_screen,
    final_screen: final_screen,
    note: 'Review the video and screenshots before comparing timings; delayed swipe injection can become a tap.'
  }))
  File.binwrite(File.join(output, 'end.png'), run(*adb, 'exec-out', 'screencap', '-p'))
  run(*adb, 'pull', '/data/misc/perfetto-traces/nb-scroll.perfetto-trace', File.join(output, 'trace.perfetto-trace'))
end
puts output
