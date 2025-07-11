require_relative 'test_helper'
require_relative '../finger_joint_calculator'
require_relative '../svg_generator'
require 'fileutils'

class VectorValidityTest < Minitest::Test
  def setup
    @options = {
      box_length: 50,
      box_width: 40,
      box_height: 30,
      stock_thickness: 6,
      finger_width: 10,
      bit_diameter: 3,
      kerf: 0.2,
      lid_height: 15,
      lid_tolerance: 0.5,
      dogbone_style: 0,
      open_viewer: false,
      enable_lid: false,
      enable_dividers: false,
      enable_x_divider: false,
      enable_y_divider: false,
      output_dir: File.expand_path('../tmp_vector_test', __dir__)
    }
    FileUtils.mkdir_p(@options[:output_dir])
    calc = FingerJointCalculator.new(@options)
    @layouts = calc.calculate_all_layouts
    @gen = SVGGenerator.new(@options, @layouts)
  end

  def test_box_bottom_path_is_closed
    width, height = @gen.send(:get_panel_dimensions, 'box_bottom')
    path = @gen.send(:generate_cutting_path, 'box_bottom', width, height)

    move_cmds = path.select { |c| c[0] == :move_to }
    assert_equal 1, move_cmds.length, 'Path should start with a single move_to'

    assert_equal :close, path.last[0], 'Path should end with a close command'

    start_point = move_cmds.first[1, 2]
    last_point = nil
    path.reverse_each do |cmd|
      if cmd[0] == :line_to
        last_point = [cmd[1], cmd[2]]
        break
      end
    end

    assert last_point, 'Path should contain line segments'
    assert_in_delta start_point[0], last_point[0], 0.001
    assert_in_delta start_point[1], last_point[1], 0.001
  end
end
