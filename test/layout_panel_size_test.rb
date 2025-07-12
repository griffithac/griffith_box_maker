require_relative 'test_helper'
require_relative '../finger_joint_calculator'
require_relative '../svg_generator'
require_relative '../layout_optimizer'

class LayoutPanelSizeTest < Minitest::Test
  def setup
    @options = {
      box_length: 60,
      box_width: 50,
      box_height: 40,
      stock_thickness: 6,
      finger_width: 10,
      bit_diameter: 3,
      kerf: 0.2,
      stock_width: 200,
      stock_height: 200,
      part_spacing: 5,
      lid_height: 15,
      lid_tolerance: 0.5,
      enable_lid: false,
      enable_dividers: false
    }
    calc = FingerJointCalculator.new(@options)
    @layouts = calc.calculate_all_layouts
    @generator = SVGGenerator.new(@options, @layouts)
    @dims = {}
    %w[box_bottom box_front box_back box_left box_right].each do |name|
      @dims[name] = @generator.send(:get_panel_dimensions, name)
    end
  end

  def test_layout_panel_dimensions_match_generator
    opt = LayoutOptimizer.new(@options)
    @dims.each do |name, (w, h)|
      opt.add_panel(name, w, h)
    end
    layout = opt.calculate_layout
    layout[:sheets].each do |sheet|
      sheet[:panels].each do |panel|
        base = panel[:name].sub(/_\d+$/, '')
        w, h = @dims[base]
        if panel[:rotated]
          assert_in_delta w, panel[:height], 0.001
          assert_in_delta h, panel[:width], 0.001
        else
          assert_in_delta w, panel[:width], 0.001
          assert_in_delta h, panel[:height], 0.001
        end
      end
    end
  end
end

