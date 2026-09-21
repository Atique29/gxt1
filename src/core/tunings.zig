/// Defines pitches and tunings in MIDI (C4)
const std = @import("std");

/// Pitch Class definition
pub const PitchClass = enum(u4){
    C,
    C_Sharp,
    D, 
    D_Sharp, 
    E, 
    F,
    F_Sharp, 
    G, 
    G_Sharp,
    A,
    A_Sharp,
    B,
};

/// Pitch definition
pub const Pitch = struct {
    pitch_class: PitchClass,
    octave: i8,
};

/// MIDI Value definition (C4)
pub const MidiVal = u8;

/// Tuning Definition 
pub const Tuning = [6] MidiVal;

/// Standard Tuning
pub const standard: Tuning = .{
    64, // E4
    59, // B3
    55, // G3   
    50, // D3
    45, // A2
    40, // E2
};

