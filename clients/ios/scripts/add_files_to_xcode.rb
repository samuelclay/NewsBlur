#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to add CustomIconRenderer and Icons folder to the Xcode project

require 'xcodeproj'

# Paths
project_path = File.expand_path('../NewsBlur.xcodeproj', __dir__)
classes_path = File.expand_path('../Classes', __dir__)
resources_path = File.expand_path('../Resources', __dir__)

# Open the project
project = Xcodeproj::Project.open(project_path)

# Get the main target
main_target = project.targets.find { |t| t.name == 'NewsBlur' }
unless main_target
  puts "Error: Could not find NewsBlur target"
  exit 1
end

# Find the Classes group
classes_group = project.main_group.find_subpath('Classes', false)
unless classes_group
  puts "Error: Could not find Classes group"
  exit 1
end

# Add CustomIconRenderer.h and CustomIconRenderer.m
puts "Adding CustomIconRenderer files..."

header_path = File.join(classes_path, 'CustomIconRenderer.h')
impl_path = File.join(classes_path, 'CustomIconRenderer.m')

# Check if files already exist in project
existing_files = classes_group.files.map { |f| f.path }

unless existing_files.include?('CustomIconRenderer.h')
  header_ref = classes_group.new_file(header_path)
  puts "  Added CustomIconRenderer.h"
else
  puts "  CustomIconRenderer.h already in project"
end

unless existing_files.include?('CustomIconRenderer.m')
  impl_ref = classes_group.new_file(impl_path)
  main_target.source_build_phase.add_file_reference(impl_ref)
  puts "  Added CustomIconRenderer.m"
else
  puts "  CustomIconRenderer.m already in project"
end

# Find or create Resources group
resources_group = project.main_group.find_subpath('Resources', false)
unless resources_group
  resources_group = project.main_group.new_group('Resources')
end

# Add Icons folder as a folder reference
icons_path = File.join(resources_path, 'Icons')
if Dir.exist?(icons_path)
  puts "Adding Icons folder..."

  # Check if Icons group/reference already exists
  existing_refs = resources_group.children.map { |c| c.display_name }

  unless existing_refs.include?('Icons')
    # Add as folder reference (blue folder)
    icons_ref = resources_group.new_file(icons_path)
    icons_ref.source_tree = '<group>'

    # Add to Copy Bundle Resources phase
    copy_phase = main_target.build_phases.find { |bp| bp.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase) }
    if copy_phase
      copy_phase.add_file_reference(icons_ref)
      puts "  Added Icons folder to Resources"
    end
  else
    puts "  Icons folder already in project"
  end
else
  puts "Warning: Icons folder not found at #{icons_path}"
  puts "  Run convert_icons_to_pdf.py first to create the Icons folder"
end

# Save the project
project.save

puts ""
puts "Project updated successfully!"
puts "Please open Xcode and verify the files are properly added."
