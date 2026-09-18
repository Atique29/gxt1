const std = @import("std");

pub const Note = enum {
    A,
    B,
    C,
    D, 
    E, 
    F,
    G, 
    A_Sharp,
    C_Sharp,
    D_Sharp, 
    F_Sharp, 
    G_Sharp,
};

pub const String = struct {
    num: u8,
    note: Note,
    freq: f32, 
};

pub const Tuning = [6] String;

pub const standard: Tuning = .{
    .{ .num = 1, .note = .E, .freq = 329.63},
    .{ .num = 2, .note = .B, .freq = 246.94},
    .{ .num = 3, .note = .G, .freq = 196.00},
    .{ .num = 4, .note = .D, .freq = 146.83},
    .{ .num = 5, .note = .A, .freq = 110.00},
    .{ .num = 6, .note = .E, .freq = 82.41},
};
