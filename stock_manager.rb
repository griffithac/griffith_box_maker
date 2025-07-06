#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'time'

class StockManager
  def initialize(prompt, pastel)
    @prompt = prompt
    @pastel = pastel
    @stock_dir = File.join(Dir.pwd, 'stock')
    @current_stock = nil

    # Ensure stock directory exists
    FileUtils.mkdir_p(@stock_dir)

    # Create default stock files if they don't exist
    create_default_stock_files
  end

  def run
    loop do
      clear_screen
      show_stock_menu
      choice = get_menu_choice

      case choice
      when :view_current
        view_current_stock
      when :load_stock
        load_stock
      when :create_stock
        create_new_stock
      when :edit_stock
        edit_stock
      when :duplicate_stock
        duplicate_stock
      when :delete_stock
        delete_stock
      when :list_all
        list_all_stock
      when :export_stock
        export_stock
      when :import_stock
        import_stock
      when :return
        break
      end
    end
  end

  def get_current_stock
    @current_stock
  end

  def load_stock_by_name(stock_name)
    stock_file = File.join(@stock_dir, "#{stock_name.downcase.gsub(/[^a-z0-9_]/, '_')}.json")

    if File.exist?(stock_file)
      load_stock_file(stock_file)
      return @current_stock
    end

    nil
  end

  def apply_stock_to_options(options)
    return options unless @current_stock

    stock_config = @current_stock[:properties]

    options[:stock_width] = stock_config[:width]
    options[:stock_height] = stock_config[:height]
    options[:stock_thickness] = stock_config[:thickness]
    options[:kerf] = stock_config[:kerf] if stock_config[:kerf]
    options[:bit_diameter] = stock_config[:recommended_bit_diameter] if stock_config[:recommended_bit_diameter]

    options
  end

  private

  def show_stock_menu
    puts @pastel.bold.green("\n📦 Stock Material Manager")
    puts "=" * 60

    if @current_stock
      puts @pastel.cyan("📋 Current Stock: #{@current_stock[:name]}")
      puts @pastel.dim("   Material: #{@current_stock[:material_type]}")
      puts @pastel.dim("   Size: #{@current_stock[:properties][:width]}×#{@current_stock[:properties][:height]}×#{@current_stock[:properties][:thickness]}mm")
      puts @pastel.dim("   Kerf: #{@current_stock[:properties][:kerf]}mm")
    else
      puts @pastel.dim("📋 No stock selected")
    end
    puts
  end

  def get_menu_choice
    @prompt.select("What would you like to do?", per_page: 15) do |menu|
      menu.choice "👁️ (V)iew Current Stock Details", :view_current, key: "v"
      menu.choice "📂 (L)oad Stock Material", :load_stock, key: "l"
      menu.choice "➕ (C)reate New Stock", :create_stock, key: "c"
      menu.choice "✏️ (E)dit Stock", :edit_stock, key: "e"
      menu.choice "📄 (D)uplicate Stock", :duplicate_stock, key: "d"
      menu.choice "🗑️ Delete Stock", :delete_stock, key: "x"
      menu.choice "📋 (A)ll Stock Materials", :list_all, key: "a"
      menu.choice "📤 E(x)port Stock", :export_stock, key: "p"
      menu.choice "📥 (I)mport Stock", :import_stock, key: "i"
      menu.choice "🔙 (R)eturn to Main Menu", :return, key: "r"
    end
  end

  def view_current_stock
    unless @current_stock
      puts @pastel.red("❌ No stock material selected")
      @prompt.keypress("Press any key to continue...")
      return
    end

    stock = @current_stock
    props = stock[:properties]

    puts @pastel.bold.cyan("\n📋 Stock Material Details")
    puts "=" * 50

    puts "#{@pastel.bold('Name:')} #{stock[:name]}"
    puts "#{@pastel.bold('Material:')} #{stock[:material_type]}"
    puts "#{@pastel.bold('Supplier:')} #{stock[:supplier] || 'Unknown'}"
    puts

    puts @pastel.bold("📐 Dimensions:")
    puts "  Width: #{props[:width]}mm"
    puts "  Height: #{props[:height]}mm"
    puts "  Thickness: #{props[:thickness]}mm"
    puts "  Area: #{(props[:width] * props[:height] / 1000000.0).round(2)} m²"
    puts

    puts @pastel.bold("⚙️ Cutting Properties:")
    puts "  Kerf: #{props[:kerf]}mm"
    puts "  Recommended Bit: #{props[:recommended_bit_diameter]}mm"
    puts "  Max Feed Rate: #{props[:max_feed_rate] || 'Not specified'}"
    puts

    puts @pastel.bold("💰 Cost Information:")
    puts "  Cost per Sheet: #{props[:cost_per_sheet] ? "$#{props[:cost_per_sheet]}" : 'Not specified'}"
    puts "  Cost per m²: #{props[:cost_per_sqm] ? "$#{props[:cost_per_sqm]}" : 'Not specified'}"
    puts

    if stock[:notes] && !stock[:notes].empty?
      puts @pastel.bold("📝 Notes:")
      puts "  #{stock[:notes]}"
      puts
    end

    puts @pastel.dim("Created: #{format_date(stock[:created_at])}")
    puts @pastel.dim("Updated: #{format_date(stock[:updated_at])}")

    @prompt.keypress("Press any key to continue...")
  end

  def load_stock
    stock_files = get_available_stock_files

    if stock_files.empty?
      puts @pastel.red("❌ No stock materials found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📂 Load Stock Material")

    choices = stock_files.map do |stock_file|
      info = get_stock_info(stock_file[:filepath])
      if info
        description = "#{info[:material_type]} - #{info[:dimensions]} - #{info[:kerf]}mm kerf"
        { name: "#{info[:name]} (#{description})", value: stock_file[:filepath] }
      else
        { name: stock_file[:name], value: stock_file[:filepath] }
      end
    end

    choices << { name: "❌ Cancel", value: :cancel }

    choice = @prompt.select("Select stock material:", choices, per_page: 15)

    return if choice == :cancel

    load_stock_file(choice)
  end

  def load_stock_file(filepath)
    begin
      stock_data = JSON.parse(File.read(filepath), symbolize_names: true)

      # Validate stock structure
      unless stock_data[:properties] && stock_data[:properties][:width]
        puts @pastel.red("❌ Invalid stock file format")
        return false
      end

      @current_stock = stock_data

      # Update timestamp
      @current_stock[:updated_at] = Time.now.iso8601
      File.write(filepath, JSON.pretty_generate(@current_stock))

      puts @pastel.green("✅ Stock material '#{@current_stock[:name]}' loaded successfully!")
      @prompt.keypress("Press any key to continue...")
      return true

    rescue JSON::ParserError => e
      puts @pastel.red("❌ Error parsing stock file: #{e.message}")
      @prompt.keypress("Press any key to continue...")
      return false
    rescue => e
      puts @pastel.red("❌ Error loading stock: #{e.message}")
      @prompt.keypress("Press any key to continue...")
      return false
    end
  end

  def create_new_stock
    puts @pastel.bold.cyan("\n➕ Create New Stock Material")

    # Basic information
    name = @prompt.ask("Stock name:") do |q|
      q.required true
      q.validate /^[a-zA-Z0-9_\-\s]+$/
      q.messages[:valid?] = "Name can only contain letters, numbers, spaces, underscores, and hyphens"
    end

    material_type = @prompt.select("Material type:") do |menu|
      menu.choice "Plywood", "plywood"
      menu.choice "MDF", "mdf"
      menu.choice "Acrylic", "acrylic"
      menu.choice "Hardboard", "hardboard"
      menu.choice "Aluminum", "aluminum"
      menu.choice "Cardboard", "cardboard"
      menu.choice "Other", "other"
    end

    if material_type == "other"
      material_type = @prompt.ask("Specify material type:")
    end

    # Dimensions
    puts "\n📐 Dimensions:"
    width = @prompt.ask("Width (mm):", convert: :float)
    height = @prompt.ask("Height (mm):", convert: :float)
    thickness = @prompt.ask("Thickness (mm):", convert: :float)

    # Cutting properties
    puts "\n⚙️ Cutting Properties:"
    kerf = @prompt.ask("Kerf (mm):", default: get_default_kerf(material_type), convert: :float)
    bit_diameter = @prompt.ask("Recommended bit diameter (mm):", default: 3.175, convert: :float)

    # Optional properties
    puts "\n💰 Optional Information:"
    supplier = @prompt.ask("Supplier (optional):")
    cost_per_sheet = @prompt.ask("Cost per sheet (optional, no $ sign):", convert: :float) rescue nil
    max_feed_rate = @prompt.ask("Max feed rate (optional):")
    notes = @prompt.ask("Notes (optional):")

    # Calculate cost per m²
    cost_per_sqm = nil
    if cost_per_sheet
      area_sqm = width * height / 1000000.0
      cost_per_sqm = (cost_per_sheet / area_sqm).round(2)
    end

    stock_data = {
      name: name,
      material_type: material_type,
      supplier: supplier.empty? ? nil : supplier,
      created_at: Time.now.iso8601,
      updated_at: Time.now.iso8601,
      properties: {
        width: width,
        height: height,
        thickness: thickness,
        kerf: kerf,
        recommended_bit_diameter: bit_diameter,
        max_feed_rate: max_feed_rate.empty? ? nil : max_feed_rate,
        cost_per_sheet: cost_per_sheet,
        cost_per_sqm: cost_per_sqm
      },
      notes: notes.empty? ? nil : notes
    }

    # Save stock
    filename = name.downcase.gsub(/[^a-z0-9_]/, '_') + '.json'
    filepath = File.join(@stock_dir, filename)

    if File.exist?(filepath)
      overwrite = @prompt.yes?("Stock '#{name}' already exists. Overwrite?")
      return unless overwrite
    end

    File.write(filepath, JSON.pretty_generate(stock_data))
    @current_stock = stock_data

    puts @pastel.green("✅ Stock material '#{name}' created and loaded!")
    @prompt.keypress("Press any key to continue...")
  end

  def edit_stock
    unless @current_stock
      puts @pastel.red("❌ No stock material selected. Load a stock material first.")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.yellow("\n✏️ Edit Stock Material: #{@current_stock[:name]}")

    choice = @prompt.select("What would you like to edit?") do |menu|
      menu.choice "📝 Name", :name
      menu.choice "🔧 Material Type", :material_type
      menu.choice "📐 Dimensions", :dimensions
      menu.choice "⚙️ Cutting Properties", :cutting
      menu.choice "💰 Cost Information", :cost
      menu.choice "🏪 Supplier", :supplier
      menu.choice "📝 Notes", :notes
      menu.choice "❌ Cancel", :cancel
    end

    return if choice == :cancel

    case choice
    when :name
      new_name = @prompt.ask("New name:", default: @current_stock[:name])
      @current_stock[:name] = new_name
    when :material_type
      @current_stock[:material_type] = @prompt.select("Material type:",
        ["plywood", "mdf", "acrylic", "hardboard", "aluminum", "cardboard", "other"])
    when :dimensions
      props = @current_stock[:properties]
      props[:width] = @prompt.ask("Width (mm):", default: props[:width], convert: :float)
      props[:height] = @prompt.ask("Height (mm):", default: props[:height], convert: :float)
      props[:thickness] = @prompt.ask("Thickness (mm):", default: props[:thickness], convert: :float)
    when :cutting
      props = @current_stock[:properties]
      props[:kerf] = @prompt.ask("Kerf (mm):", default: props[:kerf], convert: :float)
      props[:recommended_bit_diameter] = @prompt.ask("Bit diameter (mm):", default: props[:recommended_bit_diameter], convert: :float)
      props[:max_feed_rate] = @prompt.ask("Max feed rate:", default: props[:max_feed_rate] || "")
    when :cost
      props = @current_stock[:properties]
      props[:cost_per_sheet] = @prompt.ask("Cost per sheet:", default: props[:cost_per_sheet], convert: :float) rescue nil
      if props[:cost_per_sheet]
        area_sqm = props[:width] * props[:height] / 1000000.0
        props[:cost_per_sqm] = (props[:cost_per_sheet] / area_sqm).round(2)
      end
    when :supplier
      @current_stock[:supplier] = @prompt.ask("Supplier:", default: @current_stock[:supplier] || "")
    when :notes
      @current_stock[:notes] = @prompt.ask("Notes:", default: @current_stock[:notes] || "")
    end

    @current_stock[:updated_at] = Time.now.iso8601
    save_current_stock
    puts @pastel.green("✅ Stock material updated!")
    @prompt.keypress("Press any key to continue...")
  end

  def duplicate_stock
    stock_files = get_available_stock_files

    if stock_files.empty?
      puts @pastel.red("❌ No stock materials found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📄 Duplicate Stock Material")

    choices = stock_files.map { |s| { name: s[:name], value: s[:filepath] } }
    choices << { name: "❌ Cancel", value: :cancel }

    choice = @prompt.select("Select stock to duplicate:", choices, per_page: 15)
    return if choice == :cancel

    original_name = stock_files.find { |s| s[:filepath] == choice }[:name]

    new_name = @prompt.ask("Enter new name:") do |q|
      q.default "#{original_name} Copy"
      q.required true
    end

    begin
      stock_data = JSON.parse(File.read(choice), symbolize_names: true)
      stock_data[:name] = new_name
      stock_data[:created_at] = Time.now.iso8601
      stock_data[:updated_at] = Time.now.iso8601

      filename = new_name.downcase.gsub(/[^a-z0-9_]/, '_') + '.json'
      new_filepath = File.join(@stock_dir, filename)

      File.write(new_filepath, JSON.pretty_generate(stock_data))
      puts @pastel.green("✅ Stock duplicated as '#{new_name}'!")
      @prompt.keypress("Press any key to continue...")

    rescue => e
      puts @pastel.red("❌ Error duplicating stock: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def delete_stock
    stock_files = get_available_stock_files

    if stock_files.empty?
      puts @pastel.red("❌ No stock materials found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.red("\n🗑️ Delete Stock Material")
    puts @pastel.yellow("⚠️  This action cannot be undone!")

    choices = stock_files.map { |s| { name: s[:name], value: s[:filepath] } }
    choices << { name: "❌ Cancel", value: :cancel }

    choice = @prompt.select("Select stock to delete:", choices, per_page: 15)
    return if choice == :cancel

    stock_name = stock_files.find { |s| s[:filepath] == choice }[:name]

    confirm = @prompt.yes?("Are you sure you want to delete '#{stock_name}'?")
    return unless confirm

    begin
      File.delete(choice)

      # Clear current stock if it was deleted
      if @current_stock && @current_stock[:name] == stock_name
        @current_stock = nil
      end

      puts @pastel.green("✅ Stock '#{stock_name}' deleted!")
      @prompt.keypress("Press any key to continue...")

    rescue => e
      puts @pastel.red("❌ Error deleting stock: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def list_all_stock
    stock_files = get_available_stock_files

    if stock_files.empty?
      puts @pastel.red("❌ No stock materials found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📋 All Stock Materials")
    puts "=" * 80

    stock_files.each_with_index do |stock_file, index|
      info = get_stock_info(stock_file[:filepath])

      if info
        current_indicator = (@current_stock && @current_stock[:name] == info[:name]) ? @pastel.green(" ← CURRENT") : ""
        puts "#{index + 1}. #{@pastel.bold(info[:name])}#{current_indicator}"
        puts "   #{@pastel.cyan('Material:')} #{info[:material_type]}"
        puts "   #{@pastel.yellow('Size:')} #{info[:dimensions]}"
        puts "   #{@pastel.green('Kerf:')} #{info[:kerf]}mm"
        puts "   #{@pastel.dim('File:')} #{File.basename(stock_file[:filepath])}"

        if info[:cost_per_sheet]
          puts "   #{@pastel.magenta('Cost:')} $#{info[:cost_per_sheet]}/sheet"
        end
      else
        puts "#{index + 1}. #{stock_file[:name]} (Error reading file)"
      end
      puts
    end

    @prompt.keypress("Press any key to continue...")
  end

  def export_stock
    stock_files = get_available_stock_files

    if stock_files.empty?
      puts @pastel.red("❌ No stock materials found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📤 Export Stock Material")

    choices = stock_files.map { |s| { name: s[:name], value: s[:filepath] } }
    choices << { name: "❌ Cancel", value: :cancel }

    choice = @prompt.select("Select stock to export:", choices, per_page: 15)
    return if choice == :cancel

    stock_name = stock_files.find { |s| s[:filepath] == choice }[:name]
    export_path = @prompt.ask("Export path:", default: "#{stock_name}.json")

    begin
      FileUtils.cp(choice, export_path)
      puts @pastel.green("✅ Stock exported to #{export_path}")
      @prompt.keypress("Press any key to continue...")
    rescue => e
      puts @pastel.red("❌ Error exporting stock: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def import_stock
    puts @pastel.bold.cyan("\n📥 Import Stock Material")

    import_path = @prompt.ask("Enter path to stock file:")

    unless File.exist?(import_path)
      puts @pastel.red("❌ File not found: #{import_path}")
      return
    end

    begin
      stock_data = JSON.parse(File.read(import_path), symbolize_names: true)

      unless stock_data[:properties]
        puts @pastel.red("❌ Invalid stock file format")
        return
      end

      stock_name = stock_data[:name] || File.basename(import_path, '.json')
      new_name = @prompt.ask("Stock name:", default: stock_name)

      filename = new_name.downcase.gsub(/[^a-z0-9_]/, '_') + '.json'
      new_filepath = File.join(@stock_dir, filename)

      if File.exist?(new_filepath)
        overwrite = @prompt.yes?("Stock '#{new_name}' already exists. Overwrite?")
        return unless overwrite
      end

      stock_data[:name] = new_name
      stock_data[:updated_at] = Time.now.iso8601

      File.write(new_filepath, JSON.pretty_generate(stock_data))
      puts @pastel.green("✅ Stock imported as '#{new_name}'!")
      @prompt.keypress("Press any key to continue...")

    rescue JSON::ParserError => e
      puts @pastel.red("❌ Error parsing stock file: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    rescue => e
      puts @pastel.red("❌ Error importing stock: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def save_current_stock
    return unless @current_stock

    filename = @current_stock[:name].downcase.gsub(/[^a-z0-9_]/, '_') + '.json'
    filepath = File.join(@stock_dir, filename)
    File.write(filepath, JSON.pretty_generate(@current_stock))
  end

  def get_available_stock_files
    Dir.glob(File.join(@stock_dir, '*.json')).map do |filepath|
      {
        name: File.basename(filepath, '.json').gsub('_', ' ').split.map(&:capitalize).join(' '),
        filepath: filepath
      }
    end.sort_by { |s| s[:name] }
  end

  def get_stock_info(filepath)
    begin
      stock_data = JSON.parse(File.read(filepath), symbolize_names: true)
      props = stock_data[:properties]

      {
        name: stock_data[:name],
        material_type: stock_data[:material_type],
        dimensions: "#{props[:width]}×#{props[:height]}×#{props[:thickness]}mm",
        kerf: props[:kerf],
        cost_per_sheet: props[:cost_per_sheet]
      }
    rescue
      nil
    end
  end

  def get_default_kerf(material_type)
    case material_type.downcase
    when 'plywood', 'mdf', 'hardboard'
      0.3
    when 'acrylic'
      0.1
    when 'aluminum'
      0.2
    when 'cardboard'
      0.1
    else
      0.3
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

  def create_default_stock_files
    # Create some common stock materials if they don't exist
    default_stocks = [
      {
        name: "4x8 Plywood 12mm",
        material_type: "plywood",
        supplier: "Home Depot",
        properties: {
          width: 1220,
          height: 2440,
          thickness: 12,
          kerf: 0.3,
          recommended_bit_diameter: 3.175,
          cost_per_sheet: 45.00,
          cost_per_sqm: 15.1
        }
      },
      {
        name: "4x4 MDF 6mm",
        material_type: "mdf",
        properties: {
          width: 1220,
          height: 1220,
          thickness: 6,
          kerf: 0.3,
          recommended_bit_diameter: 3.175,
          cost_per_sheet: 25.00,
          cost_per_sqm: 16.8
        }
      },
      {
        name: "A1 Acrylic 3mm",
        material_type: "acrylic",
        properties: {
          width: 594,
          height: 841,
          thickness: 3,
          kerf: 0.1,
          recommended_bit_diameter: 1.5,
          cost_per_sheet: 35.00,
          cost_per_sqm: 70.0
        }
      }
    ]

    default_stocks.each do |stock|
      filename = stock[:name].downcase.gsub(/[^a-z0-9_]/, '_') + '.json'
      filepath = File.join(@stock_dir, filename)

      next if File.exist?(filepath)

      stock_data = {
        name: stock[:name],
        material_type: stock[:material_type],
        supplier: stock[:supplier],
        created_at: Time.now.iso8601,
        updated_at: Time.now.iso8601,
        properties: stock[:properties],
        notes: "Default stock material"
      }

      File.write(filepath, JSON.pretty_generate(stock_data))
    end
  end

  def clear_screen
    system('clear') || system('cls') || print("\e[2J\e[H")
  end
end
