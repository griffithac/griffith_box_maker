#!/usr/bin/env ruby

require_relative 'finger_joint_calculator'
require_relative 'svg_generator'

class LayoutOptimizer
  def initialize(options)
    @options = options
    @stock_width = options[:stock_width]
    @stock_height = options[:stock_height]
    @part_spacing = options[:part_spacing]
    @panels = []
  end

  def add_panel(name, width, height, quantity = 1)
    quantity.times do |i|
      panel_name = quantity > 1 ? "#{name}_#{i+1}" : name
      @panels << {
        name: panel_name,
        width: width,
        height: height,
        area: width * height,
        rotated: false,
        placed: false,
        x: 0,
        y: 0
      }
    end
  end

  def calculate_layout
    # Sort panels by area (largest first) for better packing
    @panels.sort_by! { |panel| -panel[:area] }

    # Try to fit all panels on available stock
    sheets = []
    current_sheet = create_new_sheet

    @panels.each do |panel|
      # Try to place panel on current sheet
      placed = try_place_panel(panel, current_sheet)

      unless placed
        # Try rotating the panel
        panel[:width], panel[:height] = panel[:height], panel[:width]
        panel[:rotated] = true
        placed = try_place_panel(panel, current_sheet)

        unless placed
          # Rotate back and try new sheet
          panel[:width], panel[:height] = panel[:height], panel[:width]
          panel[:rotated] = false

          # Create new sheet
          current_sheet = create_new_sheet
          sheets << current_sheet
          placed = try_place_panel(panel, current_sheet)

          unless placed
            # Try rotating on new sheet
            panel[:width], panel[:height] = panel[:height], panel[:width]
            panel[:rotated] = true
            placed = try_place_panel(panel, current_sheet)
          end
        end
      end

      if placed
        current_sheet[:panels] << panel
        panel[:placed] = true
      else
        # Panel won't fit even on new sheet - need custom handling
        puts "⚠️  Warning: Panel #{panel[:name]} (#{panel[:width]}×#{panel[:height]}mm) won't fit on #{@stock_width}×#{@stock_height}mm stock"
      end
    end

    # Add the last sheet if it has panels
    sheets << current_sheet if current_sheet[:panels].any?

    # Calculate efficiency
    sheets.each_with_index do |sheet, index|
      sheet[:efficiency] = calculate_sheet_efficiency(sheet)
      sheet[:number] = index + 1
    end

    {
      sheets: sheets,
      total_sheets: sheets.length,
      total_area_used: sheets.sum { |s| s[:area_used] },
      total_area_available: sheets.length * (@stock_width * @stock_height),
      overall_efficiency: calculate_overall_efficiency(sheets)
    }
  end

  def generate_cutting_layout_svg(layout, output_dir)
    files = []
    layout[:sheets].each do |sheet|
      files << generate_sheet_svg(sheet, output_dir)
    end
    files
  end

  def print_layout_summary(layout)
    puts "\n📊 Layout Optimization Summary:"
    puts "  Total sheets needed: #{layout[:total_sheets]}"
    puts "  Overall efficiency: #{layout[:overall_efficiency]}%"
    puts "  Total area used: #{layout[:total_area_used].round(2)}mm²"
    puts "  Total area available: #{layout[:total_area_available].round(2)}mm²"
    puts "  Waste: #{(layout[:total_area_available] - layout[:total_area_used]).round(2)}mm²"
    puts

    layout[:sheets].each do |sheet|
      puts "  📄 Sheet #{sheet[:number]}: #{sheet[:efficiency]}% efficient (#{sheet[:panels].length} panels)"
      sheet[:panels].each do |panel|
        rotation_indicator = panel[:rotated] ? " ↻" : ""
        puts "    • #{panel[:name]}: #{panel[:width].round(1)}×#{panel[:height].round(1)}mm at (#{panel[:x].round(1)}, #{panel[:y].round(1)})#{rotation_indicator}"
      end
      puts
    end
  end

  def suggest_optimizations(layout)
    suggestions = []

    # Check for low efficiency sheets
    layout[:sheets].each do |sheet|
      if sheet[:efficiency] < 50
        suggestions << "Sheet #{sheet[:number]} has low efficiency (#{sheet[:efficiency]}%). Consider combining with another sheet or adjusting part spacing."
      end
    end

    # Check for panels that don't fit
    unplaced_panels = @panels.select { |p| !p[:placed] }
    if unplaced_panels.any?
      suggestions << "#{unplaced_panels.length} panels don't fit on standard stock. Consider larger stock or splitting panels."
    end

    # Check overall efficiency
    if layout[:overall_efficiency] < 70
      suggestions << "Overall efficiency is #{layout[:overall_efficiency]}%. Consider optimizing panel sizes or stock dimensions."
    end

    unless suggestions.empty?
      puts "\n💡 Optimization Suggestions:"
      suggestions.each { |suggestion| puts "  • #{suggestion}" }
    end
  end

  private

  def create_new_sheet
    {
      width: @stock_width,
      height: @stock_height,
      panels: [],
      area_used: 0,
      efficiency: 0,
      number: 0
    }
  end

  def try_place_panel(panel, sheet)
    # Simple bin packing algorithm - bottom-left fit
    best_x = nil
    best_y = nil
    best_y_pos = Float::INFINITY

    # Try all possible positions starting with half spacing from edges
    half_spacing = @part_spacing / 2.0
    start_x = half_spacing
    start_y = half_spacing
    max_x = @stock_width - panel[:width] - half_spacing
    max_y = @stock_height - panel[:height] - half_spacing

    (start_x.to_i..max_x.to_i).step(@part_spacing) do |x|
      (start_y.to_i..max_y.to_i).step(@part_spacing) do |y|
        if can_place_at(panel, x, y, sheet)
          if y < best_y_pos
            best_x = x
            best_y = y
            best_y_pos = y
          end
        end
      end
    end

    if best_x && best_y
      panel[:x] = best_x
      panel[:y] = best_y
      sheet[:area_used] += panel[:area]
      return true
    end

    false
  end

  def can_place_at(panel, x, y, sheet)
    # Check if panel fits within stock boundaries with half spacing from edges
    half_spacing = @part_spacing / 2.0
    return false if x + panel[:width] + half_spacing > @stock_width
    return false if y + panel[:height] + half_spacing > @stock_height

    # Check for collisions with existing panels
    sheet[:panels].each do |existing|
      # Check if rectangles overlap (with spacing)
      if rectangles_overlap?(
        x, y, panel[:width] + @part_spacing, panel[:height] + @part_spacing,
        existing[:x], existing[:y], existing[:width] + @part_spacing, existing[:height] + @part_spacing
      )
        return false
      end
    end

    true
  end

  def rectangles_overlap?(x1, y1, w1, h1, x2, y2, w2, h2)
    !(x1 + w1 <= x2 || x2 + w2 <= x1 || y1 + h1 <= y2 || y2 + h2 <= y1)
  end

  def calculate_sheet_efficiency(sheet)
    return 0 if sheet[:panels].empty?

    total_sheet_area = @stock_width * @stock_height
    (sheet[:area_used].to_f / total_sheet_area.to_f * 100).round(2)
  end

  def calculate_overall_efficiency(sheets)
    return 0 if sheets.empty?

    total_used = sheets.sum { |s| s[:area_used] }
    total_available = sheets.length * (@stock_width * @stock_height)

    (total_used.to_f / total_available.to_f * 100).round(2)
  end

  def generate_sheet_svg(sheet, output_dir)
    require 'victor'

    filename = File.join(output_dir, "cutting_layout_sheet_#{sheet[:number]}.svg")
    margin = 20

    calculator = FingerJointCalculator.new(@options)
    layouts = calculator.calculate_all_layouts
    generator = SVGGenerator.new(@options, layouts)

    img = Victor::SVG.new width: @stock_width + 2 * margin, height: @stock_height + 2 * margin

    # Draw background
    img.rect x: 0, y: 0, width: @stock_width + 2 * margin, height: @stock_height + 2 * margin,
           fill: "#f8f9fa",
           stroke: "none"

    # Draw grid lines for reference (every 100mm)
    (0..@stock_width.to_i).step(100) do |x|
      img.line x1: x + margin, y1: margin, x2: x + margin, y2: @stock_height + margin,
             stroke: "#e9ecef",
             stroke_width: 0.5
    end
    (0..@stock_height.to_i).step(100) do |y|
      img.line x1: margin, y1: y + margin, x2: @stock_width + margin, y2: y + margin,
             stroke: "#e9ecef",
             stroke_width: 0.5
    end

    # Draw stock outline with thick border
    img.rect x: margin, y: margin, width: @stock_width, height: @stock_height,
           fill: "white",
           stroke: "black",
           stroke_width: 3.0

    # Draw panels with better styling
    sheet[:panels].each_with_index do |panel, index|
      # Panel fill with alternating colors
      panel_color = index.even? ? "#e3f2fd" : "#f3e5f5"

      # Panel background
      img.rect x: panel[:x] + margin, y: panel[:y] + margin, width: panel[:width], height: panel[:height],
             fill: panel_color,
             stroke: "#1976d2",
             stroke_width: 2.0

      # Draw finger joints on the panel
      begin
        oriented_path = build_panel_vectors(panel, generator)

        svg_path = ""
        oriented_path.each do |cmd|
          case cmd[0]
          when :move_to, :line_to
            x = cmd[1] + panel[:x] + margin
            y = cmd[2] + panel[:y] + margin
            svg_path += (cmd[0] == :move_to ? "M" : "L") + " #{x.round(3)} #{y.round(3)} "
          when :close
            svg_path += "Z "
          end
        end

        img.path d: svg_path.strip, fill: 'none', stroke: 'black', 'stroke-width' => '0.5'
      rescue => e
        warn "Failed to draw fingers for #{panel[:name]}: #{e.message}"
      end

      # Panel label
      label_x = panel[:x] + panel[:width] / 2 + margin
      label_y = panel[:y] + panel[:height] / 2 + margin

      # Main label
      img.text panel[:name], x: label_x, y: label_y,
             "text-anchor" => "middle",
             "font-family" => "Arial",
             "font-size" => "12",
             "font-weight" => "bold",
             "fill" => "#1976d2"

      # Dimensions
      img.text "#{panel[:width].round(1)}×#{panel[:height].round(1)}mm", x: label_x, y: label_y + 15,
             "text-anchor" => "middle",
             "font-family" => "Arial",
             "font-size" => "10",
             "fill" => "#424242"

      # Rotation indicator
      if panel[:rotated]
        img.text "↻ ROTATED", x: label_x, y: label_y - 15,
               "text-anchor" => "middle",
               "font-family" => "Arial",
               "font-size" => "8",
               "fill" => "#d32f2f"
      end

      # Panel number
      img.text "#{index + 1}", x: panel[:x] + 5 + margin, y: panel[:y] + 15 + margin,
             "font-family" => "Arial",
             "font-size" => "10",
             "font-weight" => "bold",
             "fill" => "white"
    end

    # Title and info header
    img.text "CUTTING LAYOUT - Sheet #{sheet[:number]}", x: @stock_width / 2 + margin, y: margin - 5,
           "text-anchor" => "middle",
           "font-family" => "Arial",
           "font-size" => "16",
           "font-weight" => "bold",
           "fill" => "black"

    # Sheet information box
    info_y = @stock_height + margin + 15
    img.text "Stock: #{@stock_width}×#{@stock_height}mm", x: margin + 10, y: info_y,
           "font-family" => "Arial",
           "font-size" => "12",
           "fill" => "black"

    img.text "Efficiency: #{sheet[:efficiency]}%", x: margin + 10, y: info_y + 15,
           "font-family" => "Arial",
           "font-size" => "12",
           "fill" => "black"

    img.text "Parts: #{sheet[:panels].length}", x: margin + 10, y: info_y + 30,
           "font-family" => "Arial",
           "font-size" => "12",
           "fill" => "black"

    # Legend
    legend_x = @stock_width - 200 + margin
    img.text "Legend:", x: legend_x, y: info_y,
           "font-family" => "Arial",
           "font-size" => "12",
           "font-weight" => "bold",
           "fill" => "black"

    img.rect x: legend_x, y: info_y + 5, width: 15, height: 10,
           fill: "#e3f2fd",
           stroke: "#1976d2",
           stroke_width: 1.0
    img.text "Even panels", x: legend_x + 20, y: info_y + 12,
           "font-family" => "Arial",
           "font-size" => "10",
           "fill" => "black"

    img.rect x: legend_x, y: info_y + 20, width: 15, height: 10,
           fill: "#f3e5f5",
           stroke: "#1976d2",
           stroke_width: 1.0
    img.text "Odd panels", x: legend_x + 20, y: info_y + 27,
           "font-family" => "Arial",
           "font-size" => "10",
           "fill" => "black"

    File.write(filename, img.render)
    filename
  end

  def build_panel_vectors(panel, generator)
    base_name = panel[:name].sub(/_\d+$/, '')

    original_width  = panel[:rotated] ? panel[:height] : panel[:width]
    original_height = panel[:rotated] ? panel[:width]  : panel[:height]

    path = generator.send(:generate_cutting_path, base_name, original_width, original_height)

    path.map do |cmd|
      case cmd[0]
      when :move_to, :line_to
        x, y = cmd[1], cmd[2]
        if panel[:rotated]
          x, y = y, original_width - x
        end
        [cmd[0], x, y]
      else
        [cmd[0]]
      end
    end
  end


end
