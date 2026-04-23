const std = @import("std");
const net = std.Io.net;

const ip: [:0]const u8 = "127.0.0.1";
const port: u16 = 5088;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const address = try net.IpAddress.parse(ip, port);
    const client = try address.connect(io, .{ .mode = .stream });
    defer client.close(io);

    const msg: [:0]const u8 = "ping\n";
    var read_buffer: [1024]u8 = undefined;
    var send_buffer: [64]u8 = undefined;
    var writer = client.writer(io, &send_buffer);

    try writer.interface.writeAll(msg);
    try writer.interface.flush();
    try client.shutdown(io, .send);

    var reader = client.reader(io, &read_buffer);
    while (true) {
        const line = reader.interface.takeDelimiterInclusive('\n') catch |err| {
            if (err == error.EndOfStream) {
                std.log.info("Server closed the connection normally.", .{});
            } else {
                std.log.err("Disconnected with error: {any}", .{err});
            }
            break;
        };

        const trimmed = std.mem.trim(u8, line, "\r\n \t");
        if (trimmed.len == 0) continue;
        std.log.info("Answer came: {s}", .{trimmed});
        break;
    }
}
