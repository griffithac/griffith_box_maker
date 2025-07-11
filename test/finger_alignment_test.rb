require_relative '../finger_joint_calculator'
require_relative 'test_helper'

class FingerAlignmentTest < Minitest::Test
  def test_total_width_matches_span
    calc = FingerJointCalculator.new(finger_width: 15)
    result = calc.send(:calc_centered_fingers, 100)
    total = result[:count] * result[:width]
    assert_in_delta 100, total, 0.001, 'Total finger widths should equal span'
  end
end
