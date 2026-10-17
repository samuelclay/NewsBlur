#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'

class Test_PlatformExport < Minitest::Test
  def setup
    @temporary = Dir.mktmpdir('newsblur-store-platform')
    @store = File.join(@temporary, 'store')
    @languages = File.join(@temporary, 'languages.json')
    File.write(@languages, JSON.generate('en' => 'English', 'fr' => 'Français'))
    FileUtils.mkdir_p(File.join(@store, 'releases', '16.0.4'))
    %w[metadata products].each { |directory| FileUtils.mkdir_p(File.join(@store, directory)) }
    File.write(File.join(@store, 'locales.json'), JSON.generate('language_count' => 2, 'locales' => [
      { 'language' => 'en', 'name' => 'English', 'apple' => 'en-US', 'google' => 'en-US' },
      { 'language' => 'fr', 'name' => 'Français', 'apple' => 'fr-FR', 'google' => 'fr-FR' }
    ]))
    %w[en fr].each do |language|
      %w[metadata products].each do |directory|
        FileUtils.cp(File.join(__dir__, directory, 'en.json'), path(directory, language))
      end
      File.write(path('releases/16.0.4', language), JSON.generate('android' => { 'release_notes' => "NewsBlur crash fixes.\n\nKeeps offline actions." }))
    end
  end

  def teardown
    FileUtils.remove_entry(@temporary)
  end

  def test_android_only_release_exports_all_languages_without_apple_payloads
    output, status = export('--platform', 'android')
    assert status.success?, output
    assert File.directory?(File.join(@temporary, 'output', 'google'))
    refute File.exist?(File.join(@temporary, 'output', 'apple'))
    notes = JSON.parse(File.read(File.join(@temporary, 'output', 'google', 'release-notes.json')))
    assert_equal %w[en-US fr-FR], notes.map { |note| note.fetch('language') }
    tagged_notes = File.read(File.join(@temporary, 'output', 'google', 'release-notes.txt'))
    assert_equal "<en-US>\nNewsBlur crash fixes.\n\nKeeps offline actions.\n</en-US>\n" \
                 "<fr-FR>\nNewsBlur crash fixes.\n\nKeeps offline actions.\n</fr-FR>\n", tagged_notes
  end

  def test_selected_platform_rejects_missing_malformed_fields_and_unknown_platforms
    [
      [{ 'ios' => { 'whats_new' => 'Other release.' } }, 'missing keys android'],
      [{ 'android' => {} }, 'missing keys release_notes'],
      [{ 'android' => { 'release_notes' => [] } }, 'text must be nonempty'],
      [{ 'android' => { 'release_notes' => 'Fixes.' }, 'andriod' => {} }, 'unexpected keys andriod']
    ].each do |document, error|
      File.write(path('releases/16.0.4', 'fr'), JSON.generate(document))
      output, status = export('--platform', 'android')
      refute status.success?, output
      assert_includes output, error
      refute File.exist?(File.join(@temporary, 'output'))
    end
  end

  def test_default_still_requires_and_exports_both_platforms
    output, status = export
    refute status.success?, output
    assert_includes output, 'missing keys ios'
    %w[en fr].each do |language|
      document = JSON.parse(File.read(path('releases/16.0.4', language)))
      document['ios'] = { 'whats_new' => 'NewsBlur updates.' }
      File.write(path('releases/16.0.4', language), JSON.generate(document))
    end
    output, status = export
    assert status.success?, output
    assert File.directory?(File.join(@temporary, 'output', 'google'))
    assert File.directory?(File.join(@temporary, 'output', 'apple'))
  end

  def test_android_selection_still_requires_every_app_language
    File.delete(path('releases/16.0.4', 'fr'))
    output, status = export('--platform', 'android')
    refute status.success?, output
    assert_includes output, 'missing languages fr'
    refute File.exist?(File.join(@temporary, 'output'))
  end

  def test_ios_only_does_not_require_android_documents
    %w[en fr].each do |language|
      %w[metadata products].each do |directory|
        document = JSON.parse(File.read(path(directory, language)))
        document.delete('android')
        File.write(path(directory, language), JSON.generate(document))
      end
      File.write(path('releases/16.0.4', language), JSON.generate('ios' => { 'whats_new' => 'NewsBlur updates.' }))
    end
    output, status = export('--platform', 'ios')
    assert status.success?, output
    assert File.directory?(File.join(@temporary, 'output', 'apple'))
    refute File.exist?(File.join(@temporary, 'output', 'google'))
  end

  private

  def path(directory, language)
    File.join(@store, directory, "#{language}.json")
  end

  def export(*arguments)
    Open3.capture2e(RbConfig.ruby, File.join(__dir__, 'export.rb'), '16.0.4',
                   '--store-dir', @store, '--languages', @languages,
                   '--output', File.join(@temporary, 'output'), *arguments)
  end
end
