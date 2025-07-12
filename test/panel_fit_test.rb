require_relative 'test_helper'
require_relative '../finger_joint_calculator'
require_relative '../svg_generator'

class PanelFitTest < Minitest::Test
  def setup
    @options = {
      box_length: 100,
      box_width: 80,
      box_height: 40,
      stock_thickness: 6,
      finger_width: 15,
      bit_diameter: 3,
      kerf: 0.2,
      lid_height: 20,
      lid_tolerance: 0.5,
      enable_lid: false,
      enable_dividers: false
    }
    @calc = FingerJointCalculator.new(@options)
    @layouts = @calc.calculate_all_layouts
    @gen = SVGGenerator.new(@options, @layouts)
  end

  def cmd_count(layout)
    layout[:count].times.sum { |i| i.even? ? 4 : 1 }
  end

  def bottom_edge_segments(path)
    layout = @layouts[:box_x]
    segments = []
    idx = 1
    layout[:count].times do |i|
      start, width = @gen.send(:get_finger_info, i, layout)
      end_pos = start + width
      if i.even?
        expected = [
          [:line_to, start, 0],
          [:line_to, start, -@options[:stock_thickness] - @options[:kerf]],
          [:line_to, end_pos, -@options[:stock_thickness] - @options[:kerf]],
          [:line_to, end_pos, 0]
        ]
      else
        expected = [[:line_to, end_pos, 0]]
      end
      assert_equal expected, path[idx, expected.length]
      idx += expected.length
      segments << [start, end_pos]
    end
    segments
  end

  def side_bottom_segments(path, layout)
    segments = []
    idx = 1
    layout[:count].times do |i|
      start, width = @gen.send(:get_finger_info, i, layout)
      end_pos = start + width
      if i.even?
        expected = [
          [:line_to, start, 0],
          [:line_to, start, @options[:stock_thickness] + @options[:kerf]],
          [:line_to, end_pos, @options[:stock_thickness] + @options[:kerf]],
          [:line_to, end_pos, 0]
        ]
      else
        expected = [[:line_to, end_pos, 0]]
      end
      assert_equal expected, path[idx, expected.length]
      idx += expected.length
      segments << [start, end_pos]
    end
    segments
  end

  def bottom_left_segments(path)
    layout = @layouts[:box_y]
    start_idx = 1 + cmd_count(@layouts[:box_x]) + cmd_count(@layouts[:box_y]) + cmd_count(@layouts[:box_x])
    segments = []
    idx = start_idx
    (layout[:count] - 1).downto(0) do |j|
      start, width = @gen.send(:get_finger_info, j, layout)
      end_pos = start + width
      if j.even?
        expected = [
          [:line_to, 0, end_pos],
          [:line_to, -@options[:stock_thickness] - @options[:kerf], end_pos],
          [:line_to, -@options[:stock_thickness] - @options[:kerf], start],
          [:line_to, 0, start]
        ]
      else
        expected = [[:line_to, 0, start]]
      end
      assert_equal expected, path[idx, expected.length]
      idx += expected.length
      segments << [start, end_pos]
    end
    segments.reverse
  end

  def test_bottom_matches_front
    w, h = @gen.send(:get_panel_dimensions, 'box_bottom')
    bottom_path = @gen.send(:generate_cutting_path, 'box_bottom', w, h)
    w, h = @gen.send(:get_panel_dimensions, 'box_front')
    front_path = @gen.send(:generate_cutting_path, 'box_front', w, h)

    bottom = bottom_edge_segments(bottom_path)
    front = side_bottom_segments(front_path, @layouts[:box_x])
    assert_equal bottom, front
  end

  def test_bottom_matches_left
    w, h = @gen.send(:get_panel_dimensions, 'box_bottom')
    bottom_path = @gen.send(:generate_cutting_path, 'box_bottom', w, h)
    w, h = @gen.send(:get_panel_dimensions, 'box_left')
    left_path = @gen.send(:generate_cutting_path, 'box_left', w, h)

    bottom_left = bottom_left_segments(bottom_path)
    left_bottom = side_bottom_segments(left_path, @layouts[:box_y])
    assert_equal bottom_left, left_bottom
  end
end
