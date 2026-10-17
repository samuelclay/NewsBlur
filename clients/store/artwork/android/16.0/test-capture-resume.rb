require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'digest'
require_relative 'capture-resume'

class TestCaptureResume < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @video = File.join(@directory, 'phone-stories.mp4')
    @expected = { 'language' => 'es', 'device' => 'phone', 'scene' => 'stories', 'serial' => 'device', 'package' => 'com.newsblur.storecapture' }
    @probe = { 'width' => 1080, 'height' => 2340, 'duration' => 5.8, 'codec' => 'h264', 'frame_rate' => '30/1', 'frame_count' => 174 }
    @source_hash = 'still-hash'
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def write_video
    File.binwrite(@video, 'recorded-video-bytes')
    File.write(@video.sub(/\.mp4$/, '.xml'), '<hierarchy/>')
    File.write(@video.sub(/\.mp4$/, '.json'), JSON.generate(@expected.merge('sha256' => Digest::SHA256.file(@video).hexdigest, 'probe' => @probe, 'source_still_sha256' => @source_hash, 'hierarchy_sha256' => Digest::SHA256.hexdigest('<hierarchy/>'))))
  end

  def complete?
    CaptureResume.video_complete?(@video, @expected, @source_hash, [1080, 2340], probe: ->(_) { @probe })
  end

  def test_missing_video_is_not_complete_even_with_still_proof
    File.write(File.join(@directory, 'phone-stories.png'), 'still')
    File.write(File.join(@directory, 'phone-stories.json'), '{}')
    refute complete?
  end

  def test_video_without_provenance_is_not_complete
    File.binwrite(@video, 'recorded-video-bytes')
    refute complete?
  end

  def test_changed_video_bytes_are_not_skipped
    write_video
    File.binwrite(@video, 'truncated')
    refute complete?
  end

  def test_wrong_locale_and_changed_still_are_not_skipped
    write_video
    @expected['language'] = 'fr'
    refute complete?
    @expected['language'] = 'es'
    @source_hash = 'different-still'
    refute complete?
  end

  def test_short_or_wrong_dimension_video_is_not_skipped
    write_video
    @probe = @probe.merge('duration' => 0.3)
    refute complete?
    @probe = @probe.merge('duration' => 5.8, 'width' => 720)
    refute complete?
  end

  def test_matching_video_and_fresh_probe_are_complete
    write_video
    assert complete?
  end

  def test_changed_hierarchy_provenance_is_not_complete
    write_video
    File.write(@video.sub(/\.mp4$/, '.xml'), '<different/>')
    refute complete?
  end

  def test_variable_frame_rate_static_ending_is_valid_without_recapture
    assert CaptureResume.valid_probe?(@probe.merge('duration' => 2.36, 'frame_count' => 192), [1080, 2340])
    refute CaptureResume.valid_probe?(@probe.merge('frame_count' => 2), [1080, 2340])
  end
end
