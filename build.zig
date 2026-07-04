const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{ 
            .os_tag = .linux,
            .cpu_arch = .x86_64,
            .abi = .gnu
        }
    });

    const optimize = b.standardOptimizeOption(.{});
   
    const ring_mod = b.addModule("ringBuffer", .{
        .root_source_file = b.path("src/core/ringBuffer.zig"),
        .target = target,
    });

    const yin_mod = b.addModule("yin", .{
        .root_source_file = b.path("src/core/yin.zig"),
        .target = target,
    });

    const pulseaudio_dep = b.dependency("pulseaudio", .{
        .target = target,
        .optimize = optimize,
    });
    const pulse_mod = b.addModule("pulse", .{
        .root_source_file = b.path("src/backends/pulseaudio.zig"),
        .target = target,
        .imports = &.{
            .{
                .name = "pulseaudio",
                .module = pulseaudio_dep.module("pulseaudio"),
            },
            .{
                .name = "ringBuffer",
                .module = ring_mod,
            }
        },
    });
    

    
    const exe = b.addExecutable(.{
        .name = "gxt1",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "pulse", .module = pulse_mod },
                .{ .name = "ringBuffer", .module = ring_mod},
                .{ .name = "yin", .module = yin_mod},
            },
        }),
    });

    
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());


}
