const std = @import("std");

const port: u16 = 5088;
const ip: []const u8 = "127.0.0.1";

fn readLine(reader: anytype) anyerror![]const u8 {
    return reader.takeDelimiterInclusive('\n');
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const addr = try std.Io.net.IpAddress.parse(ip, port);
    var server = try addr.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);

    std.log.info("Listening on {s}:{d}", .{ ip, port });

    while (true) {
        const conn = try server.accept(io);
        defer conn.close(io);

        std.log.info("Client connected", .{});

        var recv_buf: [1024]u8 = undefined;
        var reader = conn.reader(io, &recv_buf);

        var send_buf: [64]u8 = undefined;
        var writer = conn.writer(io, &send_buf);

        while (true) {
            const line = readLine(&reader.interface) catch |err| {
                if (err == error.EndOfStream) {
                    std.log.warn("Client Disconnected", .{});
                    break;
                } else {
                    std.log.warn("Error {any}", .{err});
                }
                break;
            };

            const trimmed = std.mem.trim(u8, line, "\r\n \t");
            if (trimmed.len == 0) continue;
            std.log.info("Received: [{s}]", .{trimmed});

            if (std.mem.eql(u8, trimmed, "ping")) {
                try writer.interface.writeAll("pong\n");
                try writer.interface.flush();
            } else {
                try writer.interface.writeAll("unknown\n");
                try writer.interface.flush();
            }
        }
    }
}
