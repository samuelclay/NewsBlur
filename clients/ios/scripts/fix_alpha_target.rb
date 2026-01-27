#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to add CustomIconRenderer.m to NewsBlur Alpha target

require 'xcodeproj'

project_path = File.expand_path('../NewsBlur.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

# Find the NewsBlur Alpha target
alpha_target = project.targets.find { |t| t.name == 'NewsBlur Alpha' }
unless alpha_target
  puts "Error: Could not find NewsBlur Alpha target"
  exit 1
end

# Find the CustomIconRenderer.m file reference
custom_icon_file = nil
project.main_group.recursive_children.each do |child|
  if child.is_a?(Xcodeproj::Project::Object::PBXFileReference) && child.path == 'CustomIconRenderer.m'
    custom_icon_file = child
    break
  end
end

unless custom_icon_file
  puts "Error: Could not find CustomIconRenderer.m file reference"
  exit 1
end

# Check if already added to Alpha target
already_added = alpha_target.source_build_phase.files.any? { |f| f.file_ref == custom_icon_file }

if already_added
  puts "CustomIconRenderer.m already in NewsBlur Alpha target"
else
  alpha_target.source_build_phase.add_file_reference(custom_icon_file)
  puts "Added CustomIconRenderer.m to NewsBlur Alpha target"
end

# Also add Icons folder to Alpha target resources
icons_ref = nil
project.main_group.recursive_children.each do |child|
  if child.display_name == 'Icons'
    icons_ref = child
    break
  end
end

if icons_ref
  copy_phase = alpha_target.build_phases.find { |bp| bp.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase) }
  if copy_phase
    already_has_icons = copy_phase.files.any? { |f| f.file_ref == icons_ref }
    unless already_has_icons
      copy_phase.add_file_reference(icons_ref)
      puts "Added Icons folder to NewsBlur Alpha resources"
    else
      puts "Icons folder already in NewsBlur Alpha resources"
    end
  end
end

project.save
puts "Project saved successfully!"
