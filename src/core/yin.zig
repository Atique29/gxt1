const std = @import("std");
const assert = std.debug.assert;

pub fn detectPitch(win_size: usize, comptime max_lag: usize, thresh: f32, sampling_rate: f32, data: [] i16) f32 {

    // array to store difference function: d(lag), with 0 <= lag <= lag_max
    var diff_func: [max_lag + 1] f32 = undefined;
    diff_func[0] = 0;
    
    // Array for CMNDF
    var cmndf: [max_lag + 1] f32 = undefined;
    cmndf[0] = 1; 
    
    var sum: f32 = 0; // For normalization in CMNDF
    // var pitch_estimate: f32 = 0;

    // True when cmndf goes below threshold, toward a local minima
    var in_valley: bool = false; 

    // Calculate difference function 
    var tau: usize = 1;
    while (tau <= max_lag):(tau += 1) {
        var j: usize = 0;
        var err: f32 = 0;

        while (j < win_size):(j += 1){
            const x_j: f32 = @floatFromInt(data[j]);
            const x_j_tau: f32 = @floatFromInt(data[j + tau]);
            const del_x = x_j - x_j_tau;
            err += del_x * del_x ;
        }
        diff_func[tau] = err;
        
        // Calculate CMNDF
        sum += err; // Update the running sum for normalization
        const n_diff = (err * @as(f32, @floatFromInt(tau))) / sum ; // Normalize
        cmndf[tau] = n_diff;

        // Absolute thresholding
        if (in_valley == false) { 
            if (n_diff < thresh){ // Entered the valley?
                in_valley = true;
                continue;
            }
        } else { // CMNDF is in a valley => find the local minima
            if (n_diff <= cmndf[tau - 1]) {// Going downwards in the valley
                continue;

            } else { // Going up in the valley, the previous iteration was the local minima
                
                // Parabolic interpolation with the raw diffrence function instead of CMNDF
                const center_tau = tau - 1; // Previous tau is the center point

                // Get the three ordinates for interpolation
                const y1 = diff_func[center_tau - 1];
                const y2 = diff_func[center_tau];
                const y3 = diff_func[center_tau + 1];

                // Calculate the shift to the minima from center_tau
                const denom =  2 * (y1 - 2*y2 + y3); // Handle this being zero
                const del_tau = if (@abs(denom) > 1e-5) (y1 - y3) / denom else 0;


                const interpolated_tau = del_tau + @as(f32, @floatFromInt(center_tau));
                return sampling_rate / interpolated_tau; 

            }
        }

    }

    // CMNDF did not go below threshold
    // Return a pitch corresponding to the global CMNDF minimum 

    var min: f32 = 1; // tau = 0
    var min_idx: usize = 0;
    for (cmndf[1..], 1..) |val, idx| {
        if (val < min) {
            min = val;
            min_idx = idx;
        }

    }

    // Should I do parabolic interpolation here as well?
    // But there's no center_tau + 1 here
    return sampling_rate / @as(f32, @floatFromInt(min_idx));

}
