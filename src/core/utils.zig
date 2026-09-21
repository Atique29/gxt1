//! Provides some utility functions
const std = @import("std");
const Tunings = @import("tunings");

const Tuning = Tunings.Tuning;
const Pitch = Tunings.Pitch;
const PitchClass = Tunings.PitchClass;
const MidiVal = Tunings.MidiVal;

/// Takes to f32 numbers and returns their squared difference
fn squaredError(f1: f32, f2: f32) f32 {
    return (f1 - f2) * (f1 - f2);
}

/// Calculates the deviation of pitch in cents
fn toCents(f1: f32, f2: f32) f32 {
    return 1200 * std.math.log2(f1 / f2);
}

/// Calculates frequency from MIDI value
fn freqFromMIDI(midi_val: MidiVal) f32 {
    const freq_exp: f32 = ( @as(f32, @floatFromInt(midi_val)) - 69 ) / 12 ;
    const freq: f32 = 440 * std.math.exp2(freq_exp);

    return freq;
}


/// Takes estimated pitch and a tuning 
/// Returns the Pitch that is closest in freq to estimated pitch
/// and the difference between them i cents
pub fn findNearestPitch(tuning: Tuning, pitch_est: f32) struct { Pitch, f32 } {

    var min: f32 = std.math.inf(f32);
    var idx: usize = 0;
    var target_freq: f32 = 0;

    for (tuning, 0..) |midi_val, i| {

        // note: Should I initialize tunings to precalc freq? 
        // is that optimization worth it?
        const freq = freqFromMIDI(midi_val); 
        const sq_err = squaredError(pitch_est, freq);
        if (sq_err < min){
            min =  sq_err;
            idx = i;
            target_freq = freq;
        }
    }

    const target_midi = tuning[idx];
    const deviation = toCents(pitch_est, target_freq);

    return .{ pitchFromMIDI(target_midi), deviation };
}


/// Takes a MIDI number and returns the corresponding pitch
pub fn pitchFromMIDI(midi_val: u8) Pitch {

    const pitch_idx: u8 = midi_val % 12;
    const pitch_class: PitchClass = @enumFromInt(pitch_idx);
    const midi_val_i8: i8 = @as(i8, @intCast(midi_val));
    const octave: i8 = @divFloor(midi_val_i8, 12) - 1;

    return .{ 
        .pitch_class = pitch_class,
        .octave = octave,
    };

}


























