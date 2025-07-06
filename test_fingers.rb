#!/usr/bin/env ruby

require_relative 'finger_joint_calculator'
require_relative 'svg_generator'

# Test finger joint calculations with simple dimensions
puts "🔍 Testing Finger Joint Calculations"
puts "=" * 50

# Test configuration
test_options = {
  box_length: 100,
  box_width: 80,
  box_height: 40,
  stock_thickness: 6,
  finger_width: 15,
  bit_diameter: 3,
  kerf: 0.2,
  lid_height: 20,
  lid_tolerance: 0.5,
  part_spacing: 10,
  dogbone_style: 3,
  enable_lid: false,
  enable_dividers: false,
  enable_x_divider: false,
  enable_y_divider: false,
  output_dir: "./test_fingers_output",
  open_viewer: false
}

puts "Test Box Dimensions: #{test_options[:box_length]}×#{test_options[:box_width]}×#{test_options[:box_height]}mm"
puts "Material: #{test_options[:stock_thickness]}mm thick, #{test_options[:kerf]}mm kerf"
puts "Finger Width: #{test_options[:finger_width]}mm"
puts

# Calculate finger layouts
puts "📐 Calculating Finger Layouts..."
calculator = FingerJointCalculator.new(test_options)
layouts = calculator.calculate_all_layouts

puts
puts "📊 Finger Layout Results:"
layouts.each do |key, layout|
  direction = key.to_s.gsub('_', ' ').capitalize
  puts "  #{direction}:"
  puts "    Span: #{layout[:span]}mm"
  puts "    Count: #{layout[:count]} fingers"
  puts "    Width: #{layout[:width].round(2)}mm each"
  puts "    Total: #{(layout[:count] * layout[:width]).round(2)}mm"
  puts
end

# Test specific finger calculations
puts "🔍 Testing Finger Positioning (Box Bottom):"
layout_x = layouts[:box_x]
layout_y = layouts[:box_y]

puts "X-direction fingers (#{layout_x[:count]} total):"
(0...layout_x[:count]).each do |i|
  uniform_width = layout_x[:span] / layout_x[:count]
  start_pos = i * uniform_width
  slot_type = i.even? ? "SLOT" : "finger"
  puts "  #{i}: #{start_pos.round(2)}mm - #{(start_pos + uniform_width).round(2)}mm (#{slot_type})"
end

puts
puts "Y-direction fingers (#{layout_y[:count]} total):"
(0...layout_y[:count]).each do |j|
  uniform_width = layout_y[:span] / layout_y[:count]
  start_pos = j * uniform_width
  slot_type = j.even? ? "SLOT" : "finger"
  puts "  #{j}: #{start_pos.round(2)}mm - #{(start_pos + uniform_width).round(2)}mm (#{slot_type})"
end

# Create output directory
require 'fileutils'
FileUtils.mkdir_p(test_options[:output_dir])

# Test SVG generation
puts
puts "📝 Generating Test SVG..."
begin
  generator = SVGGenerator.new(test_options, layouts)

  # Generate just the box bottom for testing
  puts "Generating box_bottom.svg..."
  files = [generator.send(:generate_panel_by_type, "box_bottom")]

  puts "✅ Generated test SVG files:"
  files.each { |file| puts "  📄 #{File.basename(file)}" }

  # Read and display part of the SVG content
  svg_content = File.read(files.first)
  puts
  puts "📄 SVG Content Preview (first 1000 characters):"
  puts svg_content[0, 1000]
  puts "..." if svg_content.length > 1000

  # Count rectangles in SVG to verify slots were created
  rect_count = svg_content.scan(/<rect/).length
  puts
  puts "📊 SVG Analysis:"
  puts "  Total <rect> elements: #{rect_count}"
  puts "  Expected: 1 outline + finger slots"

  # Look for red rectangles (finger slots)
  red_rects = svg_content.scan(/stroke="red"/).length
  puts "  Red rectangles (finger slots): #{red_rects}"

  # Calculate expected slots
  x_slots = (0...layout_x[:count]).count { |i| i.even? }
  y_slots = (0...layout_y[:count]).count { |j| j.even? }
  expected_slots = (x_slots * 2) + (y_slots * 2)  # 2 slots per finger (front/back, left/right)

  puts "  Expected finger slots: #{expected_slots} (#{x_slots} X-slots × 2 + #{y_slots} Y-slots × 2)"
  puts

  if red_rects == expected_slots
    puts "✅ SVG appears to have correct number of finger slots!"
  else
    puts "❌ SVG has incorrect number of finger slots!"
    puts "   This indicates a problem with the finger generation logic."
  end

rescue => e
  puts "❌ Error generating SVG: #{e.message}"
  puts "Stacktrace:"
  e.backtrace.each { |line| puts "  #{line}" }
end

puts
puts "🎯 Test Summary:"
puts "  Box dimensions: #{test_options[:box_length]}×#{test_options[:box_width]}×#{test_options[:box_height]}mm"
puts "  X-direction: #{layout_x[:count]} fingers @ #{layout_x[:width].round(2)}mm each"
puts "  Y-direction: #{layout_y[:count]} fingers @ #{layout_y[:width].round(2)}mm each"
puts "  Output directory: #{test_options[:output_dir]}"
puts
puts "Run this test to verify finger joint calculations are working correctly."
puts "Check the generated SVG file in your browser or SVG viewer to see the finger joints."
