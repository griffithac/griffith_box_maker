require_relative '../layout_optimizer'
require_relative 'test_helper'

class LayoutOptimizerTest < Minitest::Test
  def test_single_sheet_layout
    opt = LayoutOptimizer.new(stock_width: 100, stock_height: 100, part_spacing: 5)
    opt.add_panel('a', 40, 50)
    opt.add_panel('b', 30, 30)
    layout = opt.calculate_layout

    assert_equal 1, layout[:total_sheets]
    sheet = layout[:sheets].first
    assert_equal 2, sheet[:panels].size
    sheet[:panels].each do |p|
      assert p[:placed]
      assert_operator p[:x] + p[:width], :<=, sheet[:width]
      assert_operator p[:y] + p[:height], :<=, sheet[:height]
    end
  end

  def test_multiple_sheet_layout
    opt = LayoutOptimizer.new(stock_width: 100, stock_height: 100, part_spacing: 5)
    3.times { |i| opt.add_panel("p#{i}", 80, 80) }
    layout = opt.calculate_layout

    assert_equal 3, layout[:total_sheets]
    layout[:sheets].each do |sheet|
      assert_equal 1, sheet[:panels].size
      assert sheet[:panels].first[:placed]
    end
  end
end
