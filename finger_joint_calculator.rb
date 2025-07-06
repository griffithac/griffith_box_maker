#!/usr/bin/env ruby

class FingerJointCalculator
  def initialize(options)
    @options = options
  end

  def calculate_all_layouts
    {
      box_x: calc_centered_fingers(@options[:box_length]),
      box_y: calc_centered_fingers(@options[:box_width]),
      box_z: calc_centered_fingers(@options[:box_height]),
      lid_x: calc_centered_fingers(lid_length),
      lid_y: calc_centered_fingers(lid_width),
      lid_z: calc_centered_fingers(@options[:lid_height]),
      x_divider_x: calc_centered_fingers(@options[:box_length]),
      x_divider_z: calc_centered_fingers(@options[:box_height]),
      y_divider_y: calc_centered_fingers(@options[:box_width]),
      y_divider_z: calc_centered_fingers(@options[:box_height])
    }
  end

  def lid_length
    @options[:box_length] + 2 * @options[:stock_thickness] + 2 * @options[:lid_tolerance]
  end

  def lid_width
    @options[:box_width] + 2 * @options[:stock_thickness] + 2 * @options[:lid_tolerance]
  end

  private

  def calc_centered_fingers(span)
    finger_width = @options[:finger_width]

    # Start with ideal finger count (prefer odd for symmetry)
    rough_count = (span / finger_width).floor

    # Force odd number for true symmetry
    base_count = rough_count.odd? ? rough_count : [1, rough_count - 1].max

    # Calculate uniform width for symmetry
    uniform_width = span / base_count

    # Check if uniform width is acceptable (within 20% of target)
    width_acceptable = (uniform_width - finger_width).abs <= finger_width * 0.2

    final_count = if width_acceptable
                    base_count
                  elsif base_count + 2 <= rough_count + 2
                    base_count + 2
                  else
                    base_count
                  end

    final_width = span / final_count

    {
      count: final_count,
      width: final_width,
      span: span
    }
  end
end
