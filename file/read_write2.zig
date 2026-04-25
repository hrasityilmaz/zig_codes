const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    const file = try std.Io.Dir.cwd().createFile(io, "new_file.txt", .{ .read = true });
    defer file.close(io);

    const file_content: [:0]const u8 = "Tengri Biz Menen\n";

    try file.writeStreamingAll(io, file_content);

    const file_stat = try file.stat(io);
    const size = file_stat.size;
    std.log.info("file size -> {d}", .{size});

    var read_buffer: [1024]u8 = undefined;
    var reader = file.reader(io, &read_buffer);
    try reader.seekTo(0);

    const read = try reader.interface.readAlloc(allocator, @as(usize, size));
    defer allocator.free(read);
    std.log.info("Read -> {s}", .{read});
}
