const std = @import("std");
const windows = std.os.windows;
//
// \x1b[30m Black
// \x1b[31m Red
// \x1b[32m Green
// \x1b[33m Yellow
// \x1b[34m Blue
// \x1b[35m Magenta
// \x1b[36m Cyan
// \x1b[37m White
// \x1b[9Xm Brighter (90-97)
// \x1b[1m  Bold
// \x1b[0m  RESET
//
//

//HANDLE WINAPI GetStdHandle(NDLE WINAPI GetStdHandle(
//      _In_ DWORD nStdHandle
//      );
//)
// can return null
pub extern "kernel32" fn GetStdHandle(u32) callconv(.winapi) ?windows.HANDLE;

// BOOL WINAPI GetConsoleMode(
//   _In_  HANDLE  hConsoleHandle,
//   _Out_ LPDWORD lpMode
// );
//
pub extern "kernel32" fn GetConsoleMode(windows.HANDLE, *u32) callconv(.winapi) windows.BOOL;

// BOOL WINAPI SetConsoleMode(
//   _In_ HANDLE hConsoleHandle,
//   _In_ DWORD  dwMode
// );
//
pub extern "kernel32" fn SetConsoleMode(windows.HANDLE, u32) callconv(.winapi) windows.BOOL;

//BOOL WINAPI GetConsoleScreenBufferInfo(
//   _In_  HANDLE                      hConsoleOutput,
//   _Out_ PCONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo
// );
//
pub extern "kernel32" fn GetConsoleScreenBufferInfo(windows.HANDLE, *CSBI) callconv(.winapi) windows.BOOL;

//typedef struct _COORD {
//   SHORT X;
//   SHORT Y;
// } COORD, *PCOORD;
pub const COORD = extern struct { X: i16, Y: i16 };
pub const SMALL_RECT = extern struct { Left: i16, Top: i16, Right: i16, Bottom: i16 };

//typedef struct _CONSOLE_SCREEN_BUFFER_INFO {
//   COORD      dwSize;
//   COORD      dwCursorPosition;
//   WORD       wAttributes;
//   SMALL_RECT srWindow;
//   COORD      dwMaximumWindowSize;
// } CONSOLE_SCREEN_BUFFER_INFO;
const CSBI = extern struct {
    dwSize: COORD = .{ .X = 0, .Y = 0 },
    dwCursorPosition: COORD = .{ .X = 0, .Y = 0 },
    wAttributes: u16 = 0,
    srWindow: SMALL_RECT = .{ .Left = 0, .Top = 0, .Right = 0, .Bottom = 0 },
    dwMaxWindowSize: COORD = .{ .X = 0, .Y = 0 },
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const STD_OUTPUT: u32 = @bitCast(@as(i32, -11));
    const hOut = GetStdHandle(STD_OUTPUT) orelse return error.NoHandle;

    var mode: u32 = 0;
    _ = GetConsoleMode(hOut, &mode);
    _ = SetConsoleMode(hOut, mode | 0x0004); //ENABLE_VIRTUAL_TERMINAL_PROCESSING ansi support

    var csbi = CSBI{};
    _ = GetConsoleScreenBufferInfo(hOut, &csbi);
    const cols: usize = @intCast(csbi.srWindow.Right - csbi.srWindow.Left + 1);
    const rows: usize = @intCast(csbi.srWindow.Bottom - csbi.srWindow.Top + 1);

    //std.log.info("cols {}, rows {}", .{ cols, rows });

    const msg: [:0]const u8 = "Hello Tui!";
    const col = (cols - msg.len) / 2;
    const row = rows / 2;
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writer(io, &buffer);
    //const out = &std_out.interface;
    try out.interface.print("\x1b[2J\x1b[?25l", .{});
    try out.interface.print("\x1b[{d};{d}H", .{ row, col });
    try out.interface.print("\x1b[1m\x1b[0m{s}\x1b[0m", .{msg});
    try out.interface.print("\x1b[{d};1H\x1b[?25h", .{rows});
    try out.flush();
}
