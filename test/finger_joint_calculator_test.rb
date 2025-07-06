require_relative '../finger_joint_calculator'
require_relative 'test_helper'

class FingerJointCalculatorTest < Minitest::Test
  def test_calc_centered_fingers_prefers_odd_count
    calc = FingerJointCalculator.new(finger_width: 10)
    result = calc.send(:calc_centered_fingers, 100)
    assert_equal 9, result[:count]
    assert_in_delta 11.11, result[:width], 0.02
  end

  def test_calc_centered_fingers_expands_when_width_far
    calc = FingerJointCalculator.new(finger_width: 20)
    result = calc.send(:calc_centered_fingers, 55)
    assert_equal 3, result[:count]
    assert_in_delta 18.33, result[:width], 0.02
  end
end
