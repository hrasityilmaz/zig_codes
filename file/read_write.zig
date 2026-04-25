const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    //Probably will change here! init.gpa
    const allocator = std.heap.page_allocator;
    const mem = try allocator.alloc(u8, 1024);
    defer allocator.free(mem);

    const file = try std.Io.Dir.createFileAbsolute(io, "new_file.txt", .{ .read = true, .truncate = true });
    defer file.close(io);

    const file_content: [:0]const u8 = "Tengri Biz Menen!\n";
    var write_buffer: [1024]u8 = undefined;
    var writer = file.writer(io, &write_buffer);
    _ = writer.interface.writeAll(file_content) catch |err| {
        if (err == error.WriteFailed) {
            std.log.err("Write failed {}", .{err});
            return;
        } else return err;
    };
    _ = writer.interface.flush() catch |err| {
        if (err == error.WriteFailed) {
            std.log.err("Write failed {}", .{err});
            return;
        } else return err;
    };

    const file_stat = try file.stat(io);
    const size = file_stat.size;
    std.log.info("Alloc waiting correct buffer {d} byte will be allocate now!", .{size});

    var read_buffer: [1024]u8 = undefined;
    var reader = file.reader(io, &read_buffer);
    const read = try reader.interface.readAlloc(allocator, @as(usize, size));
    defer allocator.free(read);

    std.log.info("Read Alloc -> {s}", .{read});
}
