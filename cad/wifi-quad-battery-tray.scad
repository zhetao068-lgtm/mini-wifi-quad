// Half-open PETG battery tray, assembly-fit prototype. Dimensions in mm.
// X follows battery length (cable at -X), Y is across, Z is upwards.
// The battery body dimensions exclude the cable and plug.
pack_length = 48;
pack_width = 32;
pack_height = 12; // Fit reference. Battery is retained by a separate strap.
clearance = 0.3; // On each face in the XY plane.
rail = 1.6;
floor_thickness = 1.2;
total_height = 3.0;
strap_slot_length = 8.8;
strap_slot_width = 2.4;
mount_pitch = 40.4;
mount_hole_diameter = 2.2;
mount_pad_diameter = 7.2;
spacer_height = 4.5;
spacer_outer_diameter = 5.2;
spacer_inner_diameter = 2.2;
corner = 2.0;
epsilon = 0.025;
$fn = 24;

pocket_length = pack_length + 2 * clearance;
pocket_width = pack_width + 2 * clearance;
outer_length = pocket_length + 2 * rail;
outer_width = pocket_width + 2 * rail;
ear_x = outer_length * 0.26;
ear_y = outer_width / 2 + 2;
ear_length = strap_slot_length + 4.4;
ear_width = strap_slot_width + 3.2;
window_x = outer_length * 0.23;
window_length = outer_length * 0.366;
window_width = outer_width - 7.8;

module round_rect(length, width, radius) {
    offset(r = radius)
        square([length - 2 * radius, width - 2 * radius], center = true);
}

module floor_shape() {
    difference() {
        union() {
            round_rect(outer_length, outer_width, corner);
            for (x = [-ear_x, ear_x], y = [-ear_y, ear_y])
                translate([x, y]) round_rect(ear_length, ear_width, 1.3);
            for (y = [-mount_pitch / 2, mount_pitch / 2])
                translate([0, y]) circle(d = mount_pad_diameter);
        }
        for (x = [-window_x, window_x])
            translate([x, 0]) round_rect(window_length, window_width, 1.6);
        for (x = [-ear_x, ear_x], y = [-ear_y, ear_y])
            translate([x, y + sign(y) * 0.5])
                round_rect(strap_slot_length, strap_slot_width, 0.6);
        // M2 holes sit outside the battery body. Match donor supports before use.
        for (y = [-mount_pitch / 2, mount_pitch / 2])
            translate([0, y]) circle(d = mount_hole_diameter);
    }
}

module rails_shape() {
    difference() {
        round_rect(outer_length, outer_width, corner);
        round_rect(pocket_length, pocket_width, 0.3);
        // Open cable exit on the front rim and the opposite rim.
        for (x = [-outer_length / 2, outer_length / 2])
            translate([x, 0]) square([rail * 3, 12], center = true);
    }
}

assert(pack_length >= 34 && pack_width >= 22);
assert(total_height > floor_thickness && floor_thickness >= 1);
assert(mount_pitch / 2 - 2.0 >= pack_width / 2 + 1.0);
assert(mount_pitch / 2 - mount_pad_diameter / 2 < outer_width / 2);
assert(mount_pad_diameter > spacer_outer_diameter);

union() {
    linear_extrude(floor_thickness) floor_shape();
    translate([0, 0, floor_thickness - epsilon])
        linear_extrude(total_height - floor_thickness + epsilon) rails_shape();
}
