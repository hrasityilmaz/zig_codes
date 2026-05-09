const std = @import("std");
const windows = std.os.windows;
const Io = std.Io;
const Mutex = Io.Mutex;
const Atomic = std.atomic.Value;

pub extern "kernel32" fn GetStdHandle(u32) callconv(.winapi) ?windows.HANDLE;
pub extern "kernel32" fn GetConsoleMode(windows.HANDLE, *u32) callconv(.winapi) windows.BOOL;
pub extern "kernel32" fn SetConsoleMode(windows.HANDLE, u32) callconv(.winapi) windows.BOOL;
pub extern "kernel32" fn SetConsoleOutputCP(u32) callconv(.winapi) windows.BOOL;
pub extern "kernel32" fn SetConsoleCursorPosition(windows.HANDLE, COORD) callconv(.winapi) windows.BOOL;
pub const COORD = extern struct { X: i16, Y: i16 };

const RESET = "\x1b[0m";
const CYAN = "\x1b[96m";
const GREEN = "\x1b[92m";
const MAGENTA = "\x1b[95m";
const DIM = "\x1b[2m";
const BOLD = "\x1b[1m";
const HIDE = "\x1b[?25l";
const CLEAR = "\x1b[2J\x1b[H";

const L = 25;
const R = 32;

const Shared = struct {
    mutex: Mutex = .init,
    running: Atomic(bool) = .init(true),
    left_val: u64 = 0,
    left_tick: u64 = 0,
    right_idx: usize = 0,
    right_tick: u64 = 0,
};
var sh = Shared{};

const CONTENT = [_][]const u8{
    "Test content 1",
    "Test content 2",
    "Test content 3",
    "Test content 4",
};

fn spaces(w: *Io.Writer, n: usize) !void {
    var buf: [64]u8 = @splat(' ');
    var rem = n;
    while (rem > 0) {
        const chunk = @min(rem, buf.len);
        _ = try w.write(buf[0..chunk]);
        rem -= chunk;
    }
}

fn draw(io: Io, aw: *Io.Writer.Allocating, hout: windows.HANDLE) !void {
    _ = SetConsoleCursorPosition(hout, .{ .X = 0, .Y = 0 });
    aw.clearRetainingCapacity();
    const w = &aw.writer;

    try sh.mutex.lock(io);
    const lv = sh.left_val;
    const lt = sh.left_tick;
    const ri = sh.right_idx;
    const rt = sh.right_tick;
    sh.mutex.unlock(io);

    const quote = CONTENT[ri];
    const H = 10;
    try w.print("{s}┌{s}┬{s}┐{s}\n", .{ DIM, "─" ** L, "─" ** R, RESET });

    try w.print("{s}│{s} {s}{s}Thread A{s}  {s}(Every 1s){s}", .{
        DIM, RESET, CYAN, BOLD, RESET, DIM, RESET,
    });
    try spaces(w, L - 1 - 8 - 2 - 10);
    try w.print("{s}│{s} {s}{s}Thread B{s}  {s}(Every 2s){s}", .{
        DIM, RESET, CYAN, BOLD, RESET, DIM, RESET,
    });
    try spaces(w, R - 1 - 8 - 2 - 10);
    try w.print("{s}│{s}\n", .{ DIM, RESET });
    try w.print("{s}├{s}┼{s}┤{s}\n", .{ DIM, "─" ** L, "─" ** R, RESET });

    for (0..H) |row| {
        try w.print("{s}│{s}", .{ DIM, RESET });
        if (row == 2) {
            try w.print("  {s}{d:>6}{s}", .{ GREEN, lv, RESET });
            try spaces(w, L - 8);
        } else if (row == 4) {
            try w.print("  {s}tick #{d:<3}{s}", .{ DIM, lt, RESET });
            try spaces(w, L - 11);
        } else {
            try spaces(w, L);
        }

        try w.print("{s}│{s}", .{ DIM, RESET });
        if (row == 2) {
            const max = @min(quote.len, R - 2);
            try w.print("  {s}{s}{s}", .{ MAGENTA, quote[0..max], RESET });
            try spaces(w, R - 2 - max);
        } else if (row == 3 and quote.len > R - 2) {
            const rest = quote[R - 2 .. @min(quote.len, (R - 2) * 2)];
            try w.print("  {s}{s}{s}", .{ MAGENTA, rest, RESET });
            try spaces(w, R - 2 - rest.len);
        } else if (row == 5) {
            try w.print("  {s}tick #{d:<3}{s}", .{ DIM, rt, RESET });
            try spaces(w, R - 11);
        } else {
            try spaces(w, R);
        }
        try w.print("{s}│{s}\n", .{ DIM, RESET });
    }
    try w.print("{s}└{s}┴{s}┘{s}\n", .{ DIM, "─" ** L, "─" ** R, RESET });

    var stdout_buf: [8192]u8 = undefined;
    var stdout_wr = Io.File.stdout().writer(io, &stdout_buf);
    try stdout_wr.interface.writeAll(aw.written());
    try stdout_wr.interface.flush();
}

fn threadLeft(io: Io) !void {
    var seed: u64 = undefined;
    io.random(std.mem.asBytes(&seed));
    var prng: std.Random.DefaultPrng = .init(seed);
    const rng = prng.random();

    while (sh.running.load(.acquire)) {
        try io.sleep(.fromSeconds(1), .awake);
        const val = rng.intRangeAtMost(u64, 0, 999999);
        try sh.mutex.lock(io);
        sh.left_val = val;
        sh.left_tick += 1;
        sh.mutex.unlock(io);
    }
}

fn threadRight(io: Io) !void {
    var seed: u64 = undefined;
    io.random(std.mem.asBytes(&seed));
    var prng: std.Random.DefaultPrng = .init(seed);
    const rng = prng.random();

    while (sh.running.load(.acquire)) {
        try io.sleep(.fromSeconds(2), .awake);
        const idx = rng.uintLessThan(usize, CONTENT.len);
        try sh.mutex.lock(io);
        sh.right_idx = idx;
        sh.right_tick += 1;
        sh.mutex.unlock(io);
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    const STD_OUTPUT_HANDLE: u32 = @bitCast(@as(i32, -11));
    const hOut = GetStdHandle(STD_OUTPUT_HANDLE) orelse return error.NoHandle;
    var mode: u32 = 0;
    _ = GetConsoleMode(hOut, &mode);
    _ = SetConsoleMode(hOut, mode | 0x0004);
    _ = SetConsoleOutputCP(65001); //utf8

    var init_buf: [64]u8 = undefined;
    var out = Io.File.stdout().writer(io, &init_buf);
    try out.interface.print("{s}{s}", .{ HIDE, CLEAR });
    try out.interface.flush();
    defer {
        out.interface.print("\x1b[?25h", .{}) catch {};
        out.interface.flush() catch {};
    }

    const left = try std.Thread.spawn(.{}, threadLeft, .{io});
    const right = try std.Thread.spawn(.{}, threadRight, .{io});
    defer {
        sh.running.store(false, .release);
        left.join();
        right.join();
    }

    var aw: Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    while (sh.running.load(.acquire)) {
        try draw(io, &aw, hOut);
        io.sleep(.fromMilliseconds(250), .awake) catch break;
    }
}
