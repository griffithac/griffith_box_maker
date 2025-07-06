#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'time'

class ProjectManager
  def initialize(options, prompt, pastel)
    @options = options
    @prompt = prompt
    @pastel = pastel
    @projects_dir = File.join(Dir.pwd, 'projects')
    @current_project_file = nil
    @current_project_name = nil
    @stock_manager = nil
    @tool_manager = nil

    # Ensure projects directory exists
    FileUtils.mkdir_p(@projects_dir)
  end

  def run
    loop do
      clear_screen
      show_project_menu
      choice = get_menu_choice

      case choice
      when :save_current
        save_current_project
      when :save_as
        save_project_as
      when :load_project
        load_project
      when :load_stock
        load_stock_into_project
      when :load_tool
        load_tool_into_project
      when :list_projects
        list_projects
      when :delete_project
        delete_project
      when :duplicate_project
        duplicate_project
      when :export_project
        export_project
      when :import_project
        import_project
      when :return
        break
      end
    end
  end

  def set_stock_manager(stock_manager)
    @stock_manager = stock_manager
  end

  def set_tool_manager(tool_manager)
    @tool_manager = tool_manager
  end

  def get_options
    @options
  end

  private

  def show_project_menu
    puts @pastel.bold.blue("\n💾 Project Manager")
    puts "=" * 60

    if @current_project_name
      puts @pastel.green("📁 Current Project: #{@current_project_name}")
      puts @pastel.dim("   File: #{@current_project_file}")
    else
      puts @pastel.dim("📁 No project loaded")
    end

    puts
    puts @pastel.bold("Box Configuration:")
    puts "  #{@pastel.cyan('Dimensions:')} #{@options[:box_length]}×#{@options[:box_width]}×#{@options[:box_height]}mm"
    puts "  #{@pastel.yellow('Material:')} #{@options[:stock_thickness]}mm thick"
    puts "  #{@pastel.green('Features:')} #{get_features_summary}"
    puts
  end

  def get_menu_choice
    @prompt.select("What would you like to do?") do |menu|
      menu.choice "💾 (S)ave Current Project", :save_current, key: "s"
      menu.choice "📝 (A)s... Save with new name", :save_as, key: "a"
      menu.choice "📂 (L)oad Project", :load_project, key: "l"
      menu.choice "📦 (M)aterial - Load stock into project", :load_stock, key: "m"
      menu.choice "🔧 (T)ool - Load tool into project", :load_tool, key: "t"
      menu.choice "📋 (V)iew All Projects", :list_projects, key: "v"
      menu.choice "🗑️ (D)elete Project", :delete_project, key: "d"
      menu.choice "📄 (C)opy Project", :duplicate_project, key: "c"
      menu.choice "📤 (E)xport Project", :export_project, key: "e"
      menu.choice "📥 (I)mport Project", :import_project, key: "i"
      menu.choice "🔙 (R)eturn to Main Menu", :return, key: "r"
    end
  end

  def save_current_project
    if @current_project_name
      save_project(@current_project_name, @current_project_file)
      puts @pastel.green("✅ Project '#{@current_project_name}' saved successfully!")
    else
      save_project_as
    end
  end

  def save_project_as
    puts @pastel.bold.cyan("\n📝 Save Project As")

    name = @prompt.ask("Enter project name:") do |q|
      q.required true
      q.validate /^[a-zA-Z0-9_\-\s]+$/
      q.messages[:valid?] = "Project name can only contain letters, numbers, spaces, underscores, and hyphens"
    end

    # Clean the name for filename
    filename = name.gsub(/[^a-zA-Z0-9_\-]/, '_').gsub(/_+/, '_') + '.json'
    filepath = File.join(@projects_dir, filename)

    if File.exist?(filepath)
      overwrite = @prompt.yes?("Project '#{name}' already exists. Overwrite?")
      return unless overwrite
    end

    save_project(name, filepath)
    @current_project_name = name
    @current_project_file = filepath

    puts @pastel.green("✅ Project '#{name}' saved successfully!")
    @prompt.keypress("Press any key to continue...")
  end

  def save_project(name, filepath)
    project_data = {
      name: name,
      created_at: Time.now.iso8601,
      updated_at: Time.now.iso8601,
      version: "1.0",
      description: generate_project_description,
      configuration: @options.dup,
      metadata: {
        box_volume: calculate_box_volume,
        estimated_panels: count_estimated_panels,
        estimated_material_area: calculate_estimated_material_area
      }
    }

    # Add current stock information if available
    if @stock_manager && @stock_manager.get_current_stock
      project_data[:stock] = @stock_manager.get_current_stock
    end

    # Add current tool information if available
    if @tool_manager && @tool_manager.get_current_tool
      project_data[:tool] = @tool_manager.get_current_tool
    end

    File.write(filepath, JSON.pretty_generate(project_data))
  end

  def load_project
    projects = get_available_projects

    if projects.empty?
      puts @pastel.red("❌ No projects found in #{@projects_dir}")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📂 Load Project")

    choices = projects.map do |project|
      info = get_project_info(project[:filepath])
      description = info ? "#{info[:dimensions]} - #{info[:description]}" : "Unknown"
      ["#{project[:name]} - #{description}", project[:filepath]]
    end

    choices << ["❌ Cancel", :cancel]

    choice = @prompt.select("Select a project to load:", choices)

    return if choice == :cancel

    load_project_file(choice)
  end

  def load_project_file(filepath)
    begin
      project_data = JSON.parse(File.read(filepath), symbolize_names: true)

      # Validate project structure
      unless project_data[:configuration]
        puts @pastel.red("❌ Invalid project file format")
        return
      end

      # Load configuration
      @options.merge!(project_data[:configuration])
      @current_project_name = project_data[:name]
      @current_project_file = filepath

      # Load stock material if available and managers are present
      if project_data[:stock] && @stock_manager
        stock_name = project_data[:stock][:name]
        if @stock_manager.load_stock_by_name(stock_name)
          @stock_manager.apply_stock_to_options(@options)
          puts @pastel.green("✅ Loaded stock material: #{stock_name}")
        else
          puts @pastel.yellow("⚠️  Stock material '#{stock_name}' not found, using project settings")
        end
      end

      # Load cutting tool if available and managers are present
      if project_data[:tool] && @tool_manager
        tool_name = project_data[:tool][:name]
        if @tool_manager.load_tool_by_name(tool_name)
          @tool_manager.apply_tool_to_options(@options)
          puts @pastel.green("✅ Loaded cutting tool: #{tool_name}")
        else
          puts @pastel.yellow("⚠️  Cutting tool '#{tool_name}' not found, using project settings")
        end
      end

      # Update timestamp
      project_data[:updated_at] = Time.now.iso8601
      File.write(filepath, JSON.pretty_generate(project_data))

      puts @pastel.green("✅ Project '#{@current_project_name}' loaded successfully!")

      # Show project summary
      show_project_summary(project_data)
      @prompt.keypress("Press any key to continue...")

    rescue JSON::ParserError => e
      puts @pastel.red("❌ Error parsing project file: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    rescue => e
      puts @pastel.red("❌ Error loading project: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def list_projects
    projects = get_available_projects

    if projects.empty?
      puts @pastel.red("❌ No projects found in #{@projects_dir}")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📋 All Projects")
    puts "=" * 60

    projects.each_with_index do |project, index|
      info = get_project_info(project[:filepath])

      puts "#{index + 1}. #{@pastel.bold(project[:name])}"
      if info
        puts "   #{@pastel.dim('Created:')} #{info[:created_at]}"
        puts "   #{@pastel.dim('Updated:')} #{info[:updated_at]}"
        puts "   #{@pastel.cyan('Box:')} #{info[:dimensions]}"
        puts "   #{@pastel.yellow('Material:')} #{info[:material]}"
        puts "   #{@pastel.green('Features:')} #{info[:features]}"
        puts "   #{@pastel.dim('File:')} #{File.basename(project[:filepath])}"
      else
        puts "   #{@pastel.red('Error: Unable to read project file')}"
      end
      puts
    end

    @prompt.keypress("Press any key to continue...")
  end

  def delete_project
    projects = get_available_projects

    if projects.empty?
      puts @pastel.red("❌ No projects found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.red("\n🗑️ Delete Project")
    puts @pastel.yellow("⚠️  This action cannot be undone!")

    choices = projects.map { |p| [p[:name], p[:filepath]] }
    choices << ["❌ Cancel", :cancel]

    choice = @prompt.select("Select a project to delete:", choices)

    return if choice == :cancel

    project_name = projects.find { |p| p[:filepath] == choice }[:name]

    confirm = @prompt.yes?("Are you sure you want to delete '#{project_name}'?")
    return unless confirm

    begin
      File.delete(choice)

      # Clear current project if it was deleted
      if @current_project_file == choice
        @current_project_file = nil
        @current_project_name = nil
      end

      puts @pastel.green("✅ Project '#{project_name}' deleted successfully!")
      @prompt.keypress("Press any key to continue...")
    rescue => e
      puts @pastel.red("❌ Error deleting project: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def duplicate_project
    projects = get_available_projects

    if projects.empty?
      puts @pastel.red("❌ No projects found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📄 Duplicate Project")

    choices = projects.map { |p| [p[:name], p[:filepath]] }
    choices << ["❌ Cancel", :cancel]

    choice = @prompt.select("Select a project to duplicate:", choices)

    return if choice == :cancel

    original_name = projects.find { |p| p[:filepath] == choice }[:name]

    new_name = @prompt.ask("Enter new project name:") do |q|
      q.default "#{original_name} Copy"
      q.required true
      q.validate /^[a-zA-Z0-9_\-\s]+$/
    end

    begin
      # Read original project
      project_data = JSON.parse(File.read(choice), symbolize_names: true)

      # Update project info
      project_data[:name] = new_name
      project_data[:created_at] = Time.now.iso8601
      project_data[:updated_at] = Time.now.iso8601

      # Create new filename
      filename = new_name.gsub(/[^a-zA-Z0-9_\-]/, '_').gsub(/_+/, '_') + '.json'
      new_filepath = File.join(@projects_dir, filename)

      if File.exist?(new_filepath)
        overwrite = @prompt.yes?("Project '#{new_name}' already exists. Overwrite?")
        return unless overwrite
      end

      File.write(new_filepath, JSON.pretty_generate(project_data))

      puts @pastel.green("✅ Project duplicated as '#{new_name}'!")
      @prompt.keypress("Press any key to continue...")

    rescue => e
      puts @pastel.red("❌ Error duplicating project: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def export_project
    projects = get_available_projects

    if projects.empty?
      puts @pastel.red("❌ No projects found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📤 Export Project")

    choices = projects.map { |p| [p[:name], p[:filepath]] }
    choices << ["❌ Cancel", :cancel]

    choice = @prompt.select("Select a project to export:", choices)

    return if choice == :cancel

    project_name = projects.find { |p| p[:filepath] == choice }[:name]

    export_path = @prompt.ask("Enter export path:", default: "#{project_name}.json")

    begin
      FileUtils.cp(choice, export_path)
      puts @pastel.green("✅ Project exported to #{export_path}")
      @prompt.keypress("Press any key to continue...")
    rescue => e
      puts @pastel.red("❌ Error exporting project: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def import_project
    puts @pastel.bold.cyan("\n📥 Import Project")

    import_path = @prompt.ask("Enter path to project file:")

    unless File.exist?(import_path)
      puts @pastel.red("❌ File not found: #{import_path}")
      return
    end

    begin
      project_data = JSON.parse(File.read(import_path), symbolize_names: true)

      unless project_data[:configuration]
        puts @pastel.red("❌ Invalid project file format")
        return
      end

      project_name = project_data[:name] || File.basename(import_path, '.json')

      # Ask for new name if desired
      new_name = @prompt.ask("Project name:", default: project_name)

      filename = new_name.gsub(/[^a-zA-Z0-9_\-]/, '_').gsub(/_+/, '_') + '.json'
      new_filepath = File.join(@projects_dir, filename)

      if File.exist?(new_filepath)
        overwrite = @prompt.yes?("Project '#{new_name}' already exists. Overwrite?")
        return unless overwrite
      end

      project_data[:name] = new_name
      project_data[:updated_at] = Time.now.iso8601

      File.write(new_filepath, JSON.pretty_generate(project_data))

      puts @pastel.green("✅ Project imported as '#{new_name}'!")
      @prompt.keypress("Press any key to continue...")

    rescue JSON::ParserError => e
      puts @pastel.red("❌ Error parsing project file: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    rescue => e
      puts @pastel.red("❌ Error importing project: #{e.message}")
      @prompt.keypress("Press any key to continue...")
    end
  end

  def get_available_projects
    Dir.glob(File.join(@projects_dir, '*.json')).map do |filepath|
      {
        name: File.basename(filepath, '.json').gsub('_', ' '),
        filepath: filepath
      }
    end.sort_by { |p| p[:name] }
  end

  def get_project_info(filepath)
    begin
      project_data = JSON.parse(File.read(filepath), symbolize_names: true)
      config = project_data[:configuration]

      {
        name: project_data[:name],
        created_at: format_date(project_data[:created_at]),
        updated_at: format_date(project_data[:updated_at]),
        dimensions: "#{config[:box_length]}×#{config[:box_width]}×#{config[:box_height]}mm",
        material: "#{config[:stock_thickness]}mm thick",
        features: get_features_summary(config),
        description: project_data[:description] || "No description"
      }
    rescue
      nil
    end
  end

  def show_project_summary(project_data)
    puts @pastel.bold("\n📊 Project Summary:")
    puts "  #{@pastel.cyan('Name:')} #{project_data[:name]}"
    puts "  #{@pastel.dim('Created:')} #{format_date(project_data[:created_at])}"
    puts "  #{@pastel.dim('Updated:')} #{format_date(project_data[:updated_at])}"

    if project_data[:description]
      puts "  #{@pastel.blue('Description:')} #{project_data[:description]}"
    end

    if project_data[:metadata]
      meta = project_data[:metadata]
      puts "  #{@pastel.green('Volume:')} #{meta[:box_volume]}mm³" if meta[:box_volume]
      puts "  #{@pastel.yellow('Panels:')} #{meta[:estimated_panels]}" if meta[:estimated_panels]
      puts "  #{@pastel.magenta('Material:')} #{meta[:estimated_material_area]}mm²" if meta[:estimated_material_area]
    end
    puts
  end

  def get_features_summary(config = @options)
    features = []
    features << "Lid" if config[:enable_lid]
    features << "Dividers" if config[:enable_dividers]
    features.empty? ? "Basic Box" : features.join(", ")
  end

  def generate_project_description
    "#{@options[:box_length]}×#{@options[:box_width]}×#{@options[:box_height]}mm box with #{get_features_summary}"
  end

  def calculate_box_volume
    (@options[:box_length] * @options[:box_width] * @options[:box_height]).round(2)
  end

  def count_estimated_panels
    count = 5  # Basic box panels
    count += 5 if @options[:enable_lid]
    count += 1 if @options[:enable_dividers] && @options[:enable_x_divider]
    count += 1 if @options[:enable_dividers] && @options[:enable_y_divider]
    count
  end

  def calculate_estimated_material_area
    # Rough estimate - this would be more accurate with actual panel calculations
    basic_area = 2 * (@options[:box_length] * @options[:box_width]) +
                 2 * (@options[:box_length] * @options[:box_height]) +
                 2 * (@options[:box_width] * @options[:box_height])

    if @options[:enable_lid]
      lid_length = @options[:box_length] + 2 * @options[:stock_thickness] + 2 * @options[:lid_tolerance]
      lid_width = @options[:box_width] + 2 * @options[:stock_thickness] + 2 * @options[:lid_tolerance]
      lid_area = 2 * (lid_length * lid_width) +
                 2 * (lid_length * @options[:lid_height]) +
                 2 * (lid_width * @options[:lid_height])
      basic_area += lid_area
    end

    if @options[:enable_dividers]
      basic_area += @options[:box_length] * @options[:box_height] if @options[:enable_x_divider]
      basic_area += @options[:box_width] * @options[:box_height] if @options[:enable_y_divider]
    end

    basic_area.round(2)
  end

  def format_date(date_string)
    return "Unknown" unless date_string

    begin
      Time.parse(date_string).strftime("%Y-%m-%d %H:%M")
    rescue
      date_string
    end
  end

  def load_stock_into_project
    unless @stock_manager
      puts @pastel.red("❌ Stock manager not available")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n📦 Load Stock Material into Project")
    puts "This will load a stock material and apply its properties to the current project."
    puts

    stock_files = Dir.glob(File.join(Dir.pwd, 'stock', '*.json'))

    if stock_files.empty?
      puts @pastel.red("❌ No stock materials found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    choices = stock_files.map do |filepath|
      begin
        stock_data = JSON.parse(File.read(filepath), symbolize_names: true)
        props = stock_data[:properties]
        description = "#{stock_data[:material_type]} - #{props[:width]}×#{props[:height]}×#{props[:thickness]}mm"
        [stock_data[:name], filepath]
      rescue
        [File.basename(filepath, '.json'), filepath]
      end
    end

    choices << ["❌ Cancel", :cancel]

    choice = @prompt.select("Select stock material:", choices)
    return if choice == :cancel

    if @stock_manager.load_stock_file(choice)
      @stock_manager.apply_stock_to_options(@options)
      puts @pastel.green("✅ Stock material loaded and applied to project!")
    end

    @prompt.keypress("Press any key to continue...")
  end

  def load_tool_into_project
    unless @tool_manager
      puts @pastel.red("❌ Tool manager not available")
      @prompt.keypress("Press any key to continue...")
      return
    end

    puts @pastel.bold.cyan("\n🔧 Load Cutting Tool into Project")
    puts "This will load a cutting tool and apply its properties to the current project."
    puts

    tool_files = Dir.glob(File.join(Dir.pwd, 'tools', '*.json'))

    if tool_files.empty?
      puts @pastel.red("❌ No cutting tools found")
      @prompt.keypress("Press any key to continue...")
      return
    end

    choices = tool_files.map do |filepath|
      begin
        tool_data = JSON.parse(File.read(filepath), symbolize_names: true)
        props = tool_data[:properties]
        description = "#{tool_data[:tool_type]} - #{props[:diameter]}mm #{tool_data[:material]}"
        [tool_data[:name], filepath]
      rescue
        [File.basename(filepath, '.json'), filepath]
      end
    end

    choices << ["❌ Cancel", :cancel]

    choice = @prompt.select("Select cutting tool:", choices)
    return if choice == :cancel

    if @tool_manager.load_tool_file(choice)
      @tool_manager.apply_tool_to_options(@options)
      puts @pastel.green("✅ Cutting tool loaded and applied to project!")
    end

    @prompt.keypress("Press any key to continue...")
  end

  def clear_screen
    system('clear') || system('cls') || print("\e[2J\e[H")
  end
end
