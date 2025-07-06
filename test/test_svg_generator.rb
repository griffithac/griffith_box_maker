require 'minitest/autorun'
require 'fileutils'
require_relative '../finger_joint_calculator'
require_relative '../svg_generator'

class SVGGeneratorDogboneTest < Minitest::Test
  def setup
    @base_options = {
      box_length: 100,
      box_width: 80,
      box_height: 40,
      stock_thickness: 6,
      finger_width: 15,
      bit_diameter: 3,
      kerf: 0.2,
      lid_height: 20,
      lid_tolerance: 0.5,
      part_spacing: 10,
      enable_lid: false,
      enable_dividers: false,
      enable_x_divider: false,
      enable_y_divider: false,
      open_viewer: false,
      output_dir: File.expand_path('../tmp_test_output', __dir__)
    }
    FileUtils.mkdir_p(@base_options[:output_dir])
    calc = FingerJointCalculator.new(@base_options)
    @layouts = calc.calculate_all_layouts
  end

  def test_dogbones_added_when_enabled
    opts = @base_options.merge(dogbone_style: 3)
    gen = SVGGenerator.new(opts, @layouts)
    file = gen.send(:generate_panel_by_type, 'box_bottom')
    content = File.read(file)
    assert_match(/<circle/, content, 'Dogbone circles should be present when enabled')
  end

  def test_no_dogbones_when_disabled
    opts = @base_options.merge(dogbone_style: 0)
    gen = SVGGenerator.new(opts, @layouts)
    file = gen.send(:generate_panel_by_type, 'box_bottom')
    content = File.read(file)
    refute_match(/<circle/, content, 'Dogbone circles should not be present when disabled')
  end
end
