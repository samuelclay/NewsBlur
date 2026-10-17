#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require 'pathname'

# validate.rb validates the canonical store text before export.rb builds upload data.
module StoreMetadata
  ROOT = Pathname.new(__dir__).join('../..').expand_path
  LIMITS = {
    'ios' => {
      'name' => 30,
      'subtitle' => 30,
      'promotional_text' => 170,
      'description' => 4000,
      'keywords' => 100,
      'whats_new' => 4000
    },
    'android' => {
      'title' => 30,
      'short_description' => 80,
      'full_description' => 4000,
      'release_notes' => 500
    }
  }.freeze
  RELEASE_FIELDS = { 'ios' => ['whats_new'], 'android' => ['release_notes'] }.freeze
  URLS = ['https://www.newsblur.com/tos', 'https://www.newsblur.com/privacy'].freeze
  MULTILINE_FIELDS = %w[description full_description whats_new release_notes].freeze

  class ValidationError < StandardError; end

  class Catalog
    attr_reader :languages, :locales, :metadata, :releases, :products, :counts, :version, :platforms

    def initialize(version:, store_dir: ROOT.join('clients/store'), languages_file: ROOT.join('localization/languages.json'), platform: 'both')
      raise ValidationError, "Unknown platform: #{platform}" unless %w[both android ios].include?(platform)

      @platforms = platform == 'both' ? LIMITS.keys : [platform]
      @version = version
      @store_dir = Pathname.new(store_dir)
      @languages_file = Pathname.new(languages_file)
      @errors = []
      @counts = {}
      @metadata = {}
      @releases = {}
      @products = {}
    end

    def validate!
      unless version.is_a?(String) && version.match?(/\A\d+\.\d+(?:\.\d+)?\z/)
        raise ValidationError, 'Version must have the form 16.0 or 16.0.1'
      end
      @languages = read_object(@languages_file)
      @errors << 'The app language catalog is empty' if languages.empty?
      locale_map = read_object(@store_dir.join('locales.json'))
      validate_locales(locale_map)
      validate_directory(@store_dir.join('metadata'), @metadata, release: false)
      validate_directory(@store_dir.join('releases', version), @releases, release: true)
      validate_products
      raise ValidationError, @errors.join("\n") unless @errors.empty?

      self
    end

    private

    def read_object(path)
      data = JSON.parse(File.read(path, encoding: 'UTF-8'))
      unless data.is_a?(Hash)
        @errors << "#{path}: expected a JSON object"
        return {}
      end
      data
    rescue SystemCallError, JSON::ParserError, EncodingError, ArgumentError => error
      @errors << "#{path}: #{error.message}"
      {}
    end

    def exact_keys(value, expected, label)
      unless value.is_a?(Hash)
        @errors << "#{label}: expected an object"
        return false
      end
      missing = expected - value.keys
      extra = value.keys - expected
      @errors << "#{label}: missing keys #{missing.join(', ')}" unless missing.empty?
      @errors << "#{label}: unexpected keys #{extra.join(', ')}" unless extra.empty?
      true
    end

    def validate_locales(map)
      entries = map['locales']
      unless entries.is_a?(Array) && entries.all? { |entry| entry.is_a?(Hash) }
        @errors << 'locales.json: locales must be an array of objects'
        @locales = []
        return
      end
      @locales = entries
      mapped_languages = entries.map { |entry| entry['language'] }
      @errors << 'locales.json: app language coverage differs from localization/languages.json' unless mapped_languages.sort_by(&:to_s) == languages.keys.sort
      @errors << 'locales.json: language_count differs from the app language count' unless map['language_count'] == languages.length
      stores = platforms.map { |platform| platform == 'ios' ? 'apple' : 'google' }
      entries.each do |entry|
        (%w[language name] + stores).each do |key|
          value = entry[key]
          @errors << "locales.json: #{entry['language'].inspect}.#{key} must be nonempty text" unless value.is_a?(String) && !value.strip.empty?
        end
        stores.each do |store|
          value = entry[store]
          @errors << "locales.json: invalid #{store} locale #{value.inspect}" unless value.is_a?(String) && value.match?(/\A[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*\z/)
        end
      end
      stores.each do |store|
        values = entries.map { |entry| entry[store] }
        @errors << "locales.json: duplicate #{store} locales" unless values.uniq.length == values.length
      end
    end

    def platform_keys(document, label)
      # validate.rb accepts shared files while requiring only the requested platform.
      optional = document.is_a?(Hash) ? document.keys & (LIMITS.keys - platforms) : []
      exact_keys(document, platforms + optional, label)
    end

    def validate_directory(directory, target, release:)
      actual = Dir.glob(directory.join('*.json').to_s).map { |file| File.basename(file, '.json') }
      missing = languages.keys - actual
      extra = actual - languages.keys
      @errors << "#{directory}: missing languages #{missing.join(', ')}" unless missing.empty?
      @errors << "#{directory}: unexpected languages #{extra.join(', ')}" unless extra.empty?
      (languages.keys & actual).each do |language|
        path = directory.join("#{language}.json")
        document = read_object(path)
        target[language] = document
        next unless platform_keys(document, path)

        platforms.each do |platform|
          fields = LIMITS.fetch(platform)
          expected = release ? RELEASE_FIELDS.fetch(platform) : fields.keys - RELEASE_FIELDS.fetch(platform)
          label = "#{path}: #{platform}"
          next unless exact_keys(document[platform], expected, label)

          expected.each do |field|
            validate_text(document[platform][field], fields.fetch(field), field, "#{label}.#{field}")
          end
        end
      end
    end

    def validate_text(text, limit, field, label)
      unless text.is_a?(String) && !text.strip.empty?
        @errors << "#{label}: text must be nonempty"
        return
      end
      length = field == 'keywords' ? text.bytesize : text.length
      unit = field == 'keywords' ? 'UTF-8 bytes' : 'characters'
      @counts[label] = { 'length' => length, 'limit' => limit, 'unit' => unit }
      @errors << "#{label}: #{length} #{unit} exceeds #{limit}" if length > limit
      @errors << "#{label}: must contain at least 2 characters" if field == 'name' && text.length < 2
      @errors << "#{label}: leading or trailing whitespace" unless text == text.strip
      allowed = MULTILINE_FIELDS.include?(field) ? text.delete("\n") : text
      # Keep linguistic joiners used by Indic scripts, but reject hidden formatting controls.
      @errors << "#{label}: forbidden control characters" if allowed.delete("\u200C\u200D").match?(/[\p{Cc}\p{Cf}]/)
      @errors << "#{label}: literal escaped newline" if text.include?('\\n')
      if %w[name title description full_description].include?(field) && !text.include?('NewsBlur')
        @errors << "#{label}: NewsBlur brand is missing or altered"
      end
      return unless %w[description full_description].include?(field)

      found_urls = text.scan(%r{https?://[^\s<>]+})
      @errors << "#{label}: terms/privacy URLs differ from the canonical URLs" unless found_urls.sort == URLS.sort
    end

    def validate_products
      directory = @store_dir.join('products')
      actual = Dir.glob(directory.join('*.json').to_s).map { |file| File.basename(file, '.json') }
      missing = languages.keys - actual
      extra = actual - languages.keys
      @errors << "#{directory}: missing languages #{missing.join(', ')}" unless missing.empty?
      @errors << "#{directory}: unexpected languages #{extra.join(', ')}" unless extra.empty?
      (languages.keys & actual).each { |language| @products[language] = read_object(directory.join("#{language}.json")) }
      english = products['en']
      unless english.is_a?(Hash)
        @errors << "#{directory}: English product inventory is required"
        return
      end
      products.each do |language, document|
        label = "#{directory.join("#{language}.json")}"
        next unless platform_keys(document, label)

        platforms.each do |platform|
          kinds = platform == 'ios' ? %w[subscriptions subscription_groups] : ['subscriptions']
          next unless exact_keys(document[platform], kinds, "#{label}: #{platform}")

          kinds.each do |kind|
            reference_platform = english[platform]
            reference = reference_platform.is_a?(Hash) ? reference_platform[kind] : nil
            unless reference.is_a?(Hash) && !reference.empty?
              @errors << "#{directory}/en.json: #{platform}.#{kind} must have a nonempty product inventory"
              next
            end
            inventory = document[platform][kind]
            kind_label = "#{label}: #{platform}.#{kind}"
            next unless exact_keys(inventory, reference.keys, kind_label)

            inventory.each do |product_id, fields|
              product_label = "#{kind_label}.#{product_id}"
              reference_product = reference[product_id]
              unless reference_product.is_a?(Hash) && product_id.match?(/\A[a-zA-Z0-9._-]+\z/)
                @errors << "#{product_label}: invalid product ID or English product object"
                next
              end
              limits = if kind == 'subscription_groups'
                         # locales.json records the live display-field limits, not internal reference names.
                         { 'name' => 35, 'app_name' => 30 }
                       elsif platform == 'ios'
                         { 'name' => 35, 'description' => 55 }
                       else
                         { 'title' => 55, 'description' => 200, 'benefits' => 40 }
                       end
              next unless exact_keys(fields, limits.keys, product_label)

              limits.each do |field, limit|
                value = fields[field]
                if field == 'benefits'
                  expected_benefits = reference_product['benefits']
                  unless value.is_a?(Array) && value.length.between?(1, 4) && expected_benefits.is_a?(Array) && value.length == expected_benefits.length
                    @errors << "#{product_label}.benefits: expected 1–4 benefits matching the English count"
                    next
                  end
                  value.each_with_index { |benefit, index| validate_text(benefit, limit, 'product_benefit', "#{product_label}.benefits[#{index}]") }
                else
                  validate_text(value, limit, "product_#{field}", "#{product_label}.#{field}")
                  next unless %w[name title app_name].include?(field) && value.is_a?(String)

                  brand = reference_product[field].to_s[/NewsBlur(?: Premium(?: Archive| Pro)?)?/] || 'NewsBlur'
                  @errors << "#{product_label}.#{field}: #{brand} brand is missing or altered" unless value.include?(brand)
                end
              end
            end
          end
        end
      end
    end
  end

  def self.options(argv, export: false)
    options = { store_dir: ROOT.join('clients/store'), languages_file: ROOT.join('localization/languages.json') }
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: ruby clients/store/#{export ? 'export' : 'validate'}.rb VERSION#{export ? ' --output DIRECTORY' : ''} [options]"
      opts.on('--store-dir DIRECTORY', 'Canonical metadata directory (also supports isolated validation fixtures)') { |value| options[:store_dir] = value }
      opts.on('--languages FILE', 'App-supported languages JSON') { |value| options[:languages_file] = value }
      opts.on('--platform PLATFORM', %w[both android ios], 'Platform to validate/export: both (default), android, or ios') { |value| options[:platform] = value }
      if export
        opts.on('--output DIRECTORY', 'New directory for validated upload payloads') { |value| options[:output] = value }
        opts.on('--app-info-id ID', 'Add App Store appInfo relationships for create requests') { |value| options[:app_info_id] = value }
        opts.on('--app-store-version-id ID', 'Add App Store version relationships for create requests') { |value| options[:app_store_version_id] = value }
      end
      opts.on('-h', '--help') { puts opts; exit }
    end
    parser.parse!(argv)
    options[:version] = argv.shift
    raise OptionParser::InvalidArgument, 'Supply exactly one version' unless options[:version] && argv.empty?
    raise OptionParser::MissingArgument, '--output' if export && !options[:output]

    options
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    catalog = StoreMetadata::Catalog.new(**StoreMetadata.options(ARGV)).validate!
    puts "Validated #{catalog.languages.length} languages, #{catalog.counts.length} fields for #{catalog.version}."
  rescue StoreMetadata::ValidationError, OptionParser::ParseError => error
    warn error.message
    exit 1
  end
end
