// E88-style camera cover concept. Units are millimetres.
// Default dimensions are placeholders. Match the particular donor airframe.
// Coordinate origin: centre of the leading edge at the mounting plane.
// X runs towards the tail. Z runs upwards.

cover_length = 28;
shoulder_width = 28;
cover_height = 11;
wall = 0.65;
rim_wall = 0.90;
rim_height = 1.20;

// Set true to preview and export only the lower fit gauge.
fit_gauge = false;

// Clear opening centred on the original lens.
lens_width = 13;
lens_height = 8;
lens_center_y = 0;
lens_center_z = 5.5;

// Add holes only after measuring donor mounting points.
// Set to [[x, y], [x, y], ...] to enable mounting bosses with pilots.
mount_points = [];
pilot_diameter = 1.7;
boss_diameter = 5;
slice = 0.025;
$fn = 40;

module planform() {
    polygon([
        [0, -0.30 * shoulder_width],
        [0.13 * cover_length, -0.50 * shoulder_width],
        [0.35 * cover_length, -0.46 * shoulder_width],
        [0.93 * cover_length, -0.31 * shoulder_width],
        [cover_length, -0.21 * shoulder_width],
        [cover_length, 0.21 * shoulder_width],
        [0.93 * cover_length, 0.31 * shoulder_width],
        [0.35 * cover_length, 0.46 * shoulder_width],
        [0.13 * cover_length, 0.50 * shoulder_width],
        [0, 0.30 * shoulder_width]
    ]);
}

module section(z, inset) {
    translate([0, 0, z])
        linear_extrude(slice)
            offset(delta = -inset) planform();
}

module outer() {
    hull() {
        section(0, 0);
        section(0.68 * cover_height, 0.5);
        section(cover_height - slice, 4);
    }
}

module cavity() {
    hull() {
        section(-1, wall);
        section(0.68 * cover_height, 0.5 + wall);
        section(cover_height - wall - slice, 4 + wall);
    }
}

module lower_rim_cavity() {
    hull() {
        section(-1, rim_wall);
        section(rim_height + slice, rim_wall);
    }
}

module interior() {
    // Retain extra material in the short lower rim only.
    union() {
        intersection() { cavity(); lower_rim_cavity(); }
        intersection() {
            cavity();
            translate([-cover_length, -shoulder_width, rim_height])
                cube([3 * cover_length, 2 * shoulder_width, cover_height]);
        }
    }
}

module cover() {
    difference() {
        union() {
            difference() { outer(); interior(); }
            intersection() {
                outer();
                union() {
                    for (p = mount_points)
                        translate([p[0], p[1], 0])
                            cylinder(h = cover_height, d = boss_diameter);
                }
            }
        }
        // Flare the cut toward the front to reduce corner vignetting.
        hull() {
            translate([-1, lens_center_y - lens_width / 2 - 1.2,
                           lens_center_z - lens_height / 2 - 0.8])
                cube([slice, lens_width + 2.4, lens_height + 1.6]);
            translate([8, lens_center_y - lens_width / 2,
                       lens_center_z - lens_height / 2])
                cube([slice, lens_width, lens_height]);
        }
        for (p = mount_points)
            translate([p[0], p[1], -slice])
                cylinder(h = cover_height - wall, d = pilot_diameter);
    }
}

assert(cover_length > 20 && shoulder_width > 14 && cover_height > 5);
assert(wall > 0 && wall < 2);
assert(rim_wall >= wall && rim_height > 0 && rim_height < cover_height / 2);
assert(lens_center_z - lens_height / 2 - 0.8 > 0);
assert(lens_center_z + lens_height / 2 < cover_height - wall);
// V0.7 mounting ears and open-bottom front cut. Reference fit, not a measured lens.
module mounted_cover() {
  difference() {
    union() {
      difference() { cover(); translate([-1,-8.6,-1]) cube([9,17.2,11]); }
      for(y=[-14,14]) translate([8,y,0]) cylinder(h=2,d=6.4,$fn=48);
    }
    for(y=[-14,14]) translate([8,y,-1]) cylinder(h=4,d=2.2,$fn=48);
  }
}
if(fit_gauge) intersection() { mounted_cover(); translate([-20,-40,0]) cube([80,80,1.2]); }
else mounted_cover();
