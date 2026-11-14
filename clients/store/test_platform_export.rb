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
    %w[en fr].each do |language|
      update_document('metadata', language) { |document| document.delete('macos') }
    end
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

  def test_macos_uses_its_own_listing_and_notes_with_shared_apple_products
    prepare_macos
    output, status = export('--platform', 'macos')
    assert status.success?, output
    refute File.exist?(File.join(@temporary, 'output', 'google'))
    versions = JSON.parse(File.read(File.join(@temporary, 'output', 'apple', 'version-localizations.json')))
    assert_equal %w[en-US fr-FR], versions.map { |item| item.dig('data', 'attributes', 'locale') }
    versions.each do |item|
      assert_equal 'NewsBlur Mac keyboard updates.', item.dig('data', 'attributes', 'whatsNew')
      assert_includes item.dig('data', 'attributes', 'description'), 'NewsBlur for Mac.'
    end
    products = JSON.parse(File.read(File.join(@temporary, 'output', 'apple', 'subscription-localizations.json')))
    assert_equal JSON.parse(File.read(path('products', 'en'))).dig('ios', 'subscriptions').keys.sort,
                 products.map { |product| product.fetch('productId') }.sort
    products.each do |product|
      assert_equal %w[en-US fr-FR], product.fetch('localizations').map { |item| item.dig('data', 'attributes', 'locale') }
    end
    groups = JSON.parse(File.read(File.join(@temporary, 'output', 'apple', 'subscription-group-localizations.json')))
    assert_equal %w[en-US fr-FR], groups.map { |item| item.dig('data', 'attributes', 'locale') }.uniq.sort
  end

  def test_macos_requires_its_own_notes_in_every_language
    prepare_macos
    File.write(path('releases/16.0.4', 'fr'), JSON.generate('ios' => { 'whats_new' => 'iOS updates.' }))
    assert_rejected('missing keys macos')
  end

  def test_macos_enforces_apple_text_limits_including_keyword_bytes
    prepare_macos
    [
      ['metadata', 'keywords', 'é' * 51, '102 UTF-8 bytes exceeds 100'],
      ['metadata', 'promotional_text', 'a' * 171, '171 characters exceeds 170'],
      ['releases/16.0.4', 'whats_new', 'a' * 4001, '4001 characters exceeds 4000']
    ].each do |directory, field, value, error|
      original = File.read(path(directory, 'fr'))
      update_document(directory, 'fr') { |document| document.fetch('macos')[field] = value }
      assert_rejected(error)
      File.write(path(directory, 'fr'), original)
    end
  end

  def test_macos_cannot_overwrite_shared_apple_name_or_subtitle
    prepare_macos
    %w[name subtitle].each do |field|
      original = File.read(path('metadata', 'fr'))
      update_document('metadata', 'fr') { |document| document.fetch('macos')[field] = 'NewsBlur for Mac' }
      assert_rejected("macos.#{field} must match ios.#{field}")
      File.write(path('metadata', 'fr'), original)
    end
  end

  def test_macos_ignores_unselected_platform_text_and_does_not_require_ios_listing
    prepare_macos
    %w[en fr].each do |language|
      update_document('metadata', language) do |document|
        document.delete('ios')
        document['android'] = { 'title' => nil }
      end
      update_document('products', language) { |document| document.delete('android') }
    end
    output, status = export('--platform', 'macos')
    assert status.success?, output
    assert File.directory?(File.join(@temporary, 'output', 'apple'))
    refute File.exist?(File.join(@temporary, 'output', 'google'))
  end

  def test_android_ignores_optional_macos_metadata_and_release_notes
    %w[en fr].each do |language|
      %w[metadata releases/16.0.4].each do |directory|
        update_document(directory, language) { |document| document['macos'] = {} }
      end
    end
    output, status = export('--platform', 'android')
    assert status.success?, output
    refute File.exist?(File.join(@temporary, 'output', 'apple'))
  end

  def test_macos_requires_shared_apple_products_and_exact_translated_product_ids
    prepare_macos
    original = File.read(path('products', 'fr'))
    update_document('products', 'fr') { |document| document.delete('ios') }
    assert_rejected('missing keys ios')
    File.write(path('products', 'fr'), original)
    missing_id = nil
    update_document('products', 'fr') do |document|
      subscriptions = document.fetch('ios').fetch('subscriptions')
      missing_id = subscriptions.keys.first
      subscriptions.delete(missing_id)
    end
    assert_rejected("missing keys #{missing_id}")
  end

  private

  def prepare_macos
    %w[en fr].each do |language|
      update_document('metadata', language) do |document|
        document['macos'] = document.fetch('ios').merge('description' => "NewsBlur for Mac.\nhttps://www.newsblur.com/tos\nhttps://www.newsblur.com/privacy")
      end
      File.write(path('releases/16.0.4', language), JSON.generate('macos' => { 'whats_new' => 'NewsBlur Mac keyboard updates.' }))
    end
  end

  def update_document(directory, language)
    document = JSON.parse(File.read(path(directory, language)))
    yield document
    File.write(path(directory, language), JSON.generate(document))
  end

  def assert_rejected(error)
    output, status = export('--platform', 'macos')
    refute status.success?, output
    assert_includes output, error
    refute File.exist?(File.join(@temporary, 'output'))
  end

  def path(directory, language)
    File.join(@store, directory, "#{language}.json")
  end

  def export(*arguments)
    Open3.capture2e(RbConfig.ruby, File.join(__dir__, 'export.rb'), '16.0.4',
                   '--store-dir', @store, '--languages', @languages,
                   '--output', File.join(@temporary, 'output'), *arguments)
  end
end
