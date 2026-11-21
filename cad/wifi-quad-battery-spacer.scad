// Print two in PETG. Reference support geometry, verify donor mounting points.
spacer_height = 4.5;
spacer_outer_diameter = 5.2;
spacer_inner_diameter = 2.2;
$fn = 32;
difference() {
    cylinder(h = spacer_height, d = spacer_outer_diameter);
    translate([0, 0, -0.02])
        cylinder(h = spacer_height + 0.04, d = spacer_inner_diameter);
}
