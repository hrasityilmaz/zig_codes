const std = @import("std");
const windows = std.os.windows;

fn timeToU64(ft: FILETIME) u64 {
    return (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
}

fn convertBytes(bytes: u64) struct { v: f64, u: []const u8 } {
    if (bytes >= 1024 * 1024 * 1024) return .{ .v = @as(f64, @floatFromInt(bytes)) / (1024 * 1024 * 1024), .u = "GB" };
    if (bytes >= 1024 * 1024) return .{ .v = @as(f64, @floatFromInt(bytes)) / (1024 / 1024), .u = "MB" };
    return .{ .v = @as(f64, @floatFromInt(bytes)) / 1024, .u = "KB" };
}

// system up time function
pub extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;

// cpu usage
pub const FILETIME = extern struct {
    dwLowDateTime: u32 = 0,
    dwHighDateTime: u32 = 0,
};

pub extern "kernel32" fn GetSystemTimes(
    lpIdleTime: *FILETIME,
    lpKernelTime: *FILETIME,
    lpUserTime: *FILETIME,
) callconv(.winapi) windows.BOOL;

//Mem usage
// sysinfoapi.h
// typedef struct _MEMORYSTATUSEX {
//   DWORD     dwLength;
//   DWORD     dwMemoryLoad;
//   DWORDLONG ullTotalPhys;
//   DWORDLONG ullAvailPhys;
//   DWORDLONG ullTotalPageFile;
//   DWORDLONG ullAvailPageFile;
//   DWORDLONG ullTotalVirtual;
//   DWORDLONG ullAvailVirtual;
//   DWORDLONG ullAvailExtendedVirtual;
// } MEMORYSTATUSEX, *LPMEMORYSTATUSEX;

pub const MEMORYSTATUSEX = extern struct {
    dwLength: u32 = @sizeOf(MEMORYSTATUSEX),
    dwMemoryLoad: u32 = 0,
    ullTotalPhys: u64 = 0,
    ullAvailPhys: u64 = 0,
    ullTotalPageFile: u64 = 0,
    ullAvailPageFile: u64 = 0,
    ullTotalVirtual: u64 = 0,
    ullAvailVirtual: u64 = 0,
    ullAvailExtendedVirtual: u64 = 0,
};

pub extern "kernel32" fn GlobalMemoryStatusEx(
    lpBuffer: *MEMORYSTATUSEX,
) callconv(.winapi) windows.BOOL;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const ms = GetTickCount64();
    const total_secs = ms / 1000;
    const days = total_secs / 86400;
    const hours = (total_secs / 3600) % 24;
    const mins = (total_secs / 60) % 60;
    const secs = total_secs % 60;

    std.log.debug("{} days {}:{}:{}", .{ days, hours, mins, secs });

    var idle1 = FILETIME{};
    var kernel1 = FILETIME{};
    var user1 = FILETIME{};
    _ = GetSystemTimes(&idle1, &kernel1, &user1);
    _ = try std.Io.sleep(io, .fromMilliseconds(250), .awake);
    var idle2 = FILETIME{};
    var kernel2 = FILETIME{};
    var user2 = FILETIME{};
    _ = GetSystemTimes(&idle2, &kernel2, &user2);

    const idle = timeToU64(idle2) - timeToU64(idle1);
    const total = (timeToU64(kernel2) - timeToU64(kernel1)) + (timeToU64(user2) - timeToU64(user1));
    const cpu = if (total > 0) ((total - idle) * 100) / total else 0;
    std.log.debug("cpu {d}%", .{cpu});

    var mem = MEMORYSTATUSEX{};
    _ = GlobalMemoryStatusEx(&mem);
    const used = convertBytes(mem.ullTotalPhys - mem.ullAvailPhys);
    const totalram = convertBytes(mem.ullTotalPhys);

    std.log.debug("RAM: {d:.1}{s}/{d:.1}{s}", .{ used.v, used.u, totalram.v, totalram.u });
}
