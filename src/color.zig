const std = @import("std");

pub const Color256 = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const Color8 = u8;

pub const StandardColors = enum(Color8) {
    Reset = 0,
    Bold,
    Black = 30,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
    White,
    BrightBlack = 90,
    BrightRed,
    BrightGreen,
    BrightYellow,
    BrightBlue,
    BrightMagenta,
    BrightCyan,
    BrightWhite,
};

pub fn writeColorized(writer: anytype, color_code: Color8, str: []const u8) !void {
    try std.fmt.format(writer, "\x1b[{d}m{s}\x1b[0m", .{ color_code, str });
}

test "writeColorized test" {
    const ally = std.testing.allocator;
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(ally);
    const writer = buf.writer(ally);

    try writeColorized(writer, @intFromEnum(StandardColors.Bold), "");
    try std.testing.expectEqualStrings(
        "\x1b[1m\x1b[0m",
        buf.items,
    );
    buf.clearAndFree(ally);

    try writeColorized(writer, @intFromEnum(StandardColors.Red), "Hello, World!");
    try std.testing.expectEqualStrings(
        "\x1b[31mHello, World!\x1b[0m",
        buf.items,
    );
    buf.clearAndFree(ally);

    try writeColorized(writer, @intFromEnum(StandardColors.BrightWhite), "Hello, World!");
    try std.testing.expectEqualStrings(
        "\x1b[97mHello, World!\x1b[0m",
        buf.items,
    );
    buf.clearAndFree(ally);
}
