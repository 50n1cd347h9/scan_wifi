const std = @import("std");
const iw = @cImport(@cInclude("iwlib.h"));
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    const ifname: [:0]const u8 = "wlp5s0";

    try scanWifi(ifname);
}

fn handler(skfd: c_int, ifname: *c_char, args: *c_char, count: c_int) void {
    _ = skfd;
    stdout.print("found interface: %s\n", .{ifname});
    stdout.print("args : %s\n", .{args});
    stdout.print("count : %d\n", .{count});
}

fn scanWifi(ifname: [:0]const u8) !void {
    const allocator = std.heap.page_allocator;
    const tmp = try allocator.alloc(u8, 0x1000);
    allocator.free(tmp);

    const interface: [*c]u8 = @constCast(@ptrCast(ifname));
    var info: iw.wireless_info = undefined;
    var context: iw.wireless_scan_head = undefined;
    var range: iw.iwrange = undefined;
    var wl_info: iw.wireless_config = undefined;
    const toolname: [*c]u8 = @ptrCast(tmp);

    var num: c_int = 0;

    _ = &info;
    _ = toolname;

    const skfd: c_int = iw.iw_sockets_open();

    if (skfd < 0) {
        try stdout.print("Socket open failed", .{});
        return;
    }

    // iw_enum_handler fn = (iw_enum_handler)handler;
    // iw_enum_devices(skfd, fn, NULL, 0);
    // _ = iw.iw_print_version_info(toolname);
    // printf("toolname: %s\n", toolname);

    if (iw.iw_get_range_info(skfd, interface, &range) < 0) {
        try stdout.print("Failed to get range info", .{});
        iw.iw_sockets_close(skfd);
        return;
    }

    if (iw.iw_get_basic_config(skfd, interface, &wl_info) < 0) {
        try stdout.print("Failed to get priv info", .{});
        iw.iw_sockets_close(skfd);
        return;
    }

    if (iw.iw_scan(skfd, interface, range.we_version_compiled, &context) < 0) {
        try stdout.print("Scanning failed", .{});
        return;
    }

    var result: ?*iw.wireless_scan = context.result;
    while (result != null) : ({
        num += 1;
        result = result.?.next;
    }) {
        try stdout.print("SSID: {s}\n", .{result.?.b.essid});
        try stdout.print("Signal Level: {d} dBm\n", .{result.?.stats.qual.level});
    }

    if (num == 0) {
        try stdout.print("No access points found.\n", .{});
    }

    iw.iw_sockets_close(skfd);
}
