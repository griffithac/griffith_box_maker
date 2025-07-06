#!/usr/bin/env ruby

# Simple launcher for Box Maker CLI
# This demonstrates both interactive and command-line usage

puts "📦 Box Maker CLI Launcher"
puts "=" * 40

if ARGV.include?("--demo")
  puts "🎬 Running demo mode..."
  puts

  # Demo the command line interface
  puts "1. Command-line example:"
  puts "   Generating a small tool box..."
  system("ruby box_maker.rb --length 200 --width 150 --height 80 --finger-width 25 --output ./demo --no-open")
  puts

  puts "2. Launching interactive menu..."
  puts "   (Use arrow keys or HJKL to navigate)"
  puts
  sleep 2

  # Launch interactive mode
  system("ruby box_maker.rb --interactive")

elsif ARGV.include?("--help") || ARGV.include?("-h")
  puts "Usage modes:"
  puts
  puts "1. Interactive Menu (recommended for beginners):"
  puts "   ruby launch.rb"
  puts "   or"
  puts "   ruby box_maker.rb"
  puts
  puts "2. Command Line (for scripting/automation):"
  puts "   ruby box_maker.rb --length 200 --width 150 --height 80"
  puts
  puts "3. Demo Mode:"
  puts "   ruby launch.rb --demo"
  puts
  puts "Navigation in Interactive Mode:"
  puts "  ↑↓ or hjkl  - Navigate menu"
  puts "  ENTER       - Select/activate item"
  puts "  e           - Edit numeric values"
  puts "  SPACE       - Toggle boolean values"
  puts "  q           - Quit"

elsif ARGV.length > 0
  # Pass arguments to box_maker
  exec("ruby box_maker.rb #{ARGV.join(' ')}")

else
  # Default: launch interactive menu
  puts "🎯 Launching interactive menu..."
  puts "   Use arrow keys or HJKL to navigate"
  puts "   Press ENTER to select, 'e' to edit, 'q' to quit"
  puts
  sleep 1

  exec("ruby box_maker.rb --interactive")
end
