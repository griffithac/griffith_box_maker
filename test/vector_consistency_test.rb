require_relative 'test_helper'
require_relative '../finger_joint_calculator'
require_relative '../svg_generator'
require_relative '../layout_optimizer'

class VectorConsistencyTest < Minitest::Test
  def setup
    @options = {
      box_length: 50,
      box_width: 40,
      box_height: 30,
      stock_thickness: 6,
      finger_width: 10,
      bit_diameter: 3,
      kerf: 0.2,
      stock_width: 100,
      stock_height: 100,
      part_spacing: 5,
      lid_height: 15,
      lid_tolerance: 0.5,
      enable_lid: false,
      enable_dividers: false,
      open_viewer: false
    }
    calc = FingerJointCalculator.new(@options)
    @layouts = calc.calculate_all_layouts
    @generator = SVGGenerator.new(@options, @layouts)
  end

  def test_non_rotated_panel_vectors_match
    opt = LayoutOptimizer.new(@options)
    opt.add_panel('box_bottom', @options[:box_length], @options[:box_width])
    layout = opt.calculate_layout
    panel = layout[:sheets].first[:panels].first

    from_layout = opt.send(:build_panel_vectors, panel, @generator)
    w, h = @generator.send(:get_panel_dimensions, 'box_bottom')
    from_generator = @generator.send(:generate_cutting_path, 'box_bottom', w, h)

    assert_equal from_generator, from_layout
  end

  def test_rotated_panel_vectors_match
    opt = LayoutOptimizer.new(@options.merge(stock_width: 35, stock_height: 100))
    opt.add_panel('box_left', @options[:box_width], @options[:box_height])
    layout = opt.calculate_layout
    panel = layout[:sheets].first[:panels].first
    assert panel[:rotated], 'Panel should be rotated to fit'

    from_layout = opt.send(:build_panel_vectors, panel, @generator)
    w, h = @generator.send(:get_panel_dimensions, 'box_left')
    from_generator = @generator.send(:generate_cutting_path, 'box_left', w, h)
    rotated = from_generator.map do |cmd|
      case cmd[0]
      when :move_to, :line_to
        [cmd[0], cmd[2], w - cmd[1]]
      else
        [cmd[0]]
      end
    end

    assert_equal rotated, from_layout
  end
end
