const std = @import("std");
const Io = std.Io;

fn count5(io: Io) void {
    var i: u32 = 0;
    while (i <= 1000) : (i += 5) {
        if ((i % 5) == 0) {
            std.log.info("5-5 {d}", .{i});
        }
        io.sleep(.fromMilliseconds(500), .awake) catch |err| {
            std.log.err("Error {any}", .{err});
        };
    }
}

fn count1(io: Io) void {
    for (0..1001) |a| {
        std.log.info("1-1 {d}", .{a});
        io.sleep(.fromMicroseconds(100), .awake) catch |err| {
            std.log.err("err ->{any} ", .{err});
        };
    }
}

pub fn main(init: std.process.Init) void {
    const io = init.io;

    var task1 = io.async(count1, .{io});
    defer task1.cancel(io);
    var task2 = io.async(count5, .{io});
    defer task2.cancel(io);

    task1.await(io);
    task2.await(io);
}
