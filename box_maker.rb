#!/usr/bin/env ruby

require 'optparse'
require 'fileutils'
require 'rbconfig'

# Load separate component files
require_relative 'finger_joint_calculator'
require_relative 'svg_generator'
require_relative 'layout_optimizer'
require_relative 'project_manager'

# Try to load menu system
begin
  require_relative 'menu'
rescue LoadError => e
  puts "Note: menu.rb not found (#{e.message}), interactive mode not available"
end

class BoxMaker
  VERSION = "1.0.0"

  # Default parameters from OpenSCAD file
    DEFAULT_OPTIONS = {
    box_length: 100,
    box_width: 80,
    box_height: 40,
    stock_thickness: 6,
    stock_width: 300,    # Stock sheet width in mm
    stock_height: 300,    # Stock sheet height in mm
    finger_width: 15,
    bit_diameter: 3.175,
    kerf: 0.2,
    lid_height: 20,
    lid_tolerance: 0.5,
    part_spacing: 10,
    dogbone_style: 3,
    enable_lid: false,
    enable_dividers: false,
    enable_x_divider: true,
    enable_y_divider: true,
    output_dir: "./output",
    open_viewer: true,
    interactive: false,
    generate_gcode: false,
    generate_stl: false
  }.freeze

  def initialize
    @options = DEFAULT_OPTIONS.dup
    @project_manager = nil
  end

  def run(args)
    parse_options(args)

    # Launch interactive menu if no arguments provided or --interactive flag used
    if args.empty? || @options[:interactive]
      launch_interactive_menu
      return
    end

    puts "Box Maker CLI v#{VERSION}"
    puts "Generating finger-jointed box with dimensions: #{@options[:box_length]}×#{@options[:box_width]}×#{@options[:box_height]}mm"

    generate_box_files
  rescue => e
    puts "❌ Error generating box: #{e.message}"
    puts "\nStacktrace:"
    e.backtrace.each { |line| puts "  #{line}" }
    exit 1
  end

  def launch_interactive_menu
    if defined?(MenuSystem)
      puts "🚀 Launching Box Maker Interactive Menu..."
      puts "Use arrow keys or letter shortcuts (D/M/J/F/O/P/G/S/Q)"
      puts "All measurements are in millimeters (mm)"
      puts
      sleep 1  # Give user time to read

      menu = MenuSystem.new(self)
      menu.run
    else
      puts "❌ Interactive menu not available. menu.rb not found."
      puts "Run in command-line mode with: #{$0} --help"
      exit 1
    end
  end

  def generate_box_files
    # Create output directory
    FileUtils.mkdir_p(@options[:output_dir])

    # Calculate layouts
    calculator = FingerJointCalculator.new(@options)
    layouts = calculator.calculate_all_layouts

    # Show finger layout info
    puts "\n📊 Calculated Finger Layouts:"
    layouts.each do |key, layout|
      direction = key.to_s.gsub('_', ' ').capitalize
      puts "  #{direction}: #{layout[:count]} fingers @ #{layout[:width].round(2)}mm each"
    end
    puts



    # Optimize layout for stock material FIRST
    puts "\n🔧 Optimizing layout for stock material..."
    optimizer = LayoutOptimizer.new(@options)

    # Add panels to optimizer
    optimizer.add_panel("box_bottom", @options[:box_length], @options[:box_width])
    optimizer.add_panel("box_front", @options[:box_length], @options[:box_height])
    optimizer.add_panel("box_back", @options[:box_length], @options[:box_height])
    optimizer.add_panel("box_left", @options[:box_width], @options[:box_height])
    optimizer.add_panel("box_right", @options[:box_width], @options[:box_height])

    # Add lid panels if enabled
    if @options[:enable_lid]
      lid_length = @options[:box_length] + 2 * @options[:stock_thickness] + 2 * @options[:lid_tolerance]
      lid_width = @options[:box_width] + 2 * @options[:stock_thickness] + 2 * @options[:lid_tolerance]

      optimizer.add_panel("lid_top", lid_length, lid_width)
      optimizer.add_panel("lid_front", lid_length, @options[:lid_height])
      optimizer.add_panel("lid_back", lid_length, @options[:lid_height])
      optimizer.add_panel("lid_left", lid_width, @options[:lid_height])
      optimizer.add_panel("lid_right", lid_width, @options[:lid_height])
    end

    # Add divider panels if enabled
    if @options[:enable_dividers]
      optimizer.add_panel("x_divider", @options[:box_length], @options[:box_height]) if @options[:enable_x_divider]
      optimizer.add_panel("y_divider", @options[:box_width], @options[:box_height]) if @options[:enable_y_divider]
    end

    # Calculate optimal layout
    layout = optimizer.calculate_layout
    optimizer.print_layout_summary(layout)
    optimizer.suggest_optimizations(layout)

    # Generate cutting layout SVGs FIRST
    puts "\n📐 Generating cutting layout diagrams..."
    layout_files = optimizer.generate_cutting_layout_svg(layout, @options[:output_dir])

    # Now generate individual panel files
    puts "\n📝 Generating individual panel SVG files..."
    generator = SVGGenerator.new(@options, layouts)
    files = generator.generate_all_panels

    # Convert SVG files to G-code if requested
    gcode_files = []
    if @options[:generate_gcode]
      puts "\n🛠️  Converting SVG files to G-code..."
      gcode_files = files.map { |f| convert_svg_to_gcode(f) }.compact
    end

    stl_file = nil
    if @options[:generate_stl]
      puts "\n📦 Generating STL assembly..."
      begin
        require_relative 'stl_generator'
        stl_gen = STLGenerator.new(@options)
        stl_file = stl_gen.generate(File.join(@options[:output_dir], 'box_assembly.stl'))
      rescue LoadError => e
        puts "⚠️  STL generation skipped: #{e.message}"
      end
    end

    puts "\n✅ Generated files:"
    puts "  📋 Sheet Layouts:"
    layout_files.each { |file| puts "    📄 #{File.basename(file)}" }
    puts "  🔧 Individual Panels:"
    files.each { |file| puts "    📄 #{File.basename(file)}" }
    unless gcode_files.empty?
      puts "  🛠️  G-code Files:"
      gcode_files.each { |f| puts "    💾 #{File.basename(f)}" }
    end
    puts "  📦 STL File: #{File.basename(stl_file)}" if stl_file

    # Open with system viewer if requested (prioritize sheet layout)
    if @options[:open_viewer]
      if stl_file
        puts "\n👁️ Opening STL file with system viewer..."
        open_with_viewer(stl_file)
      elsif layout_files && !layout_files.empty?
        puts "\n👁️ Opening sheet layout with system viewer..."
        open_with_viewer(layout_files.first)
      elsif !files.empty?
        puts "\n👁️ Opening first panel file with system viewer..."
        open_with_viewer(files.first)
      end
    end

    puts "\n📁 Output directory: #{@options[:output_dir]}"
    puts "\nDone!"
  end

  def get_project_manager
    @project_manager
  end

  def set_project_manager(project_manager)
    @project_manager = project_manager
  end

  def update_options(new_options)
    @options.merge!(new_options)
  end

  def load_project_from_cli(project_file)
    begin
      require 'json'

      unless File.exist?(project_file)
        puts "❌ Project file not found: #{project_file}"
        exit 1
      end

      project_data = JSON.parse(File.read(project_file), symbolize_names: true)

      unless project_data[:configuration]
        puts "❌ Invalid project file format"
        exit 1
      end

      @options.merge!(project_data[:configuration])
      puts "✅ Loaded project: #{project_data[:name] || File.basename(project_file, '.json')}"

    rescue JSON::ParserError => e
      puts "❌ Error parsing project file: #{e.message}"
      exit 1
    rescue => e
      puts "❌ Error loading project: #{e.message}"
      exit 1
    end
  end

  def save_project_from_cli(project_name)
    begin
      require 'json'
      require 'fileutils'

      projects_dir = @options[:projects_dir] || File.join(Dir.pwd, 'projects')
      FileUtils.mkdir_p(projects_dir)

      filename = project_name.gsub(/[^a-zA-Z0-9_\-]/, '_').gsub(/_+/, '_') + '.json'
      filepath = File.join(projects_dir, filename)

      project_data = {
        name: project_name,
        created_at: Time.now.iso8601,
        updated_at: Time.now.iso8601,
        version: "1.0",
        description: "#{@options[:box_length]}×#{@options[:box_width]}×#{@options[:box_height]}mm box",
        configuration: @options.dup
      }

      File.write(filepath, JSON.pretty_generate(project_data))
      puts "✅ Project '#{project_name}' saved to #{filepath}"

    rescue => e
      puts "❌ Error saving project: #{e.message}"
      exit 1
    end
  end

  private

  def parse_options(args)
    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"
      opts.separator ""
      opts.separator "Run without arguments to launch interactive menu"
      opts.separator "Or use command-line options for direct generation:"

      opts.separator ""
      opts.separator "Box dimensions (all measurements in mm):"
      opts.on("-l", "--length LENGTH", Float, "Box length (mm)") { |v| @options[:box_length] = v }
      opts.on("-w", "--width WIDTH", Float, "Box width (mm)") { |v| @options[:box_width] = v }
      opts.on("-h", "--height HEIGHT", Float, "Box height (mm)") { |v| @options[:box_height] = v }

      opts.separator ""
      opts.separator "Material options:"
      opts.on("-t", "--thickness THICKNESS", Float, "Stock thickness (mm)") { |v| @options[:stock_thickness] = v }
      opts.on("--stock-width WIDTH", Float, "Stock sheet width (mm)") { |v| @options[:stock_width] = v }
      opts.on("--stock-height HEIGHT", Float, "Stock sheet height (mm)") { |v| @options[:stock_height] = v }
      opts.on("-f", "--finger-width WIDTH", Float, "Finger width (mm)") { |v| @options[:finger_width] = v }
      opts.on("-k", "--kerf KERF", Float, "Kerf compensation (mm)") { |v| @options[:kerf] = v }
      opts.on("-b", "--bit-diameter DIA", Float, "End mill diameter (mm)") { |v| @options[:bit_diameter] = v }

      opts.separator ""
      opts.separator "Features:"
      opts.on("--[no-]lid", "Enable/disable lid") { |v| @options[:enable_lid] = v }
      opts.on("--[no-]dividers", "Enable/disable dividers") { |v| @options[:enable_dividers] = v }
      opts.on("--lid-height HEIGHT", Float, "Lid height (mm)") { |v| @options[:lid_height] = v }
      opts.on("--lid-tolerance TOL", Float, "Lid tolerance (mm)") { |v| @options[:lid_tolerance] = v }

      opts.separator ""
      opts.separator "Interface:"
      opts.on("-i", "--interactive", "Launch interactive menu") { |v| @options[:interactive] = v }

      opts.separator ""
      opts.separator "Project options:"
      opts.on("-p", "--project FILE", "Load project configuration") { |v| load_project_from_cli(v) }
      opts.on("--save-project NAME", "Save current config as project") { |v| save_project_from_cli(v) }
      opts.on("--projects-dir DIR", "Projects directory") { |v| @options[:projects_dir] = v }

      opts.separator ""
      opts.separator "Output options:"
      opts.on("-o", "--output DIR", "Output directory") { |v| @options[:output_dir] = v }
      opts.on("--[no-]open", "Open with system viewer") { |v| @options[:open_viewer] = v }
      opts.on("-s", "--spacing SPACING", Float, "Part spacing (mm)") { |v| @options[:part_spacing] = v }
      opts.on("--[no-]gcode", "Generate G-code from SVG files") { |v| @options[:generate_gcode] = v }
      opts.on("--[no-]stl", "Generate STL preview of assembled box") { |v| @options[:generate_stl] = v }

      opts.separator ""
      opts.on("--help", "Show this help") do
        puts opts
        exit
      end

      opts.on("--version", "Show version") do
        puts VERSION
        exit
      end
    end.parse!(args)
  end

  def open_with_viewer(file)
    require 'launchy'
    if File.extname(file).downcase == '.svg'
      preview = File.join(File.dirname(file), "preview_#{File.basename(file, '.svg')}.html")
      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8" />
          <title>SVG Preview</title>
        </head>
        <body style="margin:0">
          <object type="image/svg+xml" data="#{File.basename(file)}" width="100%" height="100%"></object>
        </body>
        </html>
      HTML
      File.write(preview, html)
      Launchy.open(preview)
    else
      Launchy.open(file)
    end
  end

  def convert_svg_to_gcode(svg_file)
    require 'svgcode'
    out_file = svg_file.sub(/\.svg\z/i, '.ngc')
    begin
      svg_str = File.read(svg_file)
      gcode = Svgcode.parse(svg_str)
      File.write(out_file, gcode)
      out_file
    rescue => e
      puts "❌ Error converting #{File.basename(svg_file)}: #{e.message}"
      nil
    end
  end
end

# Main execution
if __FILE__ == $0
  BoxMaker.new.run(ARGV)
end
