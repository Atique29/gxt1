//! Provides some utility functions
const std = @import("std");
const String = @import("tunings").String;

/// Takes to f32 numbers and returns their squared difference
fn squaredError(f1: f32, f2: f32) f32 {
    return (f1 - f2) * (f1 - f2);
}

/// Calculates the deviation of pitch in cents
fn toCents(f1: f32, f2: f32) f32 {
    return 1200 * std.math.log2(f1 / f2);
}


/// Takes estimated pitch and a tuning (array of Strings)
/// Returns the String that is closest in freq to estimated pitch
/// and the difference between them i cents
pub fn findNearestString(tuning: [6]String, pitch_est: f32) struct { String, f32 } {

    var min: f32 = std.math.inf(f32);
    var idx: usize = 0;
    for (tuning, 0..) |string, i| {
        const sq_err = squaredError(pitch_est, string.freq);
        if (sq_err < min){
            min =  sq_err;
            idx = i;
        }
    }

    const target_string = tuning[idx];
    const deviation = toCents(pitch_est, target_string.freq);

    return .{target_string, deviation};
}
