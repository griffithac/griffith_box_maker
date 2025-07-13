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
    calc = FingerJointCalculator.new(@options)
    @layouts = calc.calculate_all_layouts
    @gen = SVGGenerator.new(@options, @layouts)
  end

  def cmd_count(layout)
    layout[:count].times.sum { |i| i.even? ? 4 : 1 }
  end

  def extract_segments(path, layout, axis: 1)
    segments = []
    idx = 1
    prev_end = 0
    layout[:count].times do |i|
      if i.even?
        start = path[idx][axis]
        end_pos = path[idx + 2][axis]
        idx += 4
      else
        start = prev_end
        end_pos = path[idx][axis]
        idx += 1
      end
      seg_start = [start, end_pos].min.round(4)
      seg_end   = [start, end_pos].max.round(4)
      segments << [seg_start, seg_end]
      prev_end = end_pos
    end
    segments
  end

  def bottom_edge_segments(path)
    extract_segments(path, @layouts[:box_x], axis: 1)
  end

  def side_bottom_segments(path, layout)
    extract_segments(path, layout, axis: 1)
  end

  def bottom_left_segments(path)
    layout = @layouts[:box_y]
    offset = 1 + cmd_count(@layouts[:box_x]) + cmd_count(@layouts[:box_y]) +
             cmd_count(@layouts[:box_x])
    extract_segments(path[offset..], layout, axis: 2).reverse
  end

  def test_bottom_matches_front
    w, h = @gen.send(:get_panel_dimensions, 'box_bottom')
    bottom_path = @gen.send(:generate_cutting_path, 'box_bottom', w, h)
    w, h = @gen.send(:get_panel_dimensions, 'box_front')
    front_path = @gen.send(:generate_cutting_path, 'box_front', w, h)

    assert_equal bottom_edge_segments(bottom_path),
                 side_bottom_segments(front_path, @layouts[:box_x])
  end

  def test_bottom_matches_left
    w, h = @gen.send(:get_panel_dimensions, 'box_bottom')
    bottom_path = @gen.send(:generate_cutting_path, 'box_bottom', w, h)
    w, h = @gen.send(:get_panel_dimensions, 'box_left')
    left_path = @gen.send(:generate_cutting_path, 'box_left', w, h)

    assert_equal bottom_left_segments(bottom_path),
                 side_bottom_segments(left_path, @layouts[:box_y])
  end
end
