#!/usr/bin/env ruby

require 'victor'
require 'fileutils'

class SVGGenerator
  def initialize(options, layouts)
    @options = options
    @layouts = layouts
    @kerf = options[:kerf]
    @stock_thickness = options[:stock_thickness]
    @bit_radius = options[:bit_diameter] / 2.0
  end

  def generate_all_panels
    files = []
    puts "📝 Generating SVG cutting paths..."

    begin
      # Box panels
      files << generate_panel("box_bottom")
      files << generate_panel("box_front")
      files << generate_panel("box_back")
      files << generate_panel("box_left")
      files << generate_panel("box_right")

      # Dividers
      if @options[:enable_dividers]
        files << generate_panel("x_divider") if @options[:enable_x_divider]
        files << generate_panel("y_divider") if @options[:enable_y_divider]
      end

      # Lid panels
      if @options[:enable_lid]
        files << generate_panel("lid_top")
        files << generate_panel("lid_front")
        files << generate_panel("lid_back")
        files << generate_panel("lid_left")
        files << generate_panel("lid_right")
      end

      files.compact
    rescue => e
      puts "❌ Error in generate_all_panels: #{e.message}"
      puts "Stacktrace:"
      e.backtrace.each { |line| puts "  #{line}" }
      raise e
    end
  end

  private

  def generate_panel(panel_type)
    puts "Generating #{panel_type}..."

    filename = File.join(@options[:output_dir], "#{panel_type}.svg")
    width, height = get_panel_dimensions(panel_type)

    # Add margins for cutting
    margin = 10
    svg_width = width + 2 * margin
    svg_height = height + 2 * margin

    img = Victor::SVG.new width: svg_width.to_i, height: svg_height.to_i

    # Generate the cutting path for this panel
    cutting_path = generate_cutting_path(panel_type, width, height)

    # Draw the cutting path
    draw_cutting_path(img, cutting_path, margin)

    # Add dogbones if enabled
    if @options[:dogbone_style] == 3
      add_dogbones_to_path(img, cutting_path, margin)
    end

    File.write(filename, img.render)
    filename
  end

  # Backwards compatibility for tests expecting `generate_panel_by_type`
  alias generate_panel_by_type generate_panel

  def get_panel_dimensions(panel_type)
    case panel_type
    when "box_bottom"
      [@options[:box_length], @options[:box_width]]
    when "lid_top"
      [lid_length, lid_width]
    when /box.*front/, /box.*back/
      [@options[:box_length], @options[:box_height]]
    when /lid.*front/, /lid.*back/
      [lid_length, @options[:lid_height]]
    when /box.*left/, /box.*right/
      [@options[:box_width], @options[:box_height]]
    when /lid.*left/, /lid.*right/
      [lid_width, @options[:lid_height]]
    when /x_divider/
      [@options[:box_length], @options[:box_height]]
    when /y_divider/
      [@options[:box_width], @options[:box_height]]
    else
      [@options[:box_length], @options[:box_width]]
    end
  end

  def generate_cutting_path(panel_type, width, height)
    case panel_type
    when "box_bottom"
      generate_box_bottom_path(width, height)
    when "box_front", "box_back"
      generate_box_side_long_path(width, height)
    when "box_left", "box_right"
      generate_box_side_short_path(width, height)
    when "lid_top"
      generate_lid_top_path(width, height)
    when "lid_front", "lid_back"
      generate_lid_side_long_path(width, height)
    when "lid_left", "lid_right"
      generate_lid_side_short_path(width, height)
    when "x_divider"
      generate_x_divider_path(width, height)
    when "y_divider"
      generate_y_divider_path(width, height)
    else
      generate_simple_rectangle_path(width, height)
    end
  end

  def generate_box_bottom_path(width, height)
    path = []
    layout_x = @layouts[:box_x]
    layout_y = @layouts[:box_y]

    # Start at bottom-left corner
    x, y = 0, 0
    path << [:move_to, x, y]

    # Bottom edge with fingers (X direction)
    # Even indices get slots (cut inward), odd indices are solid (straight)
    (0...layout_x[:count]).each do |i|
      finger_start, finger_width = get_finger_info(i, layout_x)

      if i.even?
        # Even finger - create slot (cut inward)
        # Move to slot start
        path << [:line_to, finger_start, y]
        # Cut slot
        path << [:line_to, finger_start, y + @stock_thickness + @kerf]
        path << [:line_to, finger_start + finger_width, y + @stock_thickness + @kerf]
        path << [:line_to, finger_start + finger_width, y]
      else
        # Odd finger - straight line
        path << [:line_to, finger_start + finger_width, y]
      end
    end

    # Right edge with fingers (Y direction)
    x = width
    (0...layout_y[:count]).each do |j|
      finger_start, finger_width = get_finger_info(j, layout_y)

      if j.even?
        # Even finger - create slot
        path << [:line_to, x, finger_start]
        path << [:line_to, x - @stock_thickness - @kerf, finger_start]
        path << [:line_to, x - @stock_thickness - @kerf, finger_start + finger_width]
        path << [:line_to, x, finger_start + finger_width]
      else
        # Odd finger - straight line
        path << [:line_to, x, finger_start + finger_width]
      end
    end

    # Top edge with fingers (X direction, reversed)
    y = height
    (layout_x[:count]-1).downto(0) do |i|
      finger_start, finger_width = get_finger_info(i, layout_x)
      finger_end = finger_start + finger_width

      if i.even?
        # Even finger - create slot
        path << [:line_to, finger_end, y]
        path << [:line_to, finger_end, y - @stock_thickness - @kerf]
        path << [:line_to, finger_start, y - @stock_thickness - @kerf]
        path << [:line_to, finger_start, y]
      else
        # Odd finger - straight line
        path << [:line_to, finger_start, y]
      end
    end

    # Left edge with fingers (Y direction, reversed)
    x = 0
    (layout_y[:count]-1).downto(0) do |j|
      finger_start, finger_width = get_finger_info(j, layout_y)
      finger_end = finger_start + finger_width

      if j.even?
        # Even finger - create slot
        path << [:line_to, x, finger_end]
        path << [:line_to, x + @stock_thickness + @kerf, finger_end]
        path << [:line_to, x + @stock_thickness + @kerf, finger_start]
        path << [:line_to, x, finger_start]
      else
        # Odd finger - straight line
        path << [:line_to, x, finger_start]
      end
    end

    # Close path
    path << [:close]
    path
  end

  def generate_box_side_long_path(width, height)
    path = []
    layout_x = @layouts[:box_x]
    layout_z = @layouts[:box_z]

    # Start at bottom-left
    x, y = 0, 0
    path << [:move_to, x, y]

    # Bottom edge - odd fingers get slots (to mate with bottom even fingers)
    (0...layout_x[:count]).each do |i|
      finger_start, finger_width = get_finger_info(i, layout_x)

      if i.odd?
        # Odd finger - create slot
        path << [:line_to, finger_start, y]
        path << [:line_to, finger_start, y - @stock_thickness - @kerf]
        path << [:line_to, finger_start + finger_width, y - @stock_thickness - @kerf]
        path << [:line_to, finger_start + finger_width, y]
      else
        # Even finger - straight line
        path << [:line_to, finger_start + finger_width, y]
      end
    end

    # Right edge - odd fingers get slots for vertical connections
    x = width
    (0...layout_z[:count]).each do |k|
      finger_start, finger_width = get_finger_info(k, layout_z)

      if k.odd?
        # Odd finger - create slot
        path << [:line_to, x, finger_start]
        path << [:line_to, x - @stock_thickness - @kerf, finger_start]
        path << [:line_to, x - @stock_thickness - @kerf, finger_start + finger_width]
        path << [:line_to, x, finger_start + finger_width]
      else
        # Even finger - straight line
        path << [:line_to, x, finger_start + finger_width]
      end
    end

    # Top edge - straight
    path << [:line_to, 0, height]

    # Left edge - odd fingers get slots for vertical connections
    x = 0
    (layout_z[:count]-1).downto(0) do |k|
      finger_start, finger_width = get_finger_info(k, layout_z)
      finger_end = finger_start + finger_width

      if k.odd?
        # Odd finger - create slot
        path << [:line_to, x, finger_end]
        path << [:line_to, x + @stock_thickness + @kerf, finger_end]
        path << [:line_to, x + @stock_thickness + @kerf, finger_start]
        path << [:line_to, x, finger_start]
      else
        # Even finger - straight line
        path << [:line_to, x, finger_start]
      end
    end

    path << [:close]
    path
  end

  def generate_box_side_short_path(width, height)
    path = []
    layout_y = @layouts[:box_y]
    layout_z = @layouts[:box_z]

    # Start at bottom-left
    x, y = 0, 0
    path << [:move_to, x, y]

    # Bottom edge - odd fingers get slots (to mate with bottom even fingers)
    (0...layout_y[:count]).each do |j|
      finger_start, finger_width = get_finger_info(j, layout_y)

      if j.odd?
        # Odd finger - create slot
        path << [:line_to, finger_start, y]
        path << [:line_to, finger_start, y - @stock_thickness - @kerf]
        path << [:line_to, finger_start + finger_width, y - @stock_thickness - @kerf]
        path << [:line_to, finger_start + finger_width, y]
      else
        # Even finger - straight line
        path << [:line_to, finger_start + finger_width, y]
      end
    end

    # Right edge - even fingers get slots for vertical connections
    x = width
    (0...layout_z[:count]).each do |k|
      finger_start, finger_width = get_finger_info(k, layout_z)

      if k.even?
        # Even finger - create slot
        path << [:line_to, x, finger_start]
        path << [:line_to, x - @stock_thickness - @kerf, finger_start]
        path << [:line_to, x - @stock_thickness - @kerf, finger_start + finger_width]
        path << [:line_to, x, finger_start + finger_width]
      else
        # Odd finger - straight line
        path << [:line_to, x, finger_start + finger_width]
      end
    end

    # Top edge - straight
    path << [:line_to, 0, height]

    # Left edge - even fingers get slots for vertical connections
    x = 0
    (layout_z[:count]-1).downto(0) do |k|
      finger_start, finger_width = get_finger_info(k, layout_z)
      finger_end = finger_start + finger_width

      if k.even?
        # Even finger - create slot
        path << [:line_to, x, finger_end]
        path << [:line_to, x + @stock_thickness + @kerf, finger_end]
        path << [:line_to, x + @stock_thickness + @kerf, finger_start]
        path << [:line_to, x, finger_start]
      else
        # Odd finger - straight line
        path << [:line_to, x, finger_start]
      end
    end

    path << [:close]
    path
  end

  def generate_lid_top_path(width, height)
    # Similar to box bottom but with lid layouts
    path = []
    layout_x = @layouts[:lid_x]
    layout_y = @layouts[:lid_y]

    # Start at bottom-left corner
    x, y = 0, 0
    path << [:move_to, x, y]

    # Simple implementation for now - can be enhanced later
    # Just draw a rectangle with finger profiles
    generate_simple_rectangle_path(width, height)
  end

  def generate_lid_side_long_path(width, height)
    generate_simple_rectangle_path(width, height)
  end

  def generate_lid_side_short_path(width, height)
    generate_simple_rectangle_path(width, height)
  end

  def generate_x_divider_path(width, height)
    generate_simple_rectangle_path(width, height)
  end

  def generate_y_divider_path(width, height)
    generate_simple_rectangle_path(width, height)
  end

  def generate_simple_rectangle_path(width, height)
    [
      [:move_to, 0, 0],
      [:line_to, width, 0],
      [:line_to, width, height],
      [:line_to, 0, height],
      [:close]
    ]
  end

  def get_finger_info(index, layout)
    width = layout[:width]
    # Calculate start position based on uniform width.  For the last finger,
    # force the end position to align exactly with the span to avoid small
    # floating point drift which can create diagonal artifacts at the
    # corners when the path is closed.
    if index == layout[:count] - 1
      start_pos = layout[:span] - width
    else
      start_pos = index * width
    end

    [start_pos.round(4), width.round(4)]
  end

  def draw_cutting_path(img, path, margin)
    return if path.empty?

    # Convert path to SVG path data
    svg_path = ""

    path.each do |command|
      case command[0]
      when :move_to
        x, y = command[1] + margin, command[2] + margin
        svg_path += "M #{x.round(3)} #{y.round(3)} "
      when :line_to
        x, y = command[1] + margin, command[2] + margin
        svg_path += "L #{x.round(3)} #{y.round(3)} "
      when :close
        svg_path += "Z "
      end
    end

    # Draw the path
    img.path d: svg_path.strip,
             fill: "none",
             stroke: "black",
             "stroke-width" => "0.5"
  end

  def add_dogbones_to_path(img, path, margin)
    # Find inside corners in the path and add dogbone circles
    # This is a simplified implementation - can be enhanced
    offset_45 = @bit_radius * 0.707

    # For now, just add dogbones at strategic points
    # This would need more sophisticated corner detection
    path.each_with_index do |command, i|
      if command[0] == :line_to && i > 0
        x, y = command[1] + margin, command[2] + margin

        # Add a small dogbone circle at this point if it's an inside corner
        # (This is a placeholder - real implementation would need corner detection)
        if should_add_dogbone(path, i)
          img.circle cx: x + offset_45, cy: y + offset_45, r: @bit_radius,
                     fill: "none",
                     stroke: "red",
                     "stroke-width" => "0.3"
        end
      end
    end
  end

  def should_add_dogbone(path, index)
    # Determine if the vertex at `index` forms an internal (concave) corner.
    first_move = path.find { |cmd| cmd[0] == :move_to }
    return false unless first_move
    start_point = [first_move[1], first_move[2]]

    # Helper to resolve a point from a command
    get_point = lambda do |cmd|
      case cmd[0]
      when :move_to, :line_to
        [cmd[1], cmd[2]]
      when :close
        start_point
      else
        nil
      end
    end

    current = get_point.call(path[index])
    return false unless current

    # Find previous drawing command
    prev_idx = index - 1
    prev_idx -= 1 while prev_idx > 0 && path[prev_idx][0] == :close
    previous = prev_idx >= 0 ? get_point.call(path[prev_idx]) : start_point

    # Find next drawing command
    next_idx = index + 1
    next_idx += 1 while next_idx < path.length && path[next_idx][0] == :close
    nxt = next_idx < path.length ? get_point.call(path[next_idx]) : start_point
    return false unless previous && nxt

    v1x = current[0] - previous[0]
    v1y = current[1] - previous[1]
    v2x = nxt[0] - current[0]
    v2y = nxt[1] - current[1]

    cross = v1x * v2y - v1y * v2x
    cross < -0.001
  end

  def lid_length
    @options[:box_length] + 2 * @options[:stock_thickness] + 2 * @options[:lid_tolerance]
  end

  def lid_width
    @options[:box_width] + 2 * @options[:stock_thickness] + 2 * @options[:lid_tolerance]
  end
end
