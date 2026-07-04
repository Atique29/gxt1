pub const sampling_rate = 44100;
pub const max_lag = 600;
pub const win_size = 8192 - max_lag;
pub const buff_size = max_lag + win_size;
pub const threshold = 0.12;
