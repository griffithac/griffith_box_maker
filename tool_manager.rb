#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'time'

class ToolManager
  def initialize(prompt, pastel)
    @prompt = prompt
    @pastel = pastel
    @tools_dir = File.join(Dir.pwd, 'tools')
    @current_tool = nil

    # Ensure tools directory exists
    FileUtils.mkdir_p(@tools_dir)

    # Create default tool files if they don't exist
    create_default_tool_files
  end

  def run
    loop do
      clear_screen
      show_tool_menu
      choice = get_menu_choice

      case choice
      when :view_current
        view_current_tool
      when :load_tool
        load_tool
      when :create_tool
        create_new_tool
      when :edit_tool
        edit_tool
      when :duplicate_tool
        duplicate_tool
      when :delete_tool
        delete_tool
      when :list_all
        list_all_tools
      when :export_tool
        export_tool
      when :import_tool
        import_tool
      when :return
        break
      end
    end
  end

  def get_current_tool
    @current_tool
  end

  def load_tool_by_name(tool_name)
    tool_file = File.join(@tools_dir, "#{tool_name.downcase.gsub(/[^a-z0-9_]/, '_')}.json")

    if File.exist?(tool_file)
      load_tool_file(tool_file)
      return @current_tool
    end

    nil
  end

  def apply_tool_to_options(options)
    return options unless @current_tool

    tool_props = @current_tool[:properties]

    options[:bit_diameter] = tool_props[:diameter]
    options[:spindle_speed] = tool_props[:recommended_rpm] if tool_props[:recommended_rpm]
    options[:feed_rate] = tool_props[:recommended_feed_rate] if tool_props[:recommended_feed_rate]
    options[:plunge_rate] = tool_props[:recommended_plunge_rate] if tool_props[:recommended_plunge_rate]

    options
  end

  private

  def show_tool_menu
    puts @pastel.bold.yellow("\n🔧 Cutting Tool Manager")
    puts "=" * 60

    if @current_tool
      puts @pastel.cyan("🔧 Current Tool: #{@current_tool[:name]}")
      puts @pastel.dim("   Type: #{@current_tool[:tool_type]}")
      puts @pastel.dim("   Diameter: #{@current_tool[:properties][:diameter]}mm")
      puts @pastel.dim("   Material: #{@current_tool[:material]}")
    else
      puts @pastel.dim("🔧 No tool selected")
    end
    puts
  end

  def get_menu_choice
    @prompt.select("What would you like to do?", per_page: 15) do |menu|
      menu.choice "👁️ (V)iew Current Tool Details", :view_current, key: "v"
      menu.choice "📂 (L)oad Tool", :load_tool, key: "l"
      menu.choice "➕ (C)reate New Tool", :create_tool, key: "c"
      menu.choice "✏️ (E)dit Tool", :edit_tool, key: "e"
      menu.choice "📄 (D)uplicate Tool", :duplicate_tool, key: "d"
      menu.choice "🗑️ Delete Tool", :delete_tool, key: "x"
      menu.choice "📋 (A)ll Tools", :list_all, key: "a"
      menu.choice "📤 E(x)port Tool", :export_tool, key: "p"
      menu.choice "📥 (I)mport Tool", :import_tool, key: "i"
      menu.choice "🔙 (R)eturn to Main Menu", :return, key: "r"
    end
  end

  def view_current_tool
    unless @current_tool
      puts @pastel.red("❌ No cutting tool selected")
      @prompt.keypress("Press any key to continue...")
      return
    end

    tool = @current_tool
    props = tool[:properties]

    puts @pastel.bold.cyan("\n🔧 Cutting Tool Details")
    puts "=" * 50

    puts "#{@pastel.bold('Name:')} #{tool[:name]}"
    puts "#{@pastel.bold('Type:')} #{tool[:tool_type]}"
    puts "#{@pastel.bold('Material:')} #{tool[:material]}"
    puts "#{@pastel.bold('Manufacturer:')} #{tool[:manufacturer] || 'Unknown'}"
    puts

    puts @pastel.bold("📐 Physical Properties:")
    puts "  Diameter: #{props[:diameter]}mm"
    puts "  Length: #{props[:length] || 'Not specified'}mm"
    puts "  Shank Diameter: #{props[:shank_diameter] || 'Not specified'}mm"
    puts "  Flutes: #{props[:flutes] || 'Not specified'}"
    puts

    puts @pastel.bold("⚙️ Cutting Parameters:")
    puts "  Recommended RPM: #{props[:recommended_rpm] || 'Not specified'}"
    puts "  Max RPM: #{props[:max_rpm] || 'Not specified'}"
    puts "  Feed Rate: #{props[:recommended_feed_rate] || 'Not specified'} mm/min"
    puts "  Plunge Rate: #{props[:recommended_plunge_rate] || 'Not specified'} mm/min"
    puts "  Max DOC: #{props[:max_depth_of_cut] || 'Not specified'}mm"
    puts

    puts @pastel.bold("🎯 Applications:")
    if tool[:suitable_materials] && !tool[:suitable_materials].empty?
      puts "  Suitable Materials: #{tool[:suitable_materials].join(', ')}"
    end
    puts "  Operation: #{props[:operation_type] || 'General'}"
    puts

    puts @pastel.bold("💰 Cost Information:")
    puts "  Purchase Cost: #{props[:purchase_cost] ? "$#{props[:purchase_cost]}" : 'Not specified'}"
    puts "  Expected Life: #{props[:expected_life_hours] ? "#{props[:expected_life_hours]} hours" : 'Not specified'}"
    puts "  Cost per Hour: #{calculate_cost_per_hour(props)}"
    puts

    if tool[:notes] && !tool[:notes].empty?
      puts @pastel.bold("📝 Notes:")
      puts "  #{tool[:notes]}"
      puts
    end

    puts @pastel.dim("Created: #{format_date(tool[:created_at])}")
    puts @pastel.dim("Updated: #{format_date(tool[:updated_at])}")

    @prompt.keypress("Press any key to continue...")
  end

  def load_tool
    tool_files = get_available_tool_files

    if tool_files.empty?
      puts @pastel.red("❌ No cutting tools found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📂 Load Cutting Tool")

    choices = tool_files.map do |tool_file|
      info = get_tool_info(tool_file[:filepath])
      if info
        description = "#{info[:tool_type]} - #{info[:diameter]}mm - #{info[:material]}"
        { name: "#{info[:name]} (#{description})", value: tool_file[:filepath] }
      else
        { name: tool_file[:name], value: tool_file[:filepath] }
      end
    end

    choices << { name: "❌ Cancel", value: :cancel }

    choice = @prompt.select("Select cutting tool:", choices, per_page: 15)

    return if choice == :cancel

    load_tool_file(choice)
  end

  def load_tool_file(filepath)
    begin
      tool_data = JSON.parse(File.read(filepath), symbolize_names: true)

      # Validate tool structure
      unless tool_data[:properties] && tool_data[:properties][:diameter]
        puts @pastel.red("❌ Invalid tool file format")
        return false
      end

      @current_tool = tool_data

      # Update timestamp
      @current_tool[:updated_at] = Time.now.iso8601
      File.write(filepath, JSON.pretty_generate(@current_tool))

      puts @pastel.green("✅ Cutting tool '#{@current_tool[:name]}' loaded successfully!")
      @prompt.keypress("Press any key to continue...")
      return true

    rescue JSON::ParserError => e
      puts @pastel.red("❌ Error parsing tool file: #{e.message}")
      @prompt.keypress("Press any key to continue...")
      return false
    rescue => e
      puts @pastel.red("❌ Error loading tool: #{e.message}")
      @prompt.keypress("Press any key to continue...")
      return false
    end
  end

  def create_new_tool
    puts @pastel.bold.cyan("\n➕ Create New Cutting Tool")

    # Basic information
    name = @prompt.ask("Tool name:") do |q|
      q.required true
      q.validate /^[a-zA-Z0-9_\-\s\.\/]+$/
      q.messages[:valid?] = "Name can only contain letters, numbers, spaces, periods, slashes, underscores, and hyphens"
    end

    tool_type = @prompt.select("Tool type:", per_page: 15) do |menu|
      menu.choice "End Mill", "end_mill"
      menu.choice "Ball End Mill", "ball_end_mill"
      menu.choice "V-Bit", "v_bit"
      menu.choice "Straight Bit", "straight_bit"
      menu.choice "Spiral Bit", "spiral_bit"
      menu.choice "Drill Bit", "drill_bit"
      menu.choice "Engraving Bit", "engraving_bit"
      menu.choice "Other", "other"
    end

    if tool_type == "other"
      tool_type = @prompt.ask("Specify tool type:")
    end

    material = @prompt.select("Tool material:", per_page: 15) do |menu|
      menu.choice "Carbide", "carbide"
      menu.choice "HSS (High Speed Steel)", "hss"
      menu.choice "Cobalt", "cobalt"
      menu.choice "Diamond", "diamond"
      menu.choice "Other", "other"
    end

    if material == "other"
      material = @prompt.ask("Specify tool material:")
    end

    # Physical properties
    puts "\n📐 Physical Properties:"
    diameter = @prompt.ask("Diameter (mm):", convert: :float)
    length = @prompt.ask("Overall length (mm, optional):", convert: :float) rescue nil
    shank_diameter = @prompt.ask("Shank diameter (mm, optional):", convert: :float) rescue nil
    flutes = @prompt.ask("Number of flutes (optional):", convert: :int) rescue nil

    # Cutting parameters
    puts "\n⚙️ Cutting Parameters:"
    recommended_rpm = @prompt.ask("Recommended RPM (optional):", convert: :int) rescue nil
    max_rpm = @prompt.ask("Maximum RPM (optional):", convert: :int) rescue nil
    recommended_feed_rate = @prompt.ask("Recommended feed rate (mm/min, optional):", convert: :float) rescue nil
    recommended_plunge_rate = @prompt.ask("Recommended plunge rate (mm/min, optional):", convert: :float) rescue nil
    max_depth_of_cut = @prompt.ask("Maximum depth of cut (mm, optional):", convert: :float) rescue nil

    # Applications
    puts "\n🎯 Applications:"
    suitable_materials = @prompt.multi_select("Suitable materials (space to select):", per_page: 15) do |menu|
      menu.choice "Plywood"
      menu.choice "MDF"
      menu.choice "Hardwood"
      menu.choice "Softwood"
      menu.choice "Acrylic"
      menu.choice "PETG"
      menu.choice "Aluminum"
      menu.choice "Brass"
      menu.choice "Carbon Fiber"
      menu.choice "Cardboard"
    end

    operation_type = @prompt.select("Primary operation:", per_page: 15) do |menu|
      menu.choice "Profiling", "profiling"
      menu.choice "Pocketing", "pocketing"
      menu.choice "Drilling", "drilling"
      menu.choice "Engraving", "engraving"
      menu.choice "V-Carving", "v_carving"
      menu.choice "General", "general"
    end

    # Optional information
    puts "\n💰 Optional Information:"
    manufacturer = @prompt.ask("Manufacturer (optional):")
    purchase_cost = @prompt.ask("Purchase cost (optional, no $ sign):", convert: :float) rescue nil
    expected_life_hours = @prompt.ask("Expected life (hours, optional):", convert: :float) rescue nil
    notes = @prompt.ask("Notes (optional):")

    tool_data = {
      name: name,
      tool_type: tool_type,
      material: material,
      manufacturer: manufacturer.empty? ? nil : manufacturer,
      suitable_materials: suitable_materials,
      created_at: Time.now.iso8601,
      updated_at: Time.now.iso8601,
      properties: {
        diameter: diameter,
        length: length,
        shank_diameter: shank_diameter,
        flutes: flutes,
        recommended_rpm: recommended_rpm,
        max_rpm: max_rpm,
        recommended_feed_rate: recommended_feed_rate,
        recommended_plunge_rate: recommended_plunge_rate,
        max_depth_of_cut: max_depth_of_cut,
        operation_type: operation_type,
        purchase_cost: purchase_cost,
        expected_life_hours: expected_life_hours
      },
      notes: notes.empty? ? nil : notes
    }

    # Save tool
    filename = name.downcase.gsub(/[^a-z0-9_]/, '_') + '.json'
    filepath = File.join(@tools_dir, filename)

    if File.exist?(filepath)
      overwrite = @prompt.yes?("Tool '#{name}' already exists. Overwrite?")
      return unless overwrite
    end

    File.write(filepath, JSON.pretty_generate(tool_data))
    @current_tool = tool_data

    puts @pastel.green("✅ Cutting tool '#{name}' created and loaded!")
    @prompt.keypress("Press any key to continue...")
  end

  def edit_tool
    unless @current_tool
      puts @pastel.red("❌ No cutting tool selected. Load a tool first.")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.yellow("\n✏️ Edit Cutting Tool: #{@current_tool[:name]}")

    choice = @prompt.select("What would you like to edit?", per_page: 15) do |menu|
      menu.choice "📝 Name", :name
      menu.choice "🔧 Tool Type", :tool_type
      menu.choice "🧱 Material", :material
      menu.choice "📐 Physical Properties", :physical
      menu.choice "⚙️ Cutting Parameters", :cutting
      menu.choice "🎯 Applications", :applications
      menu.choice "🏭 Manufacturer", :manufacturer
      menu.choice "💰 Cost Information", :cost
      menu.choice "📝 Notes", :notes
      menu.choice "❌ Cancel", :cancel
    end

    return if choice == :cancel

    case choice
    when :name
      new_name = @prompt.ask("New name:", default: @current_tool[:name])
      @current_tool[:name] = new_name
    when :tool_type
      @current_tool[:tool_type] = @prompt.select("Tool type:",
        ["end_mill", "ball_end_mill", "v_bit", "straight_bit", "spiral_bit", "drill_bit", "engraving_bit", "other"], per_page: 15)
    when :material
      @current_tool[:material] = @prompt.select("Tool material:",
        ["carbide", "hss", "cobalt", "diamond", "other"], per_page: 15)
    when :physical
      props = @current_tool[:properties]
      props[:diameter] = @prompt.ask("Diameter (mm):", default: props[:diameter], convert: :float)
      props[:length] = @prompt.ask("Length (mm):", default: props[:length], convert: :float) rescue props[:length]
      props[:shank_diameter] = @prompt.ask("Shank diameter (mm):", default: props[:shank_diameter], convert: :float) rescue props[:shank_diameter]
      props[:flutes] = @prompt.ask("Flutes:", default: props[:flutes], convert: :int) rescue props[:flutes]
    when :cutting
      props = @current_tool[:properties]
      props[:recommended_rpm] = @prompt.ask("Recommended RPM:", default: props[:recommended_rpm], convert: :int) rescue props[:recommended_rpm]
      props[:recommended_feed_rate] = @prompt.ask("Feed rate (mm/min):", default: props[:recommended_feed_rate], convert: :float) rescue props[:recommended_feed_rate]
      props[:recommended_plunge_rate] = @prompt.ask("Plunge rate (mm/min):", default: props[:recommended_plunge_rate], convert: :float) rescue props[:recommended_plunge_rate]
    when :applications
      @current_tool[:suitable_materials] = @prompt.multi_select("Suitable materials:",
        ["Plywood", "MDF", "Hardwood", "Softwood", "Acrylic", "PETG", "Aluminum", "Brass", "Carbon Fiber", "Cardboard"],
        default: @current_tool[:suitable_materials], per_page: 15)
    when :manufacturer
      @current_tool[:manufacturer] = @prompt.ask("Manufacturer:", default: @current_tool[:manufacturer] || "")
    when :cost
      props = @current_tool[:properties]
      props[:purchase_cost] = @prompt.ask("Purchase cost:", default: props[:purchase_cost], convert: :float) rescue props[:purchase_cost]
      props[:expected_life_hours] = @prompt.ask("Expected life (hours):", default: props[:expected_life_hours], convert: :float) rescue props[:expected_life_hours]
    when :notes
      @current_tool[:notes] = @prompt.ask("Notes:", default: @current_tool[:notes] || "")
    end

    @current_tool[:updated_at] = Time.now.iso8601
    save_current_tool
    puts @pastel.green("✅ Cutting tool updated!")
    @prompt.keypress("Press any key to continue...")
  end

  def duplicate_tool
    tool_files = get_available_tool_files

    if tool_files.empty?
      puts @pastel.red("❌ No cutting tools found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📄 Duplicate Cutting Tool")

    choices = tool_files.map { |t| { name: t[:name], value: t[:filepath] } }
    choices << { name: "❌ Cancel", value: :cancel }

    choice = @prompt.select("Select tool to duplicate:", choices, per_page: 15)
    return if choice == :cancel

    original_name = tool_files.find { |t| t[:filepath] == choice }[:name]

    new_name = @prompt.ask("Enter new name:") do |q|
      q.default "#{original_name} Copy"
      q.required true
    end

    begin
      tool_data = JSON.parse(File.read(choice), symbolize_names: true)
      tool_data[:name] = new_name
      tool_data[:created_at] = Time.now.iso8601
      tool_data[:updated_at] = Time.now.iso8601

      filename = new_name.downcase.gsub(/[^a-z0-9_]/, '_') + '.json'
      new_filepath = File.join(@tools_dir, filename)

      File.write(new_filepath, JSON.pretty_generate(tool_data))
      puts @pastel.green("✅ Tool duplicated as '#{new_name}'!")
      @prompt.keypress("Press any key to continue...")

    rescue => e
      puts @pastel.red("❌ Error duplicating tool: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def delete_tool
    tool_files = get_available_tool_files

    if tool_files.empty?
      puts @pastel.red("❌ No cutting tools found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.red("\n🗑️ Delete Cutting Tool")
    puts @pastel.yellow("⚠️  This action cannot be undone!")

    choices = tool_files.map { |t| { name: t[:name], value: t[:filepath] } }
    choices << { name: "❌ Cancel", value: :cancel }

    choice = @prompt.select("Select tool to delete:", choices, per_page: 15)
    return if choice == :cancel

    tool_name = tool_files.find { |t| t[:filepath] == choice }[:name]

    confirm = @prompt.yes?("Are you sure you want to delete '#{tool_name}'?")
    return unless confirm

    begin
      File.delete(choice)

      # Clear current tool if it was deleted
      if @current_tool && @current_tool[:name] == tool_name
        @current_tool = nil
      end

      puts @pastel.green("✅ Tool '#{tool_name}' deleted!")
      @prompt.keypress("Press any key to continue...")

    rescue => e
      puts @pastel.red("❌ Error deleting tool: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def list_all_tools
    tool_files = get_available_tool_files

    if tool_files.empty?
      puts @pastel.red("❌ No cutting tools found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📋 All Cutting Tools")
    puts "=" * 80

    tool_files.each_with_index do |tool_file, index|
      info = get_tool_info(tool_file[:filepath])

      if info
        current_indicator = (@current_tool && @current_tool[:name] == info[:name]) ? @pastel.green(" ← CURRENT") : ""
        puts "#{index + 1}. #{@pastel.bold(info[:name])}#{current_indicator}"
        puts "   #{@pastel.cyan('Type:')} #{info[:tool_type]}"
        puts "   #{@pastel.yellow('Diameter:')} #{info[:diameter]}mm"
        puts "   #{@pastel.green('Material:')} #{info[:material]}"
        puts "   #{@pastel.dim('File:')} #{File.basename(tool_file[:filepath])}"

        if info[:purchase_cost]
          puts "   #{@pastel.magenta('Cost:')} $#{info[:purchase_cost]}"
        end
      else
        puts "#{index + 1}. #{tool_file[:name]} (Error reading file)"
      end
      puts
    end

    @prompt.keypress("Press any key to continue...")
  end

  def export_tool
    tool_files = get_available_tool_files

    if tool_files.empty?
      puts @pastel.red("❌ No cutting tools found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📤 Export Cutting Tool")

    choices = tool_files.map { |t| { name: t[:name], value: t[:filepath] } }
    choices << { name: "❌ Cancel", value: :cancel }

    choice = @prompt.select("Select tool to export:", choices, per_page: 15)
    return if choice == :cancel

    tool_name = tool_files.find { |t| t[:filepath] == choice }[:name]
    export_path = @prompt.ask("Export path:", default: "#{tool_name}.json")

    begin
      FileUtils.cp(choice, export_path)
      puts @pastel.green("✅ Tool exported to #{export_path}")
      @prompt.keypress("Press any key to continue...")
    rescue => e
      puts @pastel.red("❌ Error exporting tool: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def import_tool
    puts @pastel.bold.cyan("\n📥 Import Cutting Tool")

    import_path = @prompt.ask("Enter path to tool file:")

    unless File.exist?(import_path)
      puts @pastel.red("❌ File not found: #{import_path}")
      return
    end

    begin
      tool_data = JSON.parse(File.read(import_path), symbolize_names: true)

      unless tool_data[:properties]
        puts @pastel.red("❌ Invalid tool file format")
        return
      end

      tool_name = tool_data[:name] || File.basename(import_path, '.json')
      new_name = @prompt.ask("Tool name:", default: tool_name)

      filename = new_name.downcase.gsub(/[^a-z0-9_]/, '_') + '.json'
      new_filepath = File.join(@tools_dir, filename)

      if File.exist?(new_filepath)
        overwrite = @prompt.yes?("Tool '#{new_name}' already exists. Overwrite?")
        return unless overwrite
      end

      tool_data[:name] = new_name
      tool_data[:updated_at] = Time.now.iso8601

      File.write(new_filepath, JSON.pretty_generate(tool_data))
      puts @pastel.green("✅ Tool imported as '#{new_name}'!")
      @prompt.keypress("Press any key to continue...")

    rescue JSON::ParserError => e
      puts @pastel.red("❌ Error parsing tool file: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    rescue => e
      puts @pastel.red("❌ Error importing tool: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def save_current_tool
    return unless @current_tool

    filename = @current_tool[:name].downcase.gsub(/[^a-z0-9_]/, '_') + '.json'
    filepath = File.join(@tools_dir, filename)
    File.write(filepath, JSON.pretty_generate(@current_tool))
  end

  def get_available_tool_files
    Dir.glob(File.join(@tools_dir, '*.json')).map do |filepath|
      {
        name: File.basename(filepath, '.json').gsub('_', ' ').split.map(&:capitalize).join(' '),
        filepath: filepath
      }
    end.sort_by { |t| t[:name] }
  end

  def get_tool_info(filepath)
    begin
      tool_data = JSON.parse(File.read(filepath), symbolize_names: true)
      props = tool_data[:properties]

      {
        name: tool_data[:name],
        tool_type: tool_data[:tool_type],
        diameter: props[:diameter],
        material: tool_data[:material],
        purchase_cost: props[:purchase_cost]
      }
    rescue
      nil
    end
  end

  def calculate_cost_per_hour(props)
    if props[:purchase_cost] && props[:expected_life_hours]
      "$#{(props[:purchase_cost] / props[:expected_life_hours]).round(2)}/hour"
    else
      "Not calculated"
    end
  end

  def format_date(date_string)
    return "Unknown" unless date_string

    begin
      Time.parse(date_string).strftime("%Y-%m-%d %H:%M")
    rescue
      date_string
    end
  end

  def create_default_tool_files
    # Create some common cutting tools if they don't exist
    default_tools = [
      {
        name: "1/8 Carbide End Mill",
        tool_type: "end_mill",
        material: "carbide",
        manufacturer: "Generic",
        suitable_materials: ["Plywood", "MDF", "Acrylic", "Hardwood"],
        properties: {
          diameter: 3.175,
          length: 25,
          shank_diameter: 3.175,
          flutes: 2,
          recommended_rpm: 18000,
          max_rpm: 24000,
          recommended_feed_rate: 1000,
          recommended_plunge_rate: 300,
          max_depth_of_cut: 1.5,
          operation_type: "profiling"
        }
      },
      {
        name: "60° V-Bit 0.1mm",
        tool_type: "v_bit",
        material: "carbide",
        suitable_materials: ["Plywood", "MDF", "Acrylic", "Hardwood"],
        properties: {
          diameter: 0.1,
          length: 20,
          shank_diameter: 3.175,
          flutes: 2,
          recommended_rpm: 20000,
          max_rpm: 25000,
          recommended_feed_rate: 600,
          recommended_plunge_rate: 200,
          max_depth_of_cut: 0.5,
          operation_type: "v_carving"
        }
      },
      {
        name: "1/4 Spiral Up-Cut",
        tool_type: "spiral_bit",
        material: "carbide",
        suitable_materials: ["Plywood", "MDF", "Hardwood", "Softwood"],
        properties: {
          diameter: 6.35,
          length: 32,
          shank_diameter: 6.35,
          flutes: 2,
          recommended_rpm: 16000,
          max_rpm: 20000,
          recommended_feed_rate: 2000,
          recommended_plunge_rate: 500,
          max_depth_of_cut: 3.0,
          operation_type: "pocketing"
        }
      }
    ]

    default_tools.each do |tool|
      filename = tool[:name].downcase.gsub(/[^a-z0-9_]/, '_') + '.json'
      filepath = File.join(@tools_dir, filename)

      next if File.exist?(filepath)

      tool_data = {
        name: tool[:name],
        tool_type: tool[:tool_type],
        material: tool[:material],
        manufacturer: tool[:manufacturer],
        suitable_materials: tool[:suitable_materials],
        created_at: Time.now.iso8601,
        updated_at: Time.now.iso8601,
        properties: tool[:properties],
        notes: "Default cutting tool"
      }

      File.write(filepath, JSON.pretty_generate(tool_data))
    end
  end

  def clear_screen
    system('clear') || system('cls') || print("\e[2J\e[H")
  end
end
