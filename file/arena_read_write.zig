const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const db = try std.Io.Dir.cwd().createFile(io, "append.db", .{ .truncate = true });
    defer db.close(io);

    var write_buf: [512 * 1024]u8 = undefined;
    var writer = db.writer(io, &write_buf);

    const start = std.Io.Clock.now(.awake, io);
    for (0..100000000) |_| {
        try writer.interface.writeAll("test\n");
    }
    try writer.interface.flush();

    const end = std.Io.Clock.now(.awake, io);
    const elapsed = start.durationTo(end);
    std.debug.print("actual work: {d}us\n", .{elapsed.toMicroseconds()});
}
