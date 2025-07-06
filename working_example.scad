// storage_box_with_lid_dividers.scad – Parametric finger-jointed box with optional lid and dividers
// OpenSCAD 2021.01-compatible

//---------------------------------------------------------------
// LAYOUT MODE SELECTION ----------------------------------------
//---------------------------------------------------------------
layout_mode = 1;  // 0 = 3D assembly, 1 = Flat layout for CNC

//---------------------------------------------------------------
// DESIGN PARAMETERS --------------------------------------------
//---------------------------------------------------------------
// Stock material dimensions
stock_length    = 1220; // mm – available stock length
stock_width     = 1220; // mm – available stock width  
stock_thickness = 5.2;  // mm sheet thickness

// Box dimensions
box_length      = 278;  // mm – outer X (long side)
box_width       = 498;  // mm – outer Y (short side)
box_height      = 73;  // mm – outer Z

// Lid parameters
enable_lid      = true; // Enable/disable lid
lid_height      = 40;   // mm – height of lid
lid_tolerance   = 1;    // mm – gap between box and lid on each side

// Divider parameters
enable_dividers = true; // Enable/disable divider functionality (slots in box/sides)
                        // Individual divider rendering controlled by enable_x_divider/enable_y_divider

// Part visibility controls
enable_box_bottom = true;
enable_box_front = true;    enable_box_back = true;
enable_box_left = true;     enable_box_right = true;
enable_lid_top = true;      enable_lid_front = true;
enable_lid_back = true;     enable_lid_left = true;
enable_lid_right = true;
enable_x_divider = true;    enable_y_divider = true;

// Layout and cutting parameters
part_spacing    = 20;   // mm – spacing between parts in flat layout
finger_width    = 40;   // mm – standard finger/slot size
bit_diameter    = 3.175;    // mm – end-mill Ø for dog-bone relief
kerf            = 0.3;  // mm – kerf compensation
dogbone_style = 3;      // 0=None, 1=Long side, 2=T-Bone, 3=45° fillets

// Divider parameters
divider_edge_margin = 6;       // mm – keeps divider side fingers away from panel edges

//---------------------------------------------------------------
// CALCULATED CONSTANTS -----------------------------------------
//---------------------------------------------------------------
lid_length = box_length + 2 * stock_thickness + 2 * lid_tolerance;
lid_width = box_width + 2 * stock_thickness + 2 * lid_tolerance;

// Divider dimensions - full length to connect to sides  
x_divider_length = box_length;  // X-divider spans X direction (left to right)
x_divider_height = box_height;  // Full height from bottom to top
y_divider_length = box_width;   // Y-divider spans Y direction (front to back)
y_divider_height = box_height;  // Full height from bottom to top

// Divider positions (centered)
x_divider_pos_y = box_width / 2;  // Y position for X divider (249mm)
y_divider_pos_x = box_length / 2; // X position for Y divider (139mm)

//---------------------------------------------------------------
// CORE FUNCTIONS -----------------------------------------------
//---------------------------------------------------------------
// Calculate centered finger layout for a given span with true symmetry
function calc_centered_fingers(span) = 
    let(
        // Start with ideal finger count (prefer odd for symmetry)
        rough_count = floor(span / finger_width),
        
        // Force odd number for true symmetry (mirrored ends)
        base_count = (rough_count % 2 == 0) ? max(1, rough_count - 1) : rough_count,
        
        // For symmetry, all fingers should be the same width
        // Calculate what that width should be
        uniform_width = span / base_count,
        
        // Check if uniform width is acceptable (within 20% of target)
        width_acceptable = abs(uniform_width - finger_width) <= finger_width * 0.2,
        
        // If uniform width not acceptable, try with more fingers
        final_count = width_acceptable ? base_count : 
                     (base_count + 2 <= rough_count + 2) ? base_count + 2 : base_count,
        
        final_width = span / final_count,
        
        // For true symmetry, all fingers are the same width
        corner_width = final_width,
        extra_space = 0  // No extra space with uniform sizing
    )
    [final_count, final_width, corner_width, extra_space];

// Get finger start position and width for finger index i (symmetrical)
function get_finger_info(i, span, layout) = 
    let(
        count = layout[0],
        uniform_width = span / count,  // All fingers same width for symmetry
        width = uniform_width,
        start = i * uniform_width
    )
    [start, width];

//---------------------------------------------------------------
// LAYOUT CALCULATIONS -----------------------------------------
//---------------------------------------------------------------
x_layout = calc_centered_fingers(box_length);
y_layout = calc_centered_fingers(box_width);
z_layout = calc_centered_fingers(box_height);
lid_x_layout = calc_centered_fingers(lid_length);
lid_y_layout = calc_centered_fingers(lid_width);
lid_z_layout = calc_centered_fingers(lid_height);

// Divider layouts
x_divider_x_layout = calc_centered_fingers(x_divider_length);
x_divider_z_layout = calc_centered_fingers(x_divider_height);
y_divider_y_layout = calc_centered_fingers(y_divider_length);
y_divider_z_layout = calc_centered_fingers(y_divider_height);

//---------------------------------------------------------------
// BOX PANEL MODULES -------------------------------------------
//---------------------------------------------------------------
module panel_bottom() {
    difference() {
        cube([box_length, box_width, stock_thickness]);
        
        // X-direction slots (fingers on even indices = 0,2,4...)
        for(i = [0 : x_layout[0]-1]) {
            if(i % 2 == 0) {
                finger_info = get_finger_info(i, box_length, x_layout);
                x_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                
                // Front edge slot
                translate([x_start, 0, -5])
                    cube([width, stock_thickness + kerf, stock_thickness + 10]);
                // Back edge slot
                translate([x_start, box_width - stock_thickness - kerf, -5])
                    cube([width, stock_thickness + kerf, stock_thickness + 10]);
            }
        }
        
        // Y-direction slots (fingers on even indices = 0,2,4...)
        for(j = [0 : y_layout[0]-1]) {
            if(j % 2 == 0) {
                finger_info = get_finger_info(j, box_width, y_layout);
                y_start = finger_info[0] - kerf/2;
                height = finger_info[1] + kerf;
                
                // Left edge slot
                translate([0, y_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
                // Right edge slot
                translate([box_length - stock_thickness - kerf, y_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
            }
        }
        
        // X-divider slots (if enabled) - all fingers, no skipping
        if(enable_dividers) {
            for(i = [0 : x_divider_x_layout[0]-1]) {
                // Skip end positions where dividers won't have bottom fingers (collision avoidance)
                is_end_finger = (i == 0 || i == x_divider_x_layout[0]-1);
                if(i % 2 == 1 && !is_end_finger) {
                    finger_info = get_finger_info(i, x_divider_length, x_divider_x_layout);
                    x_start = finger_info[0] - kerf/2;
                    width = finger_info[1] + kerf;
                    
                    translate([x_start, x_divider_pos_y - stock_thickness/2 - kerf/2, -5])
                        cube([width, stock_thickness + kerf, stock_thickness + 10]);
                }
            }
        }
        
        // Y-divider slots (if enabled) - all fingers, no skipping
        if(enable_dividers) {
            for(j = [0 : y_divider_y_layout[0]-1]) {
                // Skip end positions where dividers won't have bottom fingers (collision avoidance)
                is_end_finger = (j == 0 || j == y_divider_y_layout[0]-1);
                if(j % 2 == 1 && !is_end_finger) {
                    finger_info = get_finger_info(j, y_divider_length, y_divider_y_layout);
                    y_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    translate([y_divider_pos_x - stock_thickness/2 - kerf/2, y_start, -5])
                        cube([stock_thickness + kerf, height, stock_thickness + 10]);
                }
            }
        }
        
        // Dog-bone reliefs
        if(dogbone_style == 3) {
            r = bit_diameter / 2;
            offset_45 = r * 0.707;
            
            for(i = [0 : x_layout[0]-1]) {
                if(i % 2 == 0) {
                    finger_info = get_finger_info(i, box_length, x_layout);
                    x_start = finger_info[0] - kerf/2;
                    width = finger_info[1] + kerf;
                    
                    if(x_start > 0) {
                        translate([x_start + offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        translate([x_start + offset_45, box_width - stock_thickness - kerf + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(x_start + width < box_length) {
                        translate([x_start + width - offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        translate([x_start + width - offset_45, box_width - stock_thickness - kerf + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            for(j = [0 : y_layout[0]-1]) {
                if(j % 2 == 0) {
                    finger_info = get_finger_info(j, box_width, y_layout);
                    y_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    if(y_start > 0) {
                        translate([stock_thickness + kerf - offset_45, y_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        translate([box_length - stock_thickness - kerf + offset_45, y_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(y_start + height < box_width) {
                        translate([stock_thickness + kerf - offset_45, y_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        translate([box_length - stock_thickness - kerf + offset_45, y_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            // Divider slot dogbones - no skip logic
            if(enable_dividers) {
                // X-divider slot dogbones
                for(i = [0 : x_divider_x_layout[0]-1]) {
                    is_end_finger = (i == 0 || i == x_divider_x_layout[0]-1);
                    if(i % 2 == 1 && !is_end_finger) {
                        finger_info = get_finger_info(i, x_divider_length, x_divider_x_layout);
                        x_start = finger_info[0] - kerf/2;
                        width = finger_info[1] + kerf;
                        
                        if(x_start > 0) {
                            translate([x_start + offset_45, x_divider_pos_y - stock_thickness/2 - kerf/2 + offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                            translate([x_start + offset_45, x_divider_pos_y + stock_thickness/2 + kerf/2 - offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        }
                        if(x_start + width < box_length) {
                            translate([x_start + width - offset_45, x_divider_pos_y - stock_thickness/2 - kerf/2 + offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                            translate([x_start + width - offset_45, x_divider_pos_y + stock_thickness/2 + kerf/2 - offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        }
                    }
                }
                
                // Y-divider slot dogbones
                for(j = [0 : y_divider_y_layout[0]-1]) {
                    is_end_finger = (j == 0 || j == y_divider_y_layout[0]-1);
                    if(j % 2 == 1 && !is_end_finger) {
                        finger_info = get_finger_info(j, y_divider_length, y_divider_y_layout);
                        y_start = finger_info[0] - kerf/2;
                        height = finger_info[1] + kerf;
                        
                        if(y_start > 0) {
                            translate([y_divider_pos_x - stock_thickness/2 - kerf/2 + offset_45, y_start + offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                            translate([y_divider_pos_x + stock_thickness/2 + kerf/2 - offset_45, y_start + offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        }
                        if(y_start + height < box_width) {
                            translate([y_divider_pos_x - stock_thickness/2 - kerf/2 + offset_45, y_start + height - offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                            translate([y_divider_pos_x + stock_thickness/2 + kerf/2 - offset_45, y_start + height - offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        }
                    }
                }
            }
        }
    }
}

module panel_side_long_flat() {
    difference() {
        cube([box_length, box_height, stock_thickness]);
        
        // Bottom edge slots (odd indices to mate with bottom even fingers)
        for(i = [0 : x_layout[0]-1]) {
            if(i % 2 == 1) {
                finger_info = get_finger_info(i, box_length, x_layout);
                x_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                
                translate([x_start, 0, -5])
                    cube([width, stock_thickness + kerf, stock_thickness + 10]);
            }
        }
        
        // Vertical edge slots
        for(k = [0 : z_layout[0]-1]) {
            finger_info = get_finger_info(k, box_height, z_layout);
            z_start = finger_info[0] - kerf/2;
            height = finger_info[1] + kerf;
            
            if(k % 2 == 1) {
                translate([0, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
                translate([box_length - stock_thickness - kerf, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
            }
        }
        
        // Y-divider mortises - all positions
        if(enable_dividers) {
            for(k = [0 : y_divider_z_layout[0]-1]) {
                if(k % 2 == 1) {  // Odd positions to mate with divider fingers
                    finger_info = get_finger_info(k, y_divider_height, y_divider_z_layout);
                    z_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    translate([y_divider_pos_x - stock_thickness/2 - kerf/2, z_start, -5])
                        cube([stock_thickness + kerf, height, stock_thickness + 10]);
                }
            }
        }
        
        // Dog-bone reliefs
        if(dogbone_style == 3) {
            r = bit_diameter / 2;
            offset_45 = r * 0.707;
            
            for(i = [0 : x_layout[0]-1]) {
                if(i % 2 == 1) {
                    finger_info = get_finger_info(i, box_length, x_layout);
                    x_start = finger_info[0] - kerf/2;
                    width = finger_info[1] + kerf;
                    
                    if(x_start > 0) {
                        translate([x_start + offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(x_start + width < box_length) {
                        translate([x_start + width - offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            for(k = [0 : z_layout[0]-1]) {
                if(k % 2 == 1) {
                    finger_info = get_finger_info(k, box_height, z_layout);
                    z_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    if(z_start > 0) {
                        translate([stock_thickness + kerf - offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        translate([box_length - stock_thickness - kerf + offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(z_start + height < box_height) {
                        translate([stock_thickness + kerf - offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        translate([box_length - stock_thickness - kerf + offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            // Y-divider mortise dogbones - all mortises
            if(enable_dividers) {
                for(k = [0 : y_divider_z_layout[0]-1]) {
                    if(k % 2 == 1) {  // Only where we have mortises
                        finger_info = get_finger_info(k, y_divider_height, y_divider_z_layout);
                        z_start = finger_info[0] - kerf/2;
                        height = finger_info[1] + kerf;
                        
                        // Mortise dogbones - only at inside corners
                        if(z_start > 0) {
                            translate([y_divider_pos_x - stock_thickness/2 - kerf/2 + offset_45, z_start + offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                            translate([y_divider_pos_x + stock_thickness/2 + kerf/2 - offset_45, z_start + offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        }
                        if(z_start + height < box_height) {
                            translate([y_divider_pos_x - stock_thickness/2 - kerf/2 + offset_45, z_start + height - offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                            translate([y_divider_pos_x + stock_thickness/2 + kerf/2 - offset_45, z_start + height - offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        }
                    }
                }
            }
        }
    }
}

module panel_side_short_flat() {
    difference() {
        cube([box_width, box_height, stock_thickness]);
        
        // Bottom edge slots (odd indices to mate with bottom even fingers)
        for(j = [0 : y_layout[0]-1]) {
            if(j % 2 == 1) {
                finger_info = get_finger_info(j, box_width, y_layout);
                y_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                
                translate([y_start, 0, -5])
                    cube([width, stock_thickness + kerf, stock_thickness + 10]);
            }
        }
        
        // Vertical edge slots
        for(k = [0 : z_layout[0]-1]) {
            finger_info = get_finger_info(k, box_height, z_layout);
            z_start = finger_info[0] - kerf/2;
            height = finger_info[1] + kerf;
            
            if(k % 2 == 0) {
                translate([0, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
                translate([box_width - stock_thickness - kerf, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
            }
        }
        
        // X-divider mortises - all positions
        if(enable_dividers) {
            for(k = [0 : x_divider_z_layout[0]-1]) {
                if(k % 2 == 1) {  // Odd positions to mate with divider fingers
                    finger_info = get_finger_info(k, x_divider_height, x_divider_z_layout);
                    z_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    translate([x_divider_pos_y - stock_thickness/2 - kerf/2, z_start, -5])
                        cube([stock_thickness + kerf, height, stock_thickness + 10]);
                }
            }
        }
        
        // Dog-bone reliefs
        if(dogbone_style == 3) {
            r = bit_diameter / 2;
            offset_45 = r * 0.707;
            
            for(j = [0 : y_layout[0]-1]) {
                if(j % 2 == 1) {
                    finger_info = get_finger_info(j, box_width, y_layout);
                    y_start = finger_info[0] - kerf/2;
                    width = finger_info[1] + kerf;
                    
                    if(y_start > 0) {
                        translate([y_start + offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(y_start + width < box_width) {
                        translate([y_start + width - offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            for(k = [0 : z_layout[0]-1]) {
                if(k % 2 == 0) {
                    finger_info = get_finger_info(k, box_height, z_layout);
                    z_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    if(z_start > 0) {
                        translate([stock_thickness + kerf - offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        translate([box_width - stock_thickness - kerf + offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(z_start + height < box_height) {
                        translate([stock_thickness + kerf - offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        translate([box_width - stock_thickness - kerf + offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            // X-divider mortise dogbones - all mortises
            if(enable_dividers) {
                for(k = [0 : x_divider_z_layout[0]-1]) {
                    if(k % 2 == 1) {  // Only where we have mortises
                        finger_info = get_finger_info(k, x_divider_height, x_divider_z_layout);
                        z_start = finger_info[0] - kerf/2;
                        height = finger_info[1] + kerf;
                        
                        // Mortise dogbones - only at inside corners
                        if(z_start > 0) {
                            translate([x_divider_pos_y - stock_thickness/2 - kerf/2 + offset_45, z_start + offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                            translate([x_divider_pos_y + stock_thickness/2 + kerf/2 - offset_45, z_start + offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        }
                        if(z_start + height < box_height) {
                            translate([x_divider_pos_y - stock_thickness/2 - kerf/2 + offset_45, z_start + height - offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                            translate([x_divider_pos_y + stock_thickness/2 + kerf/2 - offset_45, z_start + height - offset_45, -5])
                                cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                        }
                    }
                }
            }
        }
    }
}

// Additional box panels for 3D assembly
module panel_side_long() {
    difference() {
        cube([box_length, stock_thickness, box_height]);
        
        // Bottom edge slots (odd indices to mate with bottom even fingers)
        for(i = [0 : x_layout[0]-1]) {
            if(i % 2 == 1) {
                finger_info = get_finger_info(i, box_length, x_layout);
                x_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                
                translate([x_start, 0, 0])
                    cube([width, stock_thickness + kerf, stock_thickness]);
            }
        }
        
        // Vertical edge slots
        for(k = [0 : z_layout[0]-1]) {
            finger_info = get_finger_info(k, box_height, z_layout);
            z_start = finger_info[0] - kerf/2;
            height = finger_info[1] + kerf;
            
            if(k % 2 == 1) {
                translate([0, 0, z_start])
                    cube([stock_thickness + kerf, stock_thickness + kerf, height]);
                translate([box_length - stock_thickness - kerf, 0, z_start])
                    cube([stock_thickness + kerf, stock_thickness + kerf, height]);
            }
        }
        
        // Y-divider mortises - all positions
        if(enable_dividers) {
            for(k = [0 : y_divider_z_layout[0]-1]) {
                if(k % 2 == 1) {  // Odd positions to mate with divider fingers
                    finger_info = get_finger_info(k, y_divider_height, y_divider_z_layout);
                    z_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    translate([y_divider_pos_x - stock_thickness/2 - kerf/2, 0, z_start])
                        cube([stock_thickness + kerf, stock_thickness + kerf, height]);
                }
            }
        }
    }
}

module panel_side_short() {
    difference() {
        cube([box_width, stock_thickness, box_height]);
        
        // Bottom edge slots (odd indices to mate with bottom even fingers)
        for(j = [0 : y_layout[0]-1]) {
            if(j % 2 == 1) {
                finger_info = get_finger_info(j, box_width, y_layout);
                y_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                
                translate([y_start, 0, 0])
                    cube([width, stock_thickness + kerf, stock_thickness]);
            }
        }
        
        // Vertical edge slots
        for(k = [0 : z_layout[0]-1]) {
            finger_info = get_finger_info(k, box_height, z_layout);
            z_start = finger_info[0] - kerf/2;
            height = finger_info[1] + kerf;
            
            if(k % 2 == 0) {
                translate([0, 0, z_start])
                    cube([stock_thickness + kerf, stock_thickness + kerf, height]);
                translate([box_width - stock_thickness - kerf, 0, z_start])
                    cube([stock_thickness + kerf, stock_thickness + kerf, height]);
            }
        }
        
        // X-divider mortises - all positions
        if(enable_dividers) {
            for(k = [0 : x_divider_z_layout[0]-1]) {
                if(k % 2 == 1) {  // Odd positions to mate with divider fingers
                    finger_info = get_finger_info(k, x_divider_height, x_divider_z_layout);
                    z_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    translate([x_divider_pos_y - stock_thickness/2 - kerf/2, 0, z_start])
                        cube([stock_thickness + kerf, stock_thickness + kerf, height]);
                }
            }
        }
    }
}

//---------------------------------------------------------------
// DIVIDER PANEL MODULES ---------------------------------------
//---------------------------------------------------------------

// X-direction divider (runs parallel to X-axis)
module panel_x_divider() {
    difference() {
        cube([x_divider_length, stock_thickness, x_divider_height]);
        
        // Create fingers by cutting away gaps - all bottom fingers except ends
        for(i = [0 : x_divider_x_layout[0]-1]) {
            finger_info = get_finger_info(i, x_divider_length, x_divider_x_layout);
            x_start = finger_info[0] - kerf/2;
            width = finger_info[1] + kerf;
            
            // Cut away positions where we DON'T want fingers
            // Skip bottom fingers at ends (i == 0 or i == count-1) to avoid side finger collision
            is_end_finger = (i == 0 || i == x_divider_x_layout[0]-1);
            if(i % 2 == 0 || is_end_finger) {
                translate([x_start, 0, 0])
                    cube([width, stock_thickness + kerf, stock_thickness]);
            }
        }
        
        // Side edge fingers - positioned in CENTER area regardless of pattern  
        // FIXED: Cut away ends (k % 2 == 0) to leave middle finger (k % 2 == 1)
        for(k = [0 : x_divider_z_layout[0]-1]) {
            if(k % 2 == 0) {
                finger_info = get_finger_info(k, x_divider_height, x_divider_z_layout);
                z_start = finger_info[0] - kerf/2;
                height = finger_info[1] + kerf;
                
                // Force fingers into center area - ignore original position if too close to edges
                center_start = divider_edge_margin;
                center_end = x_divider_height - divider_edge_margin;
                center_height = center_end - center_start;
                
                // Only create finger if it can fit entirely in center area
                if(height <= center_height) {
                    // Center the finger within the available center area
                    finger_start = center_start + (center_height - height) / 2;
                    finger_height = height;
                    
                    translate([0, 0, finger_start])
                        cube([stock_thickness + kerf, stock_thickness + kerf, finger_height]);
                    translate([x_divider_length - stock_thickness - kerf, 0, finger_start])
                        cube([stock_thickness + kerf, stock_thickness + kerf, finger_height]);
                }
            }
        }
        
        // Half-lap slot for intersecting Y-divider (top half) 
        if(enable_dividers) {
            // Half-lap at true center of X-divider
            x_intersect = x_divider_length / 2;
            translate([x_intersect - stock_thickness/2 - kerf/2, 0, x_divider_height/2])
                cube([stock_thickness + kerf, stock_thickness + kerf, x_divider_height/2]);
        }
    }
}

// X-direction divider flat layout
module panel_x_divider_flat() {
    difference() {
        cube([x_divider_length, x_divider_height, stock_thickness]);
        
        // Bottom edge fingers - all except end fingers
        for(i = [0 : x_divider_x_layout[0]-1]) {
            finger_info = get_finger_info(i, x_divider_length, x_divider_x_layout);
            x_start = finger_info[0] - kerf/2;
            width = finger_info[1] + kerf;
            
            // Cut away positions where we DON'T want fingers
            // Skip bottom fingers at ends to avoid collision with side fingers
            is_end_finger = (i == 0 || i == x_divider_x_layout[0]-1);
            if(i % 2 == 0 || is_end_finger) {
                translate([x_start, 0, -5])
                    cube([width, stock_thickness + kerf, stock_thickness + 10]);
            }
        }
        
        // Side edge fingers - cut away ends to leave middle finger
        for(k = [0 : x_divider_z_layout[0]-1]) {
            finger_info = get_finger_info(k, x_divider_height, x_divider_z_layout);
            z_start = finger_info[0] - kerf/2;
            height = finger_info[1] + kerf;
            
            // Cut away material at even positions (0, 2, 4...) to leave odd positions (1, 3, 5...)
            if(k % 2 == 0) {
                // Left side slot
                translate([0, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
                // Right side slot  
                translate([x_divider_length - stock_thickness - kerf, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
            }
        }
        
        // Half-lap slot for intersecting Y-divider
        if(enable_dividers) {
            // Half-lap should be at true center of this divider
            x_intersect = x_divider_length / 2;  // True center of X-divider
            translate([x_intersect - stock_thickness/2 - kerf/2, x_divider_height/2, -5])
                cube([stock_thickness + kerf, x_divider_height/2, stock_thickness + 10]);
        }
        
        // Dog-bone reliefs
        if(dogbone_style == 3) {
            r = bit_diameter / 2;
            offset_45 = r * 0.707;
            
            // Bottom edge dogbones - simple logic for actual slots
            for(i = [0 : x_divider_x_layout[0]-1]) {
                finger_info = get_finger_info(i, x_divider_length, x_divider_x_layout);
                x_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                
                // Only add dogbones where we have actual slots (not end fingers)
                is_end_finger = (i == 0 || i == x_divider_x_layout[0]-1);
                if(i % 2 == 0 && !is_end_finger) {
                    // Only add dogbones at corners that aren't at the panel edge
                    if(x_start > 0) {
                        translate([x_start + offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(x_start + width < x_divider_length) {
                        translate([x_start + width - offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            // Side edge slot dogbones - only at inside corners
            for(k = [0 : x_divider_z_layout[0]-1]) {
                if(k % 2 == 0) {  // Only where we cut slots
                    finger_info = get_finger_info(k, x_divider_height, x_divider_z_layout);
                    z_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    // Left side slot dogbones - only inside corners (right side of slot)
                    if(z_start > 0) {
                        translate([stock_thickness + kerf - offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(z_start + height < x_divider_height) {
                        translate([stock_thickness + kerf - offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    
                    // Right side slot dogbones - only inside corners (left side of slot)
                    if(z_start > 0) {
                        translate([x_divider_length - stock_thickness - kerf + offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(z_start + height < x_divider_height) {
                        translate([x_divider_length - stock_thickness - kerf + offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            // Half-lap dogbones - only at inside corners
            if(enable_dividers) {
                x_intersect = x_divider_length / 2;
                // Only add dogbones at corners that aren't at panel edges
                if(x_intersect > stock_thickness) {
                    translate([x_intersect - stock_thickness/2 - kerf/2 + offset_45, x_divider_height/2 + offset_45, -5])
                        cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                }
                if(x_intersect < x_divider_length - stock_thickness) {
                    translate([x_intersect + stock_thickness/2 + kerf/2 - offset_45, x_divider_height/2 + offset_45, -5])
                        cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                }
            }
        }
    }
}

// Y-direction divider (runs parallel to Y-axis)
module panel_y_divider() {
    difference() {
        cube([stock_thickness, y_divider_length, y_divider_height]);
        
        // Create fingers by cutting away gaps - all bottom fingers except ends
        for(j = [0 : y_divider_y_layout[0]-1]) {
            finger_info = get_finger_info(j, y_divider_length, y_divider_y_layout);
            y_start = finger_info[0] - kerf/2;
            width = finger_info[1] + kerf;
            
            // Cut away positions where we DON'T want fingers
            // Skip bottom fingers at ends (j == 0 or j == count-1) to avoid side finger collision
            is_end_finger = (j == 0 || j == y_divider_y_layout[0]-1);
            if(j % 2 == 0 || is_end_finger) {
                translate([0, y_start, 0])
                    cube([stock_thickness + kerf, width, stock_thickness]);
            }
        }
        
        // Side edge fingers - cut away ends to leave middle finger  
        for(k = [0 : y_divider_z_layout[0]-1]) {
            finger_info = get_finger_info(k, y_divider_height, y_divider_z_layout);
            z_start = finger_info[0] - kerf/2;
            height = finger_info[1] + kerf;
            
            // Cut away material at even positions (0, 2, 4...) to leave odd positions (1, 3, 5...)
            if(k % 2 == 0) {
                translate([0, 0, z_start])
                    cube([stock_thickness + kerf, stock_thickness + kerf, height]);
                translate([0, y_divider_length - stock_thickness - kerf, z_start])
                    cube([stock_thickness + kerf, stock_thickness + kerf, height]);
            }
        }
        
        // Half-lap slot for intersecting X-divider (bottom half)
        if(enable_dividers) {
            // Half-lap at true center of Y-divider
            y_intersect = y_divider_length / 2;
            translate([0, y_intersect - stock_thickness/2 - kerf/2, 0])
                cube([stock_thickness + kerf, stock_thickness + kerf, y_divider_height/2]);
        }
    }
}

// Y-direction divider flat layout
module panel_y_divider_flat() {
    difference() {
        cube([y_divider_length, y_divider_height, stock_thickness]);
        
        // Bottom edge fingers - all except end fingers
        for(j = [0 : y_divider_y_layout[0]-1]) {
            finger_info = get_finger_info(j, y_divider_length, y_divider_y_layout);
            y_start = finger_info[0] - kerf/2;
            width = finger_info[1] + kerf;
            
            // Cut away positions where we DON'T want fingers
            // Skip bottom fingers at ends to avoid collision with side fingers  
            is_end_finger = (j == 0 || j == y_divider_y_layout[0]-1);
            if(j % 2 == 0 || is_end_finger) {
                translate([y_start, 0, -5])
                    cube([width, stock_thickness + kerf, stock_thickness + 10]);
            }
        }
        
        // Side edge fingers - cut away ends to leave middle finger
        for(k = [0 : y_divider_z_layout[0]-1]) {
            finger_info = get_finger_info(k, y_divider_height, y_divider_z_layout);
            z_start = finger_info[0] - kerf/2;
            height = finger_info[1] + kerf;
            
            // Cut away material at even positions (0, 2, 4...) to leave odd positions (1, 3, 5...)
            if(k % 2 == 0) {
                // Front side slot
                translate([0, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
                // Back side slot
                translate([y_divider_length - stock_thickness - kerf, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
            }
        }
        
        // Half-lap slot for intersecting X-divider (bottom half)
        if(enable_dividers) {
            // Half-lap should be at true center of this divider  
            y_intersect = y_divider_length / 2;  // True center of Y-divider
            translate([y_intersect - stock_thickness/2 - kerf/2, 0, -5])
                cube([stock_thickness + kerf, y_divider_height/2, stock_thickness + 10]);
        }
        
        // Dog-bone reliefs
        if(dogbone_style == 3) {
            r = bit_diameter / 2;
            offset_45 = r * 0.707;
            
            // Bottom edge dogbones - simple logic for actual slots
            for(j = [0 : y_divider_y_layout[0]-1]) {
                finger_info = get_finger_info(j, y_divider_length, y_divider_y_layout);
                y_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                
                // Only add dogbones where we have actual slots (not end fingers)
                is_end_finger = (j == 0 || j == y_divider_y_layout[0]-1);
                if(j % 2 == 0 && !is_end_finger) {
                    // Only add dogbones at corners that aren't at the panel edge
                    if(y_start > 0) {
                        translate([y_start + offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(y_start + width < y_divider_length) {
                        translate([y_start + width - offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            // Side edge slot dogbones - only at inside corners  
            for(k = [0 : y_divider_z_layout[0]-1]) {
                if(k % 2 == 0) {  // Only where we cut slots
                    finger_info = get_finger_info(k, y_divider_height, y_divider_z_layout);
                    z_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    // Front side slot dogbones - only at inside corners (back side of slot)
                    if(z_start > 0) {
                        translate([stock_thickness + kerf - offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(z_start + height < y_divider_height) {
                        translate([stock_thickness + kerf - offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    
                    // Back side slot dogbones - only at inside corners (front side of slot)
                    if(z_start > 0) {
                        translate([y_divider_length - stock_thickness - kerf + offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(z_start + height < y_divider_height) {
                        translate([y_divider_length - stock_thickness - kerf + offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            // Half-lap dogbones - only at inside corners
            if(enable_dividers) {
                y_intersect = y_divider_length / 2;
                // Only add dogbones at corners that aren't at panel edges  
                if(y_intersect > stock_thickness) {
                    translate([y_intersect - stock_thickness/2 - kerf/2 + offset_45, y_divider_height/2 - offset_45, -5])
                        cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                }
                if(y_intersect < y_divider_length - stock_thickness) {
                    translate([y_intersect + stock_thickness/2 + kerf/2 - offset_45, y_divider_height/2 - offset_45, -5])
                        cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                }
            }
        }
    }
}

//---------------------------------------------------------------
// LID PANEL MODULES -------------------------------------------
//---------------------------------------------------------------
module panel_lid_top() {
    difference() {
        cube([lid_length, lid_width, stock_thickness]);
        
        // X-direction slots
        for(i = [0 : lid_x_layout[0]-1]) {
            if(i % 2 == 0) {
                finger_info = get_finger_info(i, lid_length, lid_x_layout);
                x_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                
                translate([x_start, 0, -5])
                    cube([width, stock_thickness + kerf, stock_thickness + 10]);
                translate([x_start, lid_width - stock_thickness - kerf, -5])
                    cube([width, stock_thickness + kerf, stock_thickness + 10]);
            }
        }
        
        // Y-direction slots
        for(j = [0 : lid_y_layout[0]-1]) {
            if(j % 2 == 0) {
                finger_info = get_finger_info(j, lid_width, lid_y_layout);
                y_start = finger_info[0] - kerf/2;
                height = finger_info[1] + kerf;
                
                translate([0, y_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
                translate([lid_length - stock_thickness - kerf, y_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
            }
        }
        
        // Dogbones for all slots - only at inside corners
        if(dogbone_style == 3) {
            r = bit_diameter / 2;
            offset_45 = r * 0.707;
            
            // X-direction slot dogbones
            for(i = [0 : lid_x_layout[0]-1]) {
                if(i % 2 == 0) {
                    finger_info = get_finger_info(i, lid_length, lid_x_layout);
                    x_start = finger_info[0] - kerf/2;
                    width = finger_info[1] + kerf;
                    
                    // Front edge slot dogbones
                    if(x_start > 0) {
                        translate([x_start + offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(x_start + width < lid_length) {
                        translate([x_start + width - offset_45, stock_thickness + kerf - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    
                    // Back edge slot dogbones
                    if(x_start > 0) {
                        translate([x_start + offset_45, lid_width - stock_thickness - kerf + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(x_start + width < lid_length) {
                        translate([x_start + width - offset_45, lid_width - stock_thickness - kerf + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            // Y-direction slot dogbones
            for(j = [0 : lid_y_layout[0]-1]) {
                if(j % 2 == 0) {
                    finger_info = get_finger_info(j, lid_width, lid_y_layout);
                    y_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    // Left edge slot dogbones
                    if(y_start > 0) {
                        translate([stock_thickness + kerf - offset_45, y_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(y_start + height < lid_width) {
                        translate([stock_thickness + kerf - offset_45, y_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    
                    // Right edge slot dogbones
                    if(y_start > 0) {
                        translate([lid_length - stock_thickness - kerf + offset_45, y_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(y_start + height < lid_width) {
                        translate([lid_length - stock_thickness - kerf + offset_45, y_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
        }
    }
}

module panel_lid_side_long_flat() {
    difference() {
        cube([lid_length, lid_height, stock_thickness]);
        
        for(i = [0 : lid_x_layout[0]-1]) {
            if(i % 2 == 1) {
                finger_info = get_finger_info(i, lid_length, lid_x_layout);
                x_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                translate([x_start, lid_height - stock_thickness - kerf, -5])
                    cube([width, stock_thickness + kerf, stock_thickness + 10]);
            }
        }
        
        for(k = [0 : lid_z_layout[0]-1]) {
            finger_info = get_finger_info(k, lid_height, lid_z_layout);
            z_start = finger_info[0] - kerf/2;
            height = finger_info[1] + kerf;
            
            if(k % 2 == 1) {
                translate([0, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
                translate([lid_length - stock_thickness - kerf, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
            }
        }
        
        // Dogbones for all slots - only at inside corners
        if(dogbone_style == 3) {
            r = bit_diameter / 2;
            offset_45 = r * 0.707;
            
            // Top edge slot dogbones
            for(i = [0 : lid_x_layout[0]-1]) {
                if(i % 2 == 1) {
                    finger_info = get_finger_info(i, lid_length, lid_x_layout);
                    x_start = finger_info[0] - kerf/2;
                    width = finger_info[1] + kerf;
                    
                    if(x_start > 0) {
                        translate([x_start + offset_45, lid_height - stock_thickness - kerf + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(x_start + width < lid_length) {
                        translate([x_start + width - offset_45, lid_height - stock_thickness - kerf + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            // Side edge slot dogbones - only at inside corners
            for(k = [0 : lid_z_layout[0]-1]) {
                if(k % 2 == 1) {
                    finger_info = get_finger_info(k, lid_height, lid_z_layout);
                    z_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    // Left side slot dogbones - only inside corners (right side of slot)
                    if(z_start > 0) {
                        translate([stock_thickness + kerf - offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(z_start + height < lid_height) {
                        translate([stock_thickness + kerf - offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    
                    // Right side slot dogbones - only inside corners (left side of slot)
                    if(z_start > 0) {
                        translate([lid_length - stock_thickness - kerf + offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(z_start + height < lid_height) {
                        translate([lid_length - stock_thickness - kerf + offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
        }
    }
}

module panel_lid_side_short_flat() {
    difference() {
        cube([lid_width, lid_height, stock_thickness]);
        
        for(j = [0 : lid_y_layout[0]-1]) {
            if(j % 2 == 1) {
                finger_info = get_finger_info(j, lid_width, lid_y_layout);
                y_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                translate([y_start, lid_height - stock_thickness - kerf, -5])
                    cube([width, stock_thickness + kerf, stock_thickness + 10]);
            }
        }
        
        for(k = [0 : lid_z_layout[0]-1]) {
            finger_info = get_finger_info(k, lid_height, lid_z_layout);
            z_start = finger_info[0] - kerf/2;
            height = finger_info[1] + kerf;
            
            if(k % 2 == 0) {
                translate([0, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
                translate([lid_width - stock_thickness - kerf, z_start, -5])
                    cube([stock_thickness + kerf, height, stock_thickness + 10]);
            }
        }
        
        // Dogbones for all slots - only at inside corners
        if(dogbone_style == 3) {
            r = bit_diameter / 2;
            offset_45 = r * 0.707;
            
            // Top edge slot dogbones
            for(j = [0 : lid_y_layout[0]-1]) {
                if(j % 2 == 1) {
                    finger_info = get_finger_info(j, lid_width, lid_y_layout);
                    y_start = finger_info[0] - kerf/2;
                    width = finger_info[1] + kerf;
                    
                    if(y_start > 0) {
                        translate([y_start + offset_45, lid_height - stock_thickness - kerf + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(y_start + width < lid_width) {
                        translate([y_start + width - offset_45, lid_height - stock_thickness - kerf + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
            
            // Side edge slot dogbones - only at inside corners
            for(k = [0 : lid_z_layout[0]-1]) {
                if(k % 2 == 0) {
                    finger_info = get_finger_info(k, lid_height, lid_z_layout);
                    z_start = finger_info[0] - kerf/2;
                    height = finger_info[1] + kerf;
                    
                    // Left side slot dogbones - only inside corners (right side of slot)
                    if(z_start > 0) {
                        translate([stock_thickness + kerf - offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(z_start + height < lid_height) {
                        translate([stock_thickness + kerf - offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    
                    // Right side slot dogbones - only inside corners (left side of slot)
                    if(z_start > 0) {
                        translate([lid_width - stock_thickness - kerf + offset_45, z_start + offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                    if(z_start + height < lid_height) {
                        translate([lid_width - stock_thickness - kerf + offset_45, z_start + height - offset_45, -5])
                            cylinder(h = stock_thickness + 10, d = bit_diameter, $fn = 24);
                    }
                }
            }
        }
    }
}

// 3D lid modules
module panel_lid_side_long() {
    difference() {
        cube([lid_length, stock_thickness, lid_height]);
        
        for(i = [0 : lid_x_layout[0]-1]) {
            if(i % 2 == 1) {
                finger_info = get_finger_info(i, lid_length, lid_x_layout);
                x_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                translate([x_start, 0, lid_height - stock_thickness])
                    cube([width, stock_thickness + kerf, stock_thickness]);
            }
        }
        
        for(k = [0 : lid_z_layout[0]-1]) {
            finger_info = get_finger_info(k, lid_height, lid_z_layout);
            z_start = finger_info[0] - kerf/2;
            height = finger_info[1] + kerf;
            
            if(k % 2 == 1) {
                translate([0, 0, z_start])
                    cube([stock_thickness + kerf, stock_thickness + kerf, height]);
                translate([lid_length - stock_thickness - kerf, 0, z_start])
                    cube([stock_thickness + kerf, stock_thickness + kerf, height]);
            }
        }
    }
}

module panel_lid_side_short() {
    difference() {
        cube([lid_width, stock_thickness, lid_height]);
        
        for(j = [0 : lid_y_layout[0]-1]) {
            if(j % 2 == 1) {
                finger_info = get_finger_info(j, lid_width, lid_y_layout);
                y_start = finger_info[0] - kerf/2;
                width = finger_info[1] + kerf;
                translate([y_start, 0, lid_height - stock_thickness])
                    cube([width, stock_thickness + kerf, stock_thickness]);
            }
        }
        
        for(k = [0 : lid_z_layout[0]-1]) {
            finger_info = get_finger_info(k, lid_height, lid_z_layout);
            z_start = finger_info[0] - kerf/2;
            height = finger_info[1] + kerf;
            
            if(k % 2 == 0) {
                translate([0, 0, z_start])
                    cube([stock_thickness + kerf, stock_thickness + kerf, height]);
                translate([lid_width - stock_thickness - kerf, 0, z_start])
                    cube([stock_thickness + kerf, stock_thickness + kerf, height]);
            }
        }
    }
}

//---------------------------------------------------------------
// MAIN ASSEMBLY ------------------------------------------------
//---------------------------------------------------------------
if(layout_mode == 0) {
    // 3D Assembly preview
    if(enable_box_bottom) color("LightBlue", 0.9) panel_bottom();
    if(enable_box_front) color("LightGreen", 0.9) translate([0, 0, 0]) panel_side_long();
    if(enable_box_back) color("LightGreen", 0.9) translate([0, box_width - stock_thickness, 0]) panel_side_long();
    if(enable_box_left) color("LightCoral", 0.9) translate([stock_thickness, 0, 0]) rotate([0, 0, 90]) panel_side_short();
    if(enable_box_right) color("LightCoral", 0.9) translate([box_length, 0, 0]) rotate([0, 0, 90]) panel_side_short();
    
    // Dividers
    if(enable_dividers) {
        if(enable_x_divider) {
            color("Orange", 0.8) 
                translate([0, x_divider_pos_y - stock_thickness/2, 0])
                panel_x_divider();
        }
        
        if(enable_y_divider) {
            color("Purple", 0.8) 
                translate([y_divider_pos_x - stock_thickness/2, 0, 0])
                panel_y_divider();
        }
    }
    
    // Lid assembly
    if(enable_lid) {
        lid_z_offset = box_height;
        lid_x_offset = -lid_tolerance - stock_thickness;
        lid_y_offset = -lid_tolerance - stock_thickness;
        
        translate([lid_x_offset, lid_y_offset, lid_z_offset]) {
            if(enable_lid_top) {
                color("DodgerBlue", 0.9) translate([0, 0, lid_height - stock_thickness]) panel_lid_top();
            }
            if(enable_lid_front) {
                color("MediumSeaGreen", 0.9) translate([0, 0, 0]) panel_lid_side_long();
            }
            if(enable_lid_back) {
                color("MediumSeaGreen", 0.9) translate([0, lid_width - stock_thickness, 0]) panel_lid_side_long();
            }
            if(enable_lid_left) {
                color("Salmon", 0.9) translate([stock_thickness, 0, 0]) rotate([0, 0, 90]) panel_lid_side_short();
            }
            if(enable_lid_right) {
                color("Salmon", 0.9) translate([lid_length, 0, 0]) rotate([0, 0, 90]) panel_lid_side_short();
            }
        }
    }
} else {
    // FLAT LAYOUT FOR CNC CUTTING
    spacing = part_spacing;
    
    // Calculate all X positions upfront (no variable reassignment)
    box_bottom_x = enable_box_bottom ? 0 : -999;
    box_front_x = enable_box_front ? (enable_box_bottom ? box_length + spacing : 0) : -999;
    box_back_x = enable_box_back ? (box_front_x >= 0 ? box_front_x + box_length + spacing : 
                                   (enable_box_bottom ? box_length + spacing : 0)) : -999;
    box_left_x = enable_box_left ? (box_back_x >= 0 ? box_back_x + box_length + spacing :
                                   (box_front_x >= 0 ? box_front_x + box_length + spacing :
                                   (enable_box_bottom ? box_length + spacing : 0))) : -999;
    box_right_x = enable_box_right ? (box_left_x >= 0 ? box_left_x + box_width + spacing :
                                     (box_back_x >= 0 ? box_back_x + box_length + spacing :
                                     (box_front_x >= 0 ? box_front_x + box_length + spacing :
                                     (enable_box_bottom ? box_length + spacing : 0)))) : -999;
    
    // ROW 1: BOX PARTS
    row1_y = 0;
    row1_height = max(box_width, box_height);
    
    if(enable_box_bottom) {
        translate([box_bottom_x, row1_y, 0]) panel_bottom();
    }
    if(enable_box_front) {
        translate([box_front_x, row1_y, 0]) panel_side_long_flat();
    }
    if(enable_box_back) {
        translate([box_back_x, row1_y, 0]) panel_side_long_flat();
    }
    if(enable_box_left) {
        translate([box_left_x, row1_y, 0]) panel_side_short_flat();
    }
    if(enable_box_right) {
        translate([box_right_x, row1_y, 0]) panel_side_short_flat();
    }
    
    // ROW 2: DIVIDERS
    row2_y = row1_height + spacing;
    row2_height = enable_dividers && (enable_x_divider || enable_y_divider) ? max(x_divider_height, y_divider_height) : 0;
    
    if(enable_dividers) {
        divider_x_x = enable_x_divider ? 0 : -999;
        divider_y_x = enable_y_divider ? (enable_x_divider ? x_divider_length + spacing : 0) : -999;
        
        if(enable_x_divider) {
            translate([divider_x_x, row2_y, 0]) panel_x_divider_flat();
        }
        if(enable_y_divider) {
            translate([divider_y_x, row2_y, 0]) panel_y_divider_flat();
        }
    }
    
    // ROW 3: LID PARTS  
    row3_y = enable_dividers && (enable_x_divider || enable_y_divider) ? (row2_y + row2_height + spacing) : row2_y;
    row3_height = enable_lid ? max(lid_width, lid_height) : 0;
    
    if(enable_lid) {
        // Calculate lid part positions
        lid_top_x = enable_lid_top ? 0 : -999;
        lid_front_x = enable_lid_front ? (enable_lid_top ? lid_length + spacing : 0) : -999;
        lid_back_x = enable_lid_back ? (lid_front_x >= 0 ? lid_front_x + lid_length + spacing :
                                       (enable_lid_top ? lid_length + spacing : 0)) : -999;
        
        if(enable_lid_top) {
            translate([lid_top_x, row3_y, 0]) panel_lid_top();
        }
        if(enable_lid_front) {
            translate([lid_front_x, row3_y, 0]) panel_lid_side_long_flat();
        }
        if(enable_lid_back) {
            translate([lid_back_x, row3_y, 0]) panel_lid_side_long_flat();
        }
        
        // ROW 4: LID SHORT SIDES
        row4_y = row3_y + row3_height + spacing;
        
        if(enable_lid_left || enable_lid_right) {
            lid_left_x = enable_lid_left ? 0 : -999;
            lid_right_x = enable_lid_right ? (enable_lid_left ? lid_width + spacing : 0) : -999;
            
            if(enable_lid_left) {
                translate([lid_left_x, row4_y, 0]) panel_lid_side_short_flat();
            }
            if(enable_lid_right) {
                translate([lid_right_x, row4_y, 0]) panel_lid_side_short_flat();
            }
        }
    }
}

// Debug output
echo("=== BOX FINGER LAYOUTS ===");
echo(str("X (", box_length, "mm): ", x_layout[0], " fingers"));
echo(str("Y (", box_width, "mm): ", y_layout[0], " fingers"));
echo(str("Z (", box_height, "mm): ", z_layout[0], " fingers"));

if(enable_dividers) {
    echo("=== DIVIDER FINGER LAYOUTS ===");
    echo(str("X-divider length (", x_divider_length, "mm): ", x_divider_x_layout[0], " fingers"));
    echo(str("X-divider height (", x_divider_height, "mm): ", x_divider_z_layout[0], " fingers"));
    echo(str("Y-divider length (", y_divider_length, "mm): ", y_divider_y_layout[0], " fingers"));
    echo(str("Y-divider height (", y_divider_height, "mm): ", y_divider_z_layout[0], " fingers"));
    echo(str("X-divider at Y = ", x_divider_pos_y, "mm"));
    echo(str("Y-divider at X = ", y_divider_pos_x, "mm"));
    echo("=== HALF-LAP JOINT POSITIONS (CORRECTED) ===");
    echo(str("X-divider half-lap at X = ", x_divider_length/2, "mm (true center of ", x_divider_length, "mm divider)"));
    echo(str("Y-divider half-lap at X = ", y_divider_length/2, "mm (true center of ", y_divider_length, "mm divider)"));
    echo("=== DIVIDER RENDERING ===");
    echo(str("X-divider enabled: ", enable_x_divider));
    echo(str("Y-divider enabled: ", enable_y_divider));
}

if(enable_lid) {
    echo("=== LID FINGER LAYOUTS ===");
    echo(str("Lid X (", lid_length, "mm): ", lid_x_layout[0], " fingers"));
    echo(str("Lid Y (", lid_width, "mm): ", lid_y_layout[0], " fingers"));
    echo(str("Lid Z (", lid_height, "mm): ", lid_z_layout[0], " fingers"));
}

echo(str("Dogbone style: ", dogbone_style));

// FIXED DOGBONE ISSUES:
// 1. X-divider side edge slots: Now only places 2 dogbones per slot (at inside corners only)
// 2. Y-divider bottom edge slots: Now only places 2 dogbones per slot (at inside corners only) 
// 3. X-divider bottom edge slots: Now follows same pattern as other panels (only corners not at panel edge)
// 4. All divider dogbones: Now consistent with main panel dogbone logic - only at inside corners, not at panel edges
// 5. Half-lap dogbones: Only at corners that aren't at panel edges