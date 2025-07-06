require_relative 'test_helper'
require_relative '../stl_generator'

class STLGeneratorTest < Minitest::Test
  def setup
    @opts = {
      box_length: 100,
      box_width: 80,
      box_height: 40,
      stock_thickness: 6,
      lid_height: 20,
      lid_tolerance: 1,
      enable_lid: true,
      output_dir: File.expand_path('../tmp_stl', __dir__)
    }
    FileUtils.mkdir_p(@opts[:output_dir])
  end

  def test_generate_creates_binary_stl
    gen = STLGenerator.new(@opts)
    file = gen.generate(File.join(@opts[:output_dir], 'box.stl'))
    assert File.exist?(file)
    header = File.binread(file, 10)
    assert_equal 'STL Ruby', header.strip
  end
end
