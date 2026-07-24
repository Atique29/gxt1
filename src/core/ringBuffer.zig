//! Lock / Wait free ring buffer implementation for the multhreaded  Single Producer, Single Consumer tuner system
// Inspired by https://github.com/freref/spsc-queue 
const std = @import("std");
const assert = std.debug.assert;
const Atomic = std.atomic;
const cache_line = Atomic.cache_line;

/// Pad the read and write pointers to ensure they take up a full cache line each
fn pad(comptime N: usize, comptime T: type) type {
    const sz = @sizeOf(T);
    const rem = sz % N;
    return [if (rem == 0) 0 else N - rem]u8;
}

const Producer = struct {
    write_idx: std.atomic.Value(usize) = .{ .raw = 0 },
    read_idx_cache: usize = 0,
    _pad: pad(cache_line, [2]usize) = undefined,
};

const Consumer = struct {
    read_idx: std.atomic.Value(usize) = .{ .raw = 0 },
    write_idx_cache: usize = 0,
    _pad: pad(cache_line, [2]usize) = undefined,
};

pub fn ringBuffer(comptime T: type, comptime capacity: usize) type {
    // Capacity must be a power of 2
    assert(std.math.isPowerOfTwo(capacity));
    const mask = capacity - 1;

    return struct {
        buff: [capacity] T, 
        producer: Producer align(cache_line) = .{}, // Align to cache line boundary
        consumer: Consumer align(cache_line) = .{},
        const Self = @This();

        /// Non-blocking write, called only by producer
        pub fn write(self: *Self, data: [] const T) usize {
            const current_write_idx = self.producer.write_idx.load(.monotonic);

            // Try to avoid an atomic read, use stale cached value 
            var available_space = capacity - (current_write_idx -% self.producer.read_idx_cache);
            // If enough space not available, read the actual current read_idx to see if slots have been freed after the last read_idx was chached
            if (available_space < data.len){
                self.producer.read_idx_cache = self.consumer.read_idx.load(.acquire);
                available_space = capacity - (current_write_idx -% self.producer.read_idx_cache);
            }

            const write_len = @min(available_space, data.len);
            // The following loop might be slow?
            // going with memcpy instead
            // for (data[0..write_len], 0..) |val, i| {
            //     self.buff[(current_write_idx + i) & mask] = val;
            // }

            // Use memcpy to write to the buffer
            // Handle the wrap around the buffer case manually
            const current_write_idx_wrapped = current_write_idx & mask;
            const space_till_end: usize = capacity - current_write_idx_wrapped;
            if (space_till_end >= write_len) { // Wrap around not required
                const write_end = current_write_idx_wrapped + write_len;
                @memcpy(self.buff[current_write_idx_wrapped..write_end], data[0..write_len]); // write everything to buffer
            } else {
                // First write up to the end of buffer 
                @memcpy(self.buff[current_write_idx_wrapped..capacity], data[0..space_till_end]);

                // Wrap around and write whats left
                const write_end = write_len - space_till_end;
                @memcpy(self.buff[0..write_end], data[space_till_end..write_len]);

            }
            // Update the write_idx atomically
            self.producer.write_idx.store(current_write_idx +% write_len, .release);
            return write_len;
        }

        /// Non-blocking read, called only by consumer
        pub fn read(self: *Self, data: []T) usize {
            const current_read_idx = self.consumer.read_idx.load(.monotonic);
            var available_data = self.consumer.write_idx_cache -% current_read_idx;

            if (available_data < data.len) {
                self.consumer.write_idx_cache = self.producer.write_idx.load(.acquire);
                available_data = self.consumer.write_idx_cache -% current_read_idx;
            }

            const read_len = @min(available_data, data.len);
            if (read_len == 0) return 0;

            const current_read_idx_wrapped = current_read_idx & mask;
            const space_till_end = capacity - current_read_idx_wrapped;

            if (space_till_end >= read_len) {
                const read_end = current_read_idx_wrapped + read_len;
                @memcpy(data[0..read_len], self.buff[current_read_idx_wrapped..read_end]);
            } else {
                @memcpy(data[0..space_till_end], self.buff[current_read_idx_wrapped..capacity]);

                const read_end = read_len - space_till_end;
                @memcpy(data[space_till_end..read_len], self.buff[0..read_end]);
            }

            self.consumer.read_idx.store(current_read_idx +% read_len, .release);
            
            return read_len;
        }

        /// Clear the write-read indices and the buffer
        pub fn flush(self: *Self) void {
            self.producer.write_idx.store(0, .release);
            self.consumer.read_idx.store(0, .release);
            @memset(&self.buff, 0);
        }

        /// Returns the data size available for reading
        /// Called by consumer
        pub fn available(self: *Self) usize {
            const read_idx = self.consumer.read_idx.load(.monotonic);
            const write_idx = self.producer.write_idx.load(.monotonic);
            const available_data = write_idx -% read_idx;
            return available_data;
        }

    };

}
