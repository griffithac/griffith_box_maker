#!/usr/bin/env ruby

require 'stl'
require 'geometry'

# Simple STL generator for an assembled box
class STLGenerator
  def initialize(options)
    @options = options
  end

  def generate(filename)
    faces = []
    t = @options[:stock_thickness]
    l = @options[:box_length]
    w = @options[:box_width]
    h = @options[:box_height]

    # Bottom panel
    faces.concat prism_faces([0, 0, 0], l, w, t)
    # Front & back panels
    faces.concat prism_faces([0, 0, t], l, t, h)
    faces.concat prism_faces([0, w - t, t], l, t, h)
    # Left & right panels
    faces.concat prism_faces([0, t, t], t, w - 2 * t, h)
    faces.concat prism_faces([l - t, t, t], t, w - 2 * t, h)

    if @options[:enable_lid]
      lid_h = @options[:lid_height]
      lid_l = l + 2 * t + 2 * @options[:lid_tolerance]
      lid_w = w + 2 * t + 2 * @options[:lid_tolerance]
      zoff = h
      xoff = -t - @options[:lid_tolerance]
      yoff = -t - @options[:lid_tolerance]
      # Lid top
      faces.concat prism_faces([xoff, yoff, zoff + lid_h - t], lid_l, lid_w, t)
      # Lid sides
      faces.concat prism_faces([xoff, yoff, zoff], lid_l, t, lid_h - t)
      faces.concat prism_faces([xoff, yoff + lid_w - t, zoff], lid_l, t, lid_h - t)
      faces.concat prism_faces([xoff, yoff + t, zoff], t, lid_w - 2 * t, lid_h - t)
      faces.concat prism_faces([xoff + lid_l - t, yoff + t, zoff], t, lid_w - 2 * t, lid_h - t)
    end

    STL.write(filename, faces, :binary)
    filename
  end

  private

  def prism_faces(origin, lx, ly, lz)
    x0, y0, z0 = origin
    x1 = x0 + lx
    y1 = y0 + ly
    z1 = z0 + lz

    p000 = Geometry::Point[x0, y0, z0]
    p100 = Geometry::Point[x1, y0, z0]
    p010 = Geometry::Point[x0, y1, z0]
    p110 = Geometry::Point[x1, y1, z0]
    p001 = Geometry::Point[x0, y0, z1]
    p101 = Geometry::Point[x1, y0, z1]
    p011 = Geometry::Point[x0, y1, z1]
    p111 = Geometry::Point[x1, y1, z1]

    tris = []
    # Bottom
    tris << tri(p000, p100, p110)
    tris << tri(p000, p110, p010)
    # Top
    tris << tri(p001, p111, p101)
    tris << tri(p001, p011, p111)
    # Front
    tris << tri(p000, p101, p100)
    tris << tri(p000, p001, p101)
    # Back
    tris << tri(p010, p110, p111)
    tris << tri(p010, p111, p011)
    # Left
    tris << tri(p000, p010, p011)
    tris << tri(p000, p011, p001)
    # Right
    tris << tri(p100, p101, p111)
    tris << tri(p100, p111, p110)
    tris
  end

  def tri(a, b, c)
    n = (b - a).cross(c - a)
    n = n / n.magnitude
    [n, Geometry::Triangle.new(a, b, c)]
  end
end
