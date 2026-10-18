#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require_relative 'validate'

# export.rb creates text-only API data; it never contacts or changes either store.
module StoreMetadata
  class Exporter
    def initialize(catalog, output:, app_info_id: nil, app_store_version_id: nil)
      @catalog = catalog
      @output = Pathname.new(output).expand_path
      @app_info_id = app_info_id
      @app_store_version_id = app_store_version_id
    end

    def export!
      raise ValidationError, "Output directory already exists: #{@output}" if @output.exist?

      info = []
      versions = []
      listings = []
      release_notes = []
      apple_subscriptions = {}
      apple_groups = []
      google_subscriptions = {}
      apple_platform = @catalog.platforms.find { |platform| %w[ios macos].include?(platform) }
      @catalog.locales.each do |mapping|
        language = mapping.fetch('language')
        metadata = @catalog.metadata.fetch(language)
        release = @catalog.releases.fetch(language)
        if apple_platform
          apple = metadata.fetch(apple_platform)
          info << apple_payload('appInfoLocalizations', {
            'locale' => mapping.fetch('apple'), 'name' => apple.fetch('name'), 'subtitle' => apple.fetch('subtitle')
          }, 'appInfo', 'appInfos', @app_info_id)
          versions << apple_payload('appStoreVersionLocalizations', {
            'locale' => mapping.fetch('apple'), 'description' => apple.fetch('description'),
            'keywords' => apple.fetch('keywords'), 'promotionalText' => apple.fetch('promotional_text'),
            'whatsNew' => release.fetch(apple_platform).fetch('whats_new')
          }, 'appStoreVersion', 'appStoreVersions', @app_store_version_id)
        end
        if @catalog.platforms.include?('android')
          android = metadata.fetch('android')
          listings << {
            'language' => mapping.fetch('google'), 'title' => android.fetch('title'),
            'shortDescription' => android.fetch('short_description'), 'fullDescription' => android.fetch('full_description')
          }
          release_notes << { 'language' => mapping.fetch('google'), 'text' => release.fetch('android').fetch('release_notes') }
        end
        products = @catalog.products.fetch(language)
        if apple_platform
          products.fetch('ios').fetch('subscriptions').each do |product_id, product|
            apple_subscriptions[product_id] ||= { 'productId' => product_id, 'localizations' => [] }
            apple_subscriptions[product_id]['localizations'] << apple_payload('subscriptionLocalizations', {
              'locale' => mapping.fetch('apple'), 'name' => product.fetch('name'), 'description' => product.fetch('description')
            }, nil, nil, nil)
          end
          products.fetch('ios').fetch('subscription_groups').each do |group_id, group|
            apple_groups << apple_payload('subscriptionGroupLocalizations', {
              'locale' => mapping.fetch('apple'), 'name' => group.fetch('name'), 'customAppName' => group.fetch('app_name')
            }, 'subscriptionGroup', 'subscriptionGroups', group_id)
          end
        end
        if @catalog.platforms.include?('android')
          products.fetch('android').fetch('subscriptions').each do |product_id, product|
            google_subscriptions[product_id] ||= { 'productId' => product_id, 'listings' => [] }
            google_subscriptions[product_id]['listings'] << {
              'languageCode' => mapping.fetch('google'), 'title' => product.fetch('title'),
              'description' => product.fetch('description'), 'benefits' => product.fetch('benefits')
            }
          end
        end
      end
      if apple_platform
        FileUtils.mkdir_p(@output.join('apple'))
        write_json('apple/app-info-localizations.json', info)
        write_json('apple/version-localizations.json', versions)
        write_json('apple/subscription-localizations.json', apple_subscriptions.values)
        write_json('apple/subscription-group-localizations.json', apple_groups)
      end
      if @catalog.platforms.include?('android')
        FileUtils.mkdir_p(@output.join('google'))
        write_json('google/listings.json', listings)
        write_json('google/release-notes.json', release_notes)
        write_json('google/subscriptions.json', google_subscriptions.values)
        tagged_notes = release_notes.map { |note| "<#{note.fetch('language')}>\n#{note.fetch('text')}\n</#{note.fetch('language')}>" }.join("\n")
        File.write(@output.join('google/release-notes.txt'), tagged_notes + "\n", encoding: 'UTF-8')
      end
      write_json('validation.json', { 'version' => @catalog.version, 'languages' => @catalog.languages.keys, 'fields' => @catalog.counts })
      @output
    end

    private

    def apple_payload(type, attributes, relationship, parent_type, parent_id)
      data = { 'type' => type, 'attributes' => attributes }
      if parent_id
        data['relationships'] = { relationship => { 'data' => { 'type' => parent_type, 'id' => parent_id } } }
      end
      { 'data' => data }
    end

    def write_json(path, data)
      File.write(@output.join(path), JSON.pretty_generate(data) + "\n", encoding: 'UTF-8')
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    options = StoreMetadata.options(ARGV, export: true)
    export_options = { output: options.delete(:output), app_info_id: options.delete(:app_info_id), app_store_version_id: options.delete(:app_store_version_id) }
    catalog = StoreMetadata::Catalog.new(**options).validate!
    output = StoreMetadata::Exporter.new(catalog, **export_options).export!
    puts "Exported #{catalog.languages.length} languages for #{catalog.version} to #{output}. No store changes made."
  rescue StoreMetadata::ValidationError, OptionParser::ParseError, SystemCallError => error
    warn error.message
    exit 1
  end
end
