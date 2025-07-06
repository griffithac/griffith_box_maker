#!/usr/bin/env ruby

require 'tty-prompt'
require_relative 'tty_prompt_key_select_patch'
require 'pastel'
require_relative 'project_manager'
require_relative 'stock_manager'
require_relative 'tool_manager'

class MenuSystem
  def initialize(box_maker)
    @box_maker = box_maker
    @options = @box_maker.instance_variable_get(:@options).dup
    @prompt = TTY::Prompt.new
    @pastel = Pastel.new
    @stock_manager = StockManager.new(@prompt, @pastel)
    @tool_manager = ToolManager.new(@prompt, @pastel)
  end

  def run
    show_welcome
    main_menu_loop
  end

  private

  def show_welcome
    clear_screen
    puts @pastel.cyan.bold("╔═══════════════════════════════════════════════════════════════════╗")
    puts @pastel.cyan.bold("║                        📦 BOX MAKER CLI                           ║")
    puts @pastel.cyan.bold("║                    Interactive Configuration                       ║")
    puts @pastel.cyan.bold("╚═══════════════════════════════════════════════════════════════════╝")
    puts
  end

  def main_menu_loop
    loop do
      clear_screen
      show_current_config

      puts @pastel.dim("Navigation: ↑↓ arrows, letter keys, or ENTER to select")
      puts

      choice = @prompt.select("#{@pastel.bold('Main Menu:')} What would you like to do?", per_page: 20) do |menu|
        menu.choice "📏 (D)imensions - Configure box size", :dimensions, key: 'd'
        menu.choice "📦 (M)aterial - Stock materials", :stock, key: 'm'
        menu.choice "🔧 (T)ools - Cutting tools", :tools, key: 't'
        menu.choice "🤝 (J)oints - Finger width, dogbones", :joints, key: 'j'
        menu.choice "🎯 (F)eatures - Lid and dividers", :features, key: 'f'
        menu.choice "📁 (O)utput - Directory and viewer", :output, key: 'o'
        menu.choice "📋 (C)onfigurations - Load common setups", :configurations, key: 'c'
        menu.choice "📐 (L)ayout - Preview stock layout", :layout_preview, key: 'l'
        menu.choice "💼 (P)rojects - Project management", :projects, key: 'p'
        menu.choice "🚀 (G)enerate - Create SVG files", :generate, key: 'g'
        menu.choice "💾 (S)ave - Save current config", :save, key: 's'
        menu.choice "❌ (Q)uit", :exit, key: 'q'
      end

      case choice
      when :dimensions
        configure_dimensions
      when :stock
        manage_stock
      when :tools
        manage_tools
      when :joints
        configure_joints
      when :features
        configure_features
      when :output
        configure_output
      when :configurations
        load_configuration
      when :layout_preview
        preview_layout
      when :projects
        manage_projects
      when :generate
        generate_box
      when :save
        save_configuration
      when :exit
        break
      end

      # Clear screen after each task completion before returning to menu
      # (except for exit which breaks the loop)
    end

    puts @pastel.cyan("👋 Thanks for using Box Maker CLI!")
  end



  def show_current_config
    puts @pastel.bold("\n📋 Current Configuration (all measurements in mm):")
    puts "#{@pastel.cyan('Box:')} #{@options[:box_length]}×#{@options[:box_width]}×#{@options[:box_height]}mm"

    # Show current stock info
    current_stock = @stock_manager.get_current_stock
    if current_stock
      puts "#{@pastel.yellow('Stock:')} #{current_stock[:name]} - #{current_stock[:properties][:width]}×#{current_stock[:properties][:height]}×#{current_stock[:properties][:thickness]}mm, #{current_stock[:properties][:kerf]}mm kerf"
    else
      puts "#{@pastel.yellow('Stock:')} #{@options[:stock_thickness]}mm thick, #{@options[:stock_width]}×#{@options[:stock_height]}mm stock, #{@options[:kerf]}mm kerf"
    end

    # Show current tool info
    current_tool = @tool_manager.get_current_tool
    if current_tool
      puts "#{@pastel.green('Tool:')} #{current_tool[:name]} - #{current_tool[:properties][:diameter]}mm #{current_tool[:tool_type]}"
    else
      puts "#{@pastel.green('Tool:')} #{@options[:bit_diameter]}mm bit"
    end

    puts "#{@pastel.blue('Fingers:')} #{@options[:finger_width]}mm wide, #{dogbone_description} dogbones"

    features = []
    features << @pastel.blue("Lid") if @options[:enable_lid]
    features << @pastel.magenta("Dividers") if @options[:enable_dividers]
    features_text = features.empty? ? @pastel.dim("Box only") : features.join(", ")
    puts "#{@pastel.bold('Features:')} #{features_text}"

    # Estimate panel count
    panel_count = 5  # Basic box panels
    panel_count += 5 if @options[:enable_lid]
    panel_count += 1 if @options[:enable_dividers] && @options[:enable_x_divider]
    panel_count += 1 if @options[:enable_dividers] && @options[:enable_y_divider]
    puts "#{@pastel.cyan('Panels:')} #{panel_count} panels estimated"
    puts
  end

  def configure_dimensions
    puts @pastel.bold.cyan("\n📏 Box Dimensions Configuration")

    choice = @prompt.select("Which dimension to configure?", per_page: 15) do |menu|
      menu.choice "(L)ength: #{@options[:box_length]}mm", :length, key: 'l'
      menu.choice "(W)idth: #{@options[:box_width]}mm", :width, key: 'w'
      menu.choice "(H)eight: #{@options[:box_height]}mm", :height, key: 'h'
      menu.choice "(A)ll dimensions", :all, key: 'a'
      menu.choice "(R)eturn to Main Menu", :return, key: 'r'
    end

    case choice
    when :length
      @options[:box_length] = @prompt.ask("Box Length (mm):", default: @options[:box_length]) { |q| q.convert :float }
    when :width
      @options[:box_width] = @prompt.ask("Box Width (mm):", default: @options[:box_width]) { |q| q.convert :float }
    when :height
      @options[:box_height] = @prompt.ask("Box Height (mm):", default: @options[:box_height]) { |q| q.convert :float }
    when :all
      @options[:box_length] = @prompt.ask("Box Length (mm):", default: @options[:box_length]) { |q| q.convert :float }
      @options[:box_width] = @prompt.ask("Box Width (mm):", default: @options[:box_width]) { |q| q.convert :float }
      @options[:box_height] = @prompt.ask("Box Height (mm):", default: @options[:box_height]) { |q| q.convert :float }
    when :return
      return
    end

    puts @pastel.green("✅ Dimensions updated!")
    @prompt.keypress("Press any key to continue...")
    clear_screen
  end

  def manage_stock
    @stock_manager.run

    # Apply any loaded stock to current options
    @stock_manager.apply_stock_to_options(@options)
    clear_screen
  end

  def configure_joints
    puts @pastel.bold.green("\n🤝 Joint Settings Configuration")

    choice = @prompt.select("Which joint setting to configure?", per_page: 15) do |menu|
      menu.choice "(F)inger Width: #{@options[:finger_width]}mm", :finger_width, key: 'f'
      menu.choice "(D)ogbone Style: #{dogbone_description}", :dogbone, key: 'd'
      menu.choice "(B)oth settings", :both, key: 'b'
      menu.choice "(R)eturn to Main Menu", :return, key: 'r'
    end

    case choice
    when :finger_width
      @options[:finger_width] = @prompt.ask("Finger Width (mm):", default: @options[:finger_width]) { |q| q.convert :float }
    when :dogbone
      configure_dogbone_style
    when :both
      @options[:finger_width] = @prompt.ask("Finger Width (mm):", default: @options[:finger_width]) { |q| q.convert :float }
      configure_dogbone_style
    when :return
      return
    end

    puts @pastel.green("✅ Joint settings updated!")
    @prompt.keypress("Press any key to continue...")
    clear_screen
  end

  def configure_dogbone_style
    dogbone_choice = @prompt.select("Dogbone Relief Style:", per_page: 15) do |menu|
      menu.choice "(N)one", 0, key: 'n'
      menu.choice "(L)ong Side", 1, key: 'l'
      menu.choice "(T)-Bone", 2, key: 't'
      menu.choice "(F)illets 45° (Recommended)", 3, key: 'f'
      menu.default dogbone_choice_index
    end
    @options[:dogbone_style] = dogbone_choice
  end

  def configure_features
    puts @pastel.bold.magenta("\n🎯 Box Features Configuration")

    choice = @prompt.select("Configure which features?", per_page: 15) do |menu|
      menu.choice "🎩 (L)id Options", :lid, key: 'l'
      menu.choice "📦 (D)ivider Options", :dividers, key: 'd'
      menu.choice "⚙️ (B)oth Lid and Dividers", :both, key: 'b'
      menu.choice "🔙 (R)eturn to Main Menu", :return, key: 'r'
    end

    case choice
    when :lid
      configure_lid
    when :dividers
      configure_dividers
    when :both
      configure_lid
      configure_dividers
    when :return
      return
    end
  end

  def configure_lid
    puts @pastel.bold.blue("\n🎩 Lid Configuration")

    @options[:enable_lid] = @prompt.yes?("Enable lid?", default: @options[:enable_lid])

    if @options[:enable_lid]
      @options[:lid_height] = @prompt.ask("Lid Height (mm):", default: @options[:lid_height]) { |q| q.convert :float }
      @options[:lid_tolerance] = @prompt.ask("Lid Tolerance (mm):", default: @options[:lid_tolerance]) { |q| q.convert :float }
    end

    puts @pastel.green("✅ Lid configuration updated!")
    @prompt.keypress("Press any key to continue...")
    clear_screen
  end

  def configure_dividers
    puts @pastel.bold.magenta("\n📦 Divider Configuration")

    @options[:enable_dividers] = @prompt.yes?("Enable dividers?", default: @options[:enable_dividers])

    if @options[:enable_dividers]
      @options[:enable_x_divider] = @prompt.yes?("Enable X-direction divider?", default: @options[:enable_x_divider])
      @options[:enable_y_divider] = @prompt.yes?("Enable Y-direction divider?", default: @options[:enable_y_divider])
    end

    puts @pastel.green("✅ Divider configuration updated!")
    @prompt.keypress("Press any key to continue...")
    clear_screen
  end

  def configure_output
    puts @pastel.bold.white("\n📁 Output Configuration")

    choice = @prompt.select("Which output setting to configure?", per_page: 15) do |menu|
      menu.choice "(D)irectory: #{@options[:output_dir]}", :directory, key: 'd'
      menu.choice "(V)iewer: #{@options[:open_viewer] ? 'Auto-open' : 'Manual'}", :viewer, key: 'v'
      menu.choice "(B)oth settings", :both, key: 'b'
      menu.choice "(R)eturn to Main Menu", :return, key: 'r'
    end

    case choice
    when :directory
      @options[:output_dir] = @prompt.ask("Output Directory:", default: @options[:output_dir])
    when :viewer
      @options[:open_viewer] = @prompt.yes?("Auto-open with system viewer?", default: @options[:open_viewer])
    when :both
      @options[:output_dir] = @prompt.ask("Output Directory:", default: @options[:output_dir])
      @options[:open_viewer] = @prompt.yes?("Auto-open with system viewer?", default: @options[:open_viewer])
    when :return
      return
    end

    puts @pastel.green("✅ Output configuration updated!")
    @prompt.keypress("Press any key to continue...")
    clear_screen
  end

  def load_configuration
    puts @pastel.bold.blue("\n📋 Common Configurations")

    configurations = {
      "Small Parts Organizer" => {
        box_length: 150, box_width: 100, box_height: 50,
        finger_width: 20, enable_lid: false
      },
      "Tool Box" => {
        box_length: 300, box_width: 200, box_height: 100,
        finger_width: 30, enable_lid: true, lid_height: 40
      },
      "Electronics Enclosure" => {
        box_length: 120, box_width: 80, box_height: 40,
        stock_thickness: 3, finger_width: 15
      },
      "Workshop Storage" => {
        box_length: 400, box_width: 300, box_height: 120,
        finger_width: 40, enable_dividers: true
      },
      "Jewelry Box" => {
        box_length: 180, box_width: 120, box_height: 40,
        stock_thickness: 3, kerf: 0.1, finger_width: 15
      },
      "Document Box" => {
        box_length: 350, box_width: 250, box_height: 80,
        finger_width: 35, enable_lid: true
      }
    }

    choice = @prompt.select("Select a configuration:", per_page: 15) do |menu|
      menu.choice "(S)mall Parts Organizer - 150×100×50mm, no lid", "Small Parts Organizer", key: 's'
      menu.choice "(T)ool Box - 300×200×100mm, with lid", "Tool Box", key: 't'
      menu.choice "(E)lectronics Enclosure - 120×80×40mm, 3mm material", "Electronics Enclosure", key: 'e'
      menu.choice "(W)orkshop Storage - 400×300×120mm, with dividers", "Workshop Storage", key: 'w'
      menu.choice "(J)ewelry Box - 180×120×40mm, fine tolerances", "Jewelry Box", key: 'j'
      menu.choice "(D)ocument Box - 350×250×80mm, with lid", "Document Box", key: 'd'
      menu.choice "(C)ancel", :cancel, key: 'c'
    end

    return if choice == :cancel

    # Apply configuration
    configuration = configurations[choice]
    configuration.each { |key, value| @options[key] = value }

    puts @pastel.green("✅ Applied configuration: #{choice}")
    @prompt.keypress("Press any key to continue...")
    clear_screen
  end

  def generate_box
    puts @pastel.bold.green("\n🚀 Generating Box Files")
    puts

    begin
      # Update the box_maker instance with current options
      @box_maker.instance_variable_get(:@options).merge!(@options)

      # Create calculator and generate
      calculator = FingerJointCalculator.new(@options)
      layouts = calculator.calculate_all_layouts

      # Show finger layout info
      puts @pastel.bold("📊 Calculated Finger Layouts:")
      layouts.each do |key, layout|
        direction = key.to_s.gsub('_', ' ').capitalize
        puts "  #{@pastel.cyan(direction)}: #{layout[:count]} fingers @ #{layout[:width].round(2)}mm each"
      end
      puts

      # Create output directory
      FileUtils.mkdir_p(@options[:output_dir])

      # Generate SVG files
      puts "📝 Generating SVG files..."
      generator = SVGGenerator.new(@options, layouts)
      files = generator.generate_all_panels

      puts @pastel.green("✅ Successfully generated #{files.length} panel files:")
      files.each { |file| puts "  📄 #{File.basename(file)}" }
      puts
      puts "📁 Output directory: #{@pastel.cyan(@options[:output_dir])}"

      # Open with viewer if requested
      if @options[:open_viewer] && !files.empty?
        puts "👁️ Opening first file with system viewer..."
        @box_maker.send(:open_with_viewer, files.first)
      end

      @prompt.keypress("Press any key to continue...", keys: [:return, :space])
      clear_screen

    rescue => e
      puts @pastel.red("❌ Error generating box: #{e.message}")
      puts @pastel.dim("Stacktrace:")
      e.backtrace.each { |line| puts @pastel.dim("  #{line}") }
      @prompt.keypress("Press any key to continue...", keys: [:return, :space])
      clear_screen
    end

    def configure_stock_dimensions
      puts @pastel.bold.blue("\n📐 Stock Material Dimensions")
      puts
      puts "Configure your stock material sheet dimensions for optimal layout planning."
      puts

      puts @pastel.cyan("Current Stock Dimensions:")
      puts "  Width: #{@options[:stock_width]}mm"
      puts "  Height: #{@options[:stock_height]}mm"
      puts "  Thickness: #{@options[:stock_thickness]}mm"
      puts "  Total Area: #{(@options[:stock_width] * @options[:stock_height] / 1000000.0).round(2)} m²"
      puts

      choice = @prompt.select("What would you like to do?") do |menu|
        menu.choice "📏 (W)idth: #{@options[:stock_width]}mm", :width, key: "w"
        menu.choice "📏 (H)eight: #{@options[:stock_height]}mm", :height, key: "h"
        menu.choice "📏 (T)hickness: #{@options[:stock_thickness]}mm", :thickness, key: "t"
        menu.choice "📋 (C)onfigurations - Common stock sizes", :stock_configurations, key: "c"
        menu.choice "🔄 (A)ll dimensions", :all, key: "a"
        menu.choice "🔙 (R)eturn to Material Menu", :return, key: "r"
      end

      case choice
      when :width
        @options[:stock_width] = @prompt.ask("Stock Sheet Width (mm):", default: @options[:stock_width]) { |q| q.convert :float }
      when :height
        @options[:stock_height] = @prompt.ask("Stock Sheet Height (mm):", default: @options[:stock_height]) { |q| q.convert :float }
      when :thickness
        @options[:stock_thickness] = @prompt.ask("Stock Thickness (mm):", default: @options[:stock_thickness]) { |q| q.convert :float }
      when :stock_configurations
        configure_stock_configurations
      when :all
        @options[:stock_width] = @prompt.ask("Stock Sheet Width (mm):", default: @options[:stock_width]) { |q| q.convert :float }
        @options[:stock_height] = @prompt.ask("Stock Sheet Height (mm):", default: @options[:stock_height]) { |q| q.convert :float }
        @options[:stock_thickness] = @prompt.ask("Stock Thickness (mm):", default: @options[:stock_thickness]) { |q| q.convert :float }
      when :return
        return
      end

      puts @pastel.green("✅ Stock dimensions updated!")
    end

    def configure_stock_configurations
      puts @pastel.bold.blue("\n📋 Common Stock Sizes")

      configurations = {
        "4x8 Plywood (1220×2440mm)" => { stock_width: 1220, stock_height: 2440, stock_thickness: 12 },
        "4x4 Plywood (1220×1220mm)" => { stock_width: 1220, stock_height: 1220, stock_thickness: 12 },
        "3x3 MDF (900×900mm)" => { stock_width: 900, stock_height: 900, stock_thickness: 6 },
        "A1 Acrylic (594×841mm)" => { stock_width: 594, stock_height: 841, stock_thickness: 3 },
        "Letter Size (216×279mm)" => { stock_width: 216, stock_height: 279, stock_thickness: 3 },
        "A4 Size (210×297mm)" => { stock_width: 210, stock_height: 297, stock_thickness: 3 }
      }

      choice = @prompt.select("Select a stock size configuration:") do |menu|
        menu.choice "🏠 (1) 4x8 Plywood - 1220×2440×12mm", "4x8 Plywood (1220×2440mm)", key: "1"
        menu.choice "📦 (2) 4x4 Plywood - 1220×1220×12mm", "4x4 Plywood (1220×1220mm)", key: "2"
        menu.choice "🔧 (3) 3x3 MDF - 900×900×6mm", "3x3 MDF (900×900mm)", key: "3"
        menu.choice "💎 (4) A1 Acrylic - 594×841×3mm", "A1 Acrylic (594×841mm)", key: "4"
        menu.choice "📄 (5) Letter Size - 216×279×3mm", "Letter Size (216×279mm)", key: "5"
        menu.choice "📄 (6) A4 Size - 210×297×3mm", "A4 Size (210×297mm)", key: "6"
        menu.choice "❌ (C)ancel", :cancel, key: "c"
      end

      return if choice == :cancel

      configuration = configurations[choice]
      @options[:stock_width] = configuration[:stock_width]
      @options[:stock_height] = configuration[:stock_height]
      @options[:stock_thickness] = configuration[:stock_thickness]

      puts @pastel.green("✅ Applied stock configuration: #{choice}")
    end
  end

  def save_configuration
    puts @pastel.bold.yellow("\n💾 Save Configuration")

    filename = @prompt.ask("Enter filename (without extension):") do |q|
      q.required true
      q.validate /^[a-zA-Z0-9_\-]+$/
      q.messages[:valid?] = "Filename can only contain letters, numbers, underscores, and hyphens"
    end

    config_file = "#{filename}.json"

    begin
      require 'json'
      File.write(config_file, JSON.pretty_generate(@options))
      puts @pastel.green("✅ Configuration saved to #{config_file}")
    rescue => e
      puts @pastel.red("❌ Error saving configuration: #{e.message}")
    end

    @prompt.keypress("Press any key to continue...", keys: [:return, :space])
  end

  def preview_layout
    puts @pastel.bold.cyan("\n📐 Stock Layout Preview")
    puts

    begin
      require_relative 'layout_optimizer'

      # Create optimizer with current options
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

      puts
      choice = @prompt.select("What would you like to do?", per_page: 15) do |menu|
        menu.choice "📄 (G)enerate layout SVG files", :generate_layout, key: 'g'
        menu.choice "👁️ (V)iew layout (if SVG exists)", :view_layout, key: 'v'
        menu.choice "🔙 (R)eturn to Main Menu", :return, key: 'r'
      end

      case choice
      when :generate_layout
        puts "\n📐 Generating layout SVG files..."
        FileUtils.mkdir_p(@options[:output_dir])
        layout_files = optimizer.generate_cutting_layout_svg(layout, @options[:output_dir])

        puts @pastel.green("✅ Generated layout files:")
        layout_files.each { |file| puts "  📄 #{File.basename(file)}" }

        if @options[:open_viewer] && !layout_files.empty?
          puts "\n👁️ Opening layout with system viewer..."
          @box_maker.send(:open_with_viewer, layout_files.first)
        end
      when :view_layout
        layout_file = File.join(@options[:output_dir], "cutting_layout_sheet_1.svg")
        if File.exist?(layout_file)
          puts "\n👁️ Opening existing layout with system viewer..."
          @box_maker.send(:open_with_viewer, layout_file)
        else
          puts @pastel.red("❌ No layout file found. Generate layout first.")
        end
      when :return
        return
      end

    rescue => e
      puts @pastel.red("❌ Error previewing layout: #{e.message}")
      puts @pastel.dim("Stacktrace:")
      e.backtrace.each { |line| puts @pastel.dim("  #{line}") }
    end

    @prompt.keypress("Press any key to continue...", keys: [:return, :space])
    clear_screen
    clear_screen
  end

  def manage_tools
    @tool_manager.run

    # Apply any loaded tool to current options
    @tool_manager.apply_tool_to_options(@options)
    clear_screen
  end

  def manage_projects
    puts @pastel.bold.blue("\n💼 Project Management")

    begin
      project_manager = ProjectManager.new(@options, @prompt, @pastel)
      project_manager.set_stock_manager(@stock_manager)
      project_manager.set_tool_manager(@tool_manager)
      project_manager.run

      # Update options with any changes from project loading
      @options.merge!(project_manager.get_options)
    rescue => e
      puts @pastel.red("❌ Error in project management: #{e.message}")
      puts @pastel.dim("Stacktrace:")
      e.backtrace.each { |line| puts @pastel.dim("  #{line}") }
      @prompt.keypress("Press any key to continue...")
    end
    clear_screen
  end

  private

  def clear_screen
    system('clear') || system('cls') || print("\e[2J\e[H")
  end

  def dogbone_description
    case @options[:dogbone_style]
    when 0 then "None"
    when 1 then "Long Side"
    when 2 then "T-Bone"
    when 3 then "45° Fillets"
    else "Unknown"
    end
  end

  def dogbone_choice_index
    [@options[:dogbone_style] + 1, 4].min
  end
end
