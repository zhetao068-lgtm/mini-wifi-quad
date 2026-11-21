// V0.7 STRUCTURAL FIT PROTOTYPE. All dimensions are mm.
// Motor pod 20.4 mm and PCB 29 x 25 mm are reference envelopes, NOT measured hardware.
// Print frame with its flat lower face on the bed. Four feet print separately.
part = "frame"; // "frame", "foot", "collar-test", "assembly"
frame_bottom = 12;
floor_t = 1.2;
body_l = 105;
body_w = 49;
rim = 2.0;
arm_w = 8;
arm_wall = 0.9;
arm_rib_h = 5.5;
motor_x = 64;
motor_y = 62;
root_x = 24;
root_y = 17;
pod_d = 20.4;
pod_clearance = 0.2;
collar_wall = 2;
collar_h = 7.5;
collar_split = 1.2;
seat_open_d = 17;
foot_d = 8.4;
foot_inner_d = 4.2;
foot_height = 12;
foot_cap_h = 5;
foot_pilot_d = 1.7;
foot_offset = 16;
fastener_clear_d = 2.2;
battery_x = 12;
battery_hole_y = 20.2;
battery_pad_d = 7.2;
battery_pad_top = 19.5;
cover_x = -41;
cover_hole_y = 14;
cover_pad_d = 7.2;
cover_pad_top = 19;
$fn = 48;
eps = 0.02;
pod_hole_d = pod_d + 2 * pod_clearance;
collar_od = pod_hole_d + 2 * collar_wall;

module rr(l,w,r) { offset(r=r) square([l-2*r,w-2*r],center=true); }
module plate() {
    difference() {
        union() {
            difference() { rr(body_l,body_w,5); rr(body_l-2*rim,body_w-2*rim,3); }
            rr(body_l-2,3,1);
            translate([-5,0]) rr(3,body_w-2,1);
            translate([battery_x,0]) rr(3,body_w-2,1);
            translate([-5,0]) difference() { rr(34,29,2); rr(26,21,1); }
            translate([-42.75,0]) rr(19.5,35.6,2);
            for(y=[-battery_hole_y,battery_hole_y])
                translate([battery_x,y]) circle(d=battery_pad_d);
        }
        for(x=[-15,5],y=[-11.5,11.5])
            translate([x,y]) rr(6,1.6,0.5);
    }
}
module arm_placement(sx,sy) {
    dx=motor_x-root_x;
    dy=motor_y-root_y;
    a=atan2(sy*dy,sx*dx);
    translate([sx*root_x,sy*root_y,0]) rotate([0,0,a]) children();
}
module arms() {
    L=sqrt(pow(motor_x-root_x,2)+pow(motor_y-root_y,2));
    for(sx=[-1,1],sy=[-1,1]) arm_placement(sx,sy) {
        translate([-6,-arm_w/2,frame_bottom]) cube([L+6,arm_w,floor_t]);
        for(y=[-arm_w/2,arm_w/2-arm_wall])
            translate([-6,y,frame_bottom+floor_t-eps])
                cube([L+6,arm_wall,arm_rib_h+eps]);
        translate([L,0,frame_bottom]) cylinder(h=floor_t,d=collar_od);
        translate([L,0,frame_bottom+floor_t-eps])
            cylinder(h=collar_h+eps,d=collar_od);
    }
}
module pillars() {
    for(y=[-battery_hole_y,battery_hole_y])
        translate([battery_x,y,frame_bottom])
            cylinder(h=battery_pad_top-frame_bottom,d=battery_pad_d);
    for(y=[-cover_hole_y,cover_hole_y])
        translate([cover_x,y,frame_bottom])
            cylinder(h=cover_pad_top-frame_bottom,d=cover_pad_d);
    // Four small PCB feet; no assumed PCB mounting holes.
    for(x=[-16,6],y=[-10,10])
        translate([x,y,frame_bottom]) cylinder(h=19.5-frame_bottom,d=4);
    // Camera cradle: cross ribs and flat adhesive surface.
    translate([-47.5,0,frame_bottom]) linear_extrude(19.3-frame_bottom)
        union() { square([9,3],center=true); square([3,14.7],center=true); }
    translate([-52,-7.35,19.3-eps]) cube([9,14.7,0.8+eps]);
}
module frame() {
    difference() {
        union() {
            translate([0,0,frame_bottom]) linear_extrude(floor_t) plate();
            arms(); pillars();
        }
        for(sx=[-1,1],sy=[-1,1]) {
            translate([sx*motor_x,sy*motor_y,frame_bottom-eps])
                cylinder(h=floor_t+2*eps,d=seat_open_d);
            translate([sx*motor_x,sy*motor_y,frame_bottom+floor_t])
                cylinder(h=collar_h+eps,d=pod_hole_d);
            a=atan2(sy*(motor_y-root_y),sx*(motor_x-root_x));
            translate([sx*motor_x,sy*motor_y,frame_bottom-eps]) rotate([0,0,a])
                translate([0,-collar_split/2,0]) cube([collar_od,collar_split,collar_h+floor_t+2*eps]);
        }
        L=sqrt(pow(motor_x-root_x,2)+pow(motor_y-root_y,2));
        for(sx=[-1,1],sy=[-1,1]) arm_placement(sx,sy)
            translate([L-foot_offset,0,frame_bottom-eps])
                cylinder(h=floor_t+2*eps,d=fastener_clear_d);
        for(y=[-battery_hole_y,battery_hole_y])
            translate([battery_x,y,frame_bottom-eps]) cylinder(h=9,d=fastener_clear_d);
        for(y=[-cover_hole_y,cover_hole_y])
            translate([cover_x,y,frame_bottom-eps]) cylinder(h=8,d=fastener_clear_d);
    }
}
module foot() {
    difference() {
        cylinder(h=foot_height,d=foot_d);
        translate([0,0,-eps]) cylinder(h=foot_height-foot_cap_h+eps,d=foot_inner_d);
        translate([0,0,foot_height-foot_cap_h]) cylinder(h=foot_cap_h+eps,d=foot_pilot_d);
    }
}
module collar_test() {
    difference() {
        union() {
            difference() { cylinder(h=floor_t,d=collar_od); translate([0,0,-eps]) cylinder(h=floor_t+2*eps,d=seat_open_d); }
            translate([0,0,floor_t-eps]) difference() {
                cylinder(h=collar_h+eps,d=collar_od);
                cylinder(h=collar_h+2*eps,d=pod_hole_d);
            }
        }
        translate([0,-collar_split/2,-1]) cube([collar_od,collar_split,10]);
    }
}
assert(pod_hole_d>pod_d && collar_wall>=1.6);
assert(foot_height==frame_bottom && foot_cap_h>4);
assert(collar_split>0 && seat_open_d<pod_d);
if(part=="frame") translate([0,0,-frame_bottom]) frame();
else if(part=="foot") foot();
else if(part=="collar-test") collar_test();
else if(part=="assembly") {
    frame();
    L=sqrt(pow(motor_x-root_x,2)+pow(motor_y-root_y,2));
    for(sx=[-1,1],sy=[-1,1]) arm_placement(sx,sy)
        translate([L-foot_offset,0,0]) foot();
    translate([-49,0,19]) import("quad-camera-cover-v07.stl");
    translate([12,0,24]) import("wifi-quad-battery-tray-fit.stl");
    for(y=[-20.2,20.2]) translate([12,y,19.5]) import("wifi-quad-battery-spacer.stl");
}
