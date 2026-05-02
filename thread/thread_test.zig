const std = @import("std");
const Io = std.Io;

fn count1(io: Io) void {
    var i: u32 = 0;
    while (i <= 1000) : (i = i + 1) {
        std.log.info("count 1 -> {d}", .{i});
        io.sleep(.fromMilliseconds(100), .awake) catch |err| {
            std.log.err("Error {any}", .{err});
        };
    }
}

fn count5(io: Io) void {
    var i: u32 = 0;
    while (i <= 1000) : (i = i + 5) {
        std.log.info("conut 5 -> {d}", .{i});

        io.sleep(.fromMilliseconds(500), .awake) catch |err| {
            std.log.err("Error {any}", .{err});
        };
    }
}

pub fn main(init: std.process.Init) !void {
    std.log.info("Starting count \n", .{});
    const io = init.io;

    const work1 = try std.Thread.spawn(.{}, count1, .{io});
    defer work1.join();

    const work2 = try std.Thread.spawn(.{}, count5, .{io});
    defer work2.join();
}
