const std = @import("std");
const Io = std.Io;
const Pulse = @import("pulse");
const RingBuffer = @import("ringBuffer").ringBuffer(i16, 8192);

pub fn main(init: std.process.Init) !void {

    std.log.info("Initializing pulseaudio event-loop", .{});
    var p: Pulse = undefined;
    try p.init();
    defer p.deinit();

    {}
    p.lock();
    try p.waitUntilReady();

    const buffer: [8192] i16 = undefined;
    var rb: RingBuffer = .{.buff = buffer};
    std.log.info("Initializing audio stream", .{});
    try p.streamStart(&rb);
    p.unlock();

    var fft_buf: [8192]i16 = undefined;
    const io = init.io;
    const stdout: Io.File = .stdout();
    while (true) {
        const read_len = rb.read(&fft_buf);
        if (read_len > 0) {
            const byte_slice = std.mem.sliceAsBytes(fft_buf[0..read_len]);
            try stdout.writeStreamingAll(io, byte_slice);
        } else {
            try std.Io.sleep(io, Io.Duration.fromMilliseconds(10), .real);
        }
    }
}



