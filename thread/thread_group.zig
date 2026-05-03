const std = @import("std");
const Io = std.Io;

const err = std.log.err;
const info = std.log.info;

fn sleep(io: Io, id: usize, rng: std.Random) void {
    const duration = rng.intRangeAtMost(i64, 100, 2500);
    info("{d}. sleep  started for {d}", .{ id, duration });
    io.sleep(.fromMilliseconds(duration), .awake) catch |e| {
        err("Error when sleep {any}", .{e});
    };
    info("{d} slept for {} ", .{ id, duration });
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var seed: u64 = undefined;

    io.random(std.mem.asBytes(&seed));
    var prng: std.Random.DefaultPrng = .init(seed);
    const rng = prng.random();

    //const res = rng.intRangeAtMost(u64, 100, 2500);
    //info("{d}", .{res});

    var group: Io.Group = .init;
    for (0..8) |i| {
        group.async(io, sleep, .{ io, i, rng });
    }

    try group.await(io);
}
