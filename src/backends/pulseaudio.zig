//! This file declares the pulseaudio backend for streaming audio

const std = @import("std");
const pa = @import("pulseaudio") ;
const RingBuffer = @import("ringBuffer").ringBuffer(i16, 8192);
const assert = std.debug.assert;

context: *pa.context,
state: pa.context.state_t,
stream_state: pa.stream.state_t,
main_loop: *pa.threaded_mainloop,
stream: ?*pa.stream,
properties: *pa.proplist,
rb: *RingBuffer,

const Pulse = @This();

pub fn init(p: *Pulse) !void {
    const main_loop = try pa.threaded_mainloop.new();
    errdefer main_loop.free();
    
    const properties = try pa.proplist.new();
    errdefer properties.free();
    try properties.sets("media.role", "tuner");
    try properties.sets("media.software", "GCXT1");

    const context = try pa.context.new_with_proplist(main_loop.get_api(), "TunerAudioBackend", properties);
    errdefer context.unref();

    p.* = .{
        .context = context, 
        .state = .UNCONNECTED, 
        .main_loop = main_loop, 
        .stream = null, 
        .stream_state = .UNCONNECTED,
        .properties = properties,
        .rb = undefined,
    };

    context.set_state_callback(contextStateCallback, p);
    try context.connect(null, .{}, null);
    errdefer context.disconnect();

    try main_loop.start();
    errdefer main_loop.stop();

}

pub fn deinit(p: *Pulse) void{
    // assert(p.stream == null); why andrew does this instead of stopping
    // amd unreferencing the stream?
    // when does stream becomes null in his player?
    if (p.stream) |stream| {
        assert(stream.disconnect() == 0);
        stream.unref();
    }
    p.properties.free();
    p.context.disconnect(); 
    p.context.unref();
    p.main_loop.stop();
    p.main_loop.free();
    p.* = undefined;
}

fn contextStateCallback(context: *pa.context, userdata: ?*anyopaque) callconv(.c) void {
    const p: *Pulse = @ptrCast(@alignCast(userdata));
    p.state = context.get_state();
    switch (p.state) {
        .UNCONNECTED, .CONNECTING, .AUTHORIZING, .SETTING_NAME => return,
        .READY, .FAILED, .TERMINATED => p.main_loop.signal(0),
    }
}

fn streamCallback(stream: *pa.stream, userdata: ?*anyopaque) callconv(.c) void{
    const p: *Pulse = @ptrCast(@alignCast(userdata));
    p.stream_state = stream.get_state();
    switch (p.stream_state) {
        .UNCONNECTED, .CREATING  => return,
        .READY, .FAILED, .TERMINATED => p.main_loop.signal(0),
    }
}

fn streamReadCallback(stream: *pa.stream, _: usize, userdata : ?*anyopaque) callconv(.c) void{
    const p: *Pulse = @ptrCast(@alignCast(userdata));

    while (stream.readable_size() > 0) {
        var length: usize = undefined;
        var data: ?*const anyopaque = undefined;
        _ = stream.peek(&data, &length);
        if (data) |data_ptr| {
            const byte_ptr: [*]const i16 = @ptrCast(@alignCast(data_ptr)); // Cast to i16 because 16 bit pcm 
            const data_slice: []const i16 = byte_ptr[0..length/2];
            _ = p.rb.write(data_slice);
            
        } else {@panic("hole!");}
        _ = stream.drop();
    }
}

// Must be called with the lock held 
pub fn streamStart(p: *Pulse, buff: *RingBuffer) !void {
    assert(p.state == .READY);
    assert(p.stream == null);
    p.rb = buff;

    // Set up the stream
    const rec_sample_spec: pa.sample_spec = .{
        .format = .S16LE,
        .rate = 44100,
        .channels = 1,
    };

    var rec_channel_map: pa.channel_map = undefined;
    _ = pa.channel_map_init_mono(&rec_channel_map);

    // Create new recording stream
    p.stream = try pa.stream.new(p.context, "gcxt1_stream", &rec_sample_spec, &rec_channel_map);
    const stream = p.stream.?;
    stream.set_state_callback(streamCallback, p);
    stream.set_read_callback(streamReadCallback, p);

    // Connect to the stream
    const u32_max = std.math.maxInt(u32);
    const buff_attr: pa.buffer_attr = .{
        // .maxlength = 65536, docs: only make fragsize different
        .maxlength = u32_max, 
        .fragsize = 4096,   // lowered from u32_max to reduce the latency
        .minreq = u32_max,  // playback only
        .prebuf = u32_max,  // playback only
        .tlength = u32_max, // playback only
    };

    // Connect the stream to the source
    _ = stream.connect_record(null, &buff_attr, .{
        .ADJUST_LATENCY = true, // Set ADJUST_LATENCY to apply the shorter fragsize set above
    });

    // Wait until stream ready
    while (true) {
        p.main_loop.wait();
        switch (p.stream_state) {
            .READY => break,
            .FAILED => return error.Failed, 
            .TERMINATED => return error.Terminated,
            else => continue,
        }
    }

}

/// Must be called with lock held
pub fn waitUntilReady(p: *Pulse) !void {
    while (true) {
        p.main_loop.wait();
        switch (p.state) {
            .READY => break,
            .FAILED => return error.Failed,
            .TERMINATED => return error.Terminated,
            else => continue,
        }
    }
}

pub fn lock(p: *Pulse) void {
    p.main_loop.lock();
}

pub fn unlock(p: *Pulse) void {
    p.main_loop.unlock();
}

pub fn wait(p: *Pulse) void {
    p.main_loop.wait();
}
