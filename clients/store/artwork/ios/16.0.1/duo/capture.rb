#!/usr/bin/env ruby
# capture.rb captures the existing unfolded Duo through run_ios.py, preserving unaltered native PNGs.
require 'json'
require 'open3'
require 'fileutils'
require 'digest'
require 'time'
root=File.expand_path(__dir__)
repo=File.expand_path('../../../../../..',root)
raise 'Wrong repository root' unless File.file?(File.join(repo,'clients/ios/run_ios.py'))
system("swiftc",File.join(root,"capture-ocr.swift"),"-o","/tmp/duo-ocr",exception:true)
system("swiftc",File.join(repo,"clients/ios/ScreenshotReadiness.swift"),"-o","/tmp/newsblur-screenshot-readiness",exception:true)
locales=ARGV.empty? ? JSON.parse(File.read(File.join(repo,'localization/languages.json'))).keys : ARGV
scenes=[['stories','reader-folder-tech','experimental'],['feeds','reader-folder-tech','standard'],['reader','reader-story-swift-1','standard'],['saved','cooking-saved','standard']]
udid='D570C816-B762-48E2-AC94-C592153A896D'
source=Open3.capture2('git','rev-parse','HEAD',chdir:repo).first.strip
locales.each do |locale|
  directory=File.join(root,'captures',locale)
  next if File.exist?(File.join(directory,'ready.json'))
  FileUtils.mkdir_p(directory)
  records=[]
  scenes.each do |view,screen,style|
    path=File.join(directory,"duo-#{view}.png")
    temporary="/tmp/newsblur-duo-#{locale}-#{view}-candidate.png"
    arguments="-newsblur-ui-testing -newsblur-marketing-cooking -newsblur-marketing-assets #{repo}/clients/ios/MarketingCooking -newsblur-ui-test-screen #{screen} -newsblur-ui-test-story-titles-style #{style} -newsblur-ui-test-theme light -ApplePersistenceIgnoreState YES -newsblur_language #{locale} -duo_fullscreen_reader.Alex NO"
    environment={'IOS_SIM_DISPLAY'=>'3','IOS_LAUNCH_ARGUMENTS'=>arguments}
    base=['python3',File.join(repo,'clients/ios/run_ios.py'),'--udid',udid]
    log,status=Open3.capture2e(environment,*base,'terminate','launch','sleep:12',"screenshot:#{temporary}")
    raise log unless status.success?
    ready=false
    12.times do
      ocr,ocr_status=Open3.capture2('/tmp/duo-ocr',temporary)
      photo_region = if %w[ar he].include?(locale)
        view == 'reader' ? %w[0.15 0.5 0.2 0.35] : %w[0.01 0.2 0.07 0.5]
      else
        view == 'reader' ? %w[0.6 0.5 0.2 0.35] : %w[0.83 0.2 0.07 0.5]
      end
      color,color_status=Open3.capture2('/tmp/newsblur-screenshot-readiness',temporary,*photo_region)
      if ocr_status.success? && color_status.success? && ocr.include?('Pesto pasta') && color.to_f > 0.2
        ready=true
        break
      end
      log,status=Open3.capture2e(environment,*base,'sleep:4',"screenshot:#{temporary}")
      raise log unless status.success?
    end
    raise "Native content not ready: #{locale}/#{view}" unless ready
    # Allow the short synchronization completion notice to leave before final capture.
    log,status=Open3.capture2e(environment,*base,'sleep:3',"screenshot:#{path}")
    raise log unless status.success?
    raise 'Wrong Duo screen dimensions' unless File.binread(path,24)[16,8].unpack('NN')==[2853,2007]
    records << {view:view,screen:screen,style:style,arguments:arguments,path:File.basename(path),sha256:Digest::SHA256.file(path).hexdigest,captured_at:Time.now.utc.iso8601}
    puts "Captured #{locale}/#{view}"; STDOUT.flush
  end
  File.write(File.join(directory,'ready.json'),JSON.pretty_generate({locale:locale,udid:udid,display:3,source_commit:source,files:records,visual_review:'required'})+"\n")
end
