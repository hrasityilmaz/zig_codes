const std = @import("std");
const Io = std.Io;

const warn = std.log.warn;
const info = std.log.info;

const Account = struct { name: [:0]const u8, balance: i64, mutex: std.Io.Mutex = .init };

var acc_a = Account{
    .name = "A_BANK",
    .balance = 1000,
};
var acc_b = Account{
    .name = "B_BANK",
    .balance = 1000,
};

fn transfer(from: *Account, to: *Account, amount: i64, io: Io) !void {
    const first = if (@intFromPtr(from) < @intFromPtr(to)) from else to;
    const second = if (@intFromPtr(from) < @intFromPtr(to)) to else from;

    try first.mutex.lock(io);
    try second.mutex.lock(io);
    defer first.mutex.unlock(io);
    defer second.mutex.unlock(io);

    if (from.balance < amount) {
        warn("!!! Not Enough! {d}->{d}", .{ from.balance, amount });
        return;
    }

    from.balance -= amount;
    to.balance += amount;

    info("Transfer succeeded! {s}->{s} {}$\n", .{ from.name, to.name, amount });
    try io.sleep(.fromMilliseconds(15), .awake);
}

fn @"sendA->B"(io: Io) !void {
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try transfer(&acc_a, &acc_b, 100, io);
        try io.sleep(.fromMilliseconds(10), .awake);
    }
}

fn @"sendB->A"(io: Io) !void {
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        try transfer(&acc_b, &acc_a, 100, io);
        try io.sleep(.fromMilliseconds(10), .awake);
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    info("BankA Account before transfers: {d}", .{acc_a.balance});
    info("BankB Account before transfer {d}", .{acc_b.balance});

    const transfer1 = try std.Thread.spawn(.{}, @"sendA->B", .{io});
    const transfer2 = try std.Thread.spawn(.{}, @"sendB->A", .{io});

    transfer1.join();
    transfer2.join();

    info("BankA Account after transfer {d}", .{acc_a.balance});
    info("BankB Account after transfer {d}", .{acc_b.balance});
}
