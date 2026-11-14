#!/usr/bin/env ruby
# verify-draft.rb reconciles native captures, exports, independent review and saved store placements.
require 'json'
require 'digest'
require 'time'
root=File.expand_path(__dir__)
repo=File.expand_path('../../../../../..',root)
locales=JSON.parse(File.read(File.join(repo,'localization/languages.json'))).keys
records=locales.map do |locale|
  directory=File.join(root,'exports',locale)
  review=JSON.parse(File.read(File.join(directory,'independent-review.json')))
  raise "Review failed: #{locale}" unless review.fetch('status')=='passed'
  readback=File.read(File.join(directory,'store-readback.txt'))
  raise "Count failed: #{locale}" unless readback.include?('4 of 10 App Screenshots')
  captures=JSON.parse(File.read(File.join(root,'captures',locale,'ready.json')))
  captures.fetch('files').each do |item|
    raise 'Native source changed' unless Digest::SHA256.file(File.join(root,'captures',locale,item.fetch('path'))).hexdigest==item.fetch('sha256')
  end
  files=(1..4).map do |panel|
    name="newsblur-16.0.1-#{locale}-duo-inner-2853x2007-0#{panel}.png"
    path=File.join(directory,name)
    sha=Digest::SHA256.file(path).hexdigest
    raise "Missing placement: #{name}" unless readback.include?(name)
    raise "Unreviewed bytes: #{name}" unless review.fetch('files').any?{|f|f.fetch('filename')==name && f.fetch('sha256')==sha}
    raise "Wrong dimensions: #{name}" unless File.binread(path,24)[16,8].unpack('NN')==[2853,2007]
    {filename:name,sha256:sha}
  end
  {locale:locale,capture_source:captures.fetch('source_commit'),files:files,independent_visual_review:'passed',store_placement:'verified_after_reload'}
end
report={verified_at:Time.now.utc.iso8601,version:'16.0.1',state:'PREPARE_FOR_SUBMISSION',build_attached:false,submitted:false,public:false,screenshot_count:records.length*4,locale_count:records.length,store_url:'https://appstoreconnect.apple.com/apps/463981119/distribution/ios/version/inflight',locales:records}
File.write(File.join(root,'draft-verification.json'),JSON.pretty_generate(report)+"\n")
puts "Verified #{records.length*4} screenshots in #{records.length} localized draft placements. No release submitted."
