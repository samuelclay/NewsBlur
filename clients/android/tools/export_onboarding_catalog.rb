#!/usr/bin/env ruby
# export_onboarding_catalog.rb carries the audited iOS identities into Android assets.
require 'json'
Dir.chdir(File.expand_path('../../..', __dir__))
source=File.read('clients/ios/Classes/OnboardingIconCatalog.swift')
catalog={}; key=nil
source.each_line do |line|
  key=$1 if line =~ /^        "([^"]+)": \[/
  if line =~ /Feed\(id: "([^"]+)", title: "((?:\\.|[^"])*)", url: "((?:\\.|[^"])*)", source: "([^"]+)"\)/
    (catalog[key] ||= []) << {id:$1, title:JSON.parse('"'+$2+'"'), url:JSON.parse('"'+$3+'"'), source:$4}
  end
end
File.write('clients/android/NewsBlur/app/src/main/assets/onboarding_catalog.json', JSON.pretty_generate(catalog)+"\n")
selector = File.read('clients/ios/Classes/OnboardingCatalogSelector.swift')
block = selector.split('private static let excludedFeedURLs:', 2).last.split("\n    ]", 2).first
exclusions = {}
block.scan(/"([^"\n]+)": \[([^\]]*)\]/m) do |category, entries|
  exclusions[category] = entries.scan(/"([^"\n]+)"/).flatten
end
abort 'The iOS exclusions could not be read' if exclusions.empty?
File.write('clients/android/NewsBlur/app/src/main/assets/onboarding_exclusions.json', JSON.pretty_generate(exclusions) + "\n")
