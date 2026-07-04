const std = @import("std");
const Io = std.Io;
const Pulse = @import("pulse");
const yin = @import("yin");
const config = @import("config");

const sampling_rate = config.sampling_rate;
const max_lag = config.max_lag;
const win_size = config.win_size;
const buff_size = max_lag + win_size;
const thresh = config.threshold;
const RingBuffer = @import("ringBuffer").ringBuffer(i16, buff_size);

pub fn main(init: std.process.Init) !void {

    std.log.info("Initializing pulseaudio event-loop", .{});
    var p: Pulse = undefined;
    try p.init();
    defer p.deinit();

    p.lock();
    try p.waitUntilReady();

    var rb: RingBuffer = .{.buff = undefined};
    std.log.info("Initializing audio stream", .{});
    try p.streamStart(&rb);
    p.unlock();

    var yin_buff: [buff_size]i16 = undefined;
    const io = init.io;
    // const stdout: Io.File = .stdout();
    while (true) {
        const read_len = rb.read(&yin_buff);
        if (read_len >= max_lag + win_size) {
            // std.log.info("read {d} samples\n", .{read_len});
            // const byte_slice = std.mem.sliceAsBytes(fft_buf[0..read_len]);
            // try stdout.writeStreamingAll(io, byte_slice[0..0]);
            const pitch = yin.detectPitch(win_size, max_lag, thresh, sampling_rate, yin_buff[0..]);
            std.debug.print("Pitch: {d:.2}\n", .{pitch});

        } else {
            try std.Io.sleep(io, Io.Duration.fromMilliseconds(500), .real);
        }
    }
}



