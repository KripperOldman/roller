const std = @import("std");

pub const Color24 = struct {
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

pub fn writeColorizedRGB(writer: anytype, color: Color24, str: []const u8) !void {
    try std.fmt.format(
        writer,
        "\x1b[38;2;{d};{d};{d}m{s}\x1b[0m",
        .{ color.r, color.g, color.b, str },
    );
}

test "writeColorized 8 bit test" {
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

test "writeColorized 24 bit test" {
    const ally = std.testing.allocator;
    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(ally);
    const writer = buf.writer(ally);

    try writeColorizedRGB(writer, Color24{ .r = 0, .g = 0, .b = 0 }, "");
    try std.testing.expectEqualStrings(
        "\x1b[38;2;0;0;0m\x1b[0m",
        buf.items,
    );
    buf.clearAndFree(ally);

    try writeColorizedRGB(writer, Color24{ .r = 255, .g = 255, .b = 255 }, "Hello, World!");
    try std.testing.expectEqualStrings(
        "\x1b[38;2;255;255;255mHello, World!\x1b[0m",
        buf.items,
    );
    buf.clearAndFree(ally);

    try writeColorizedRGB(writer, Color24{ .r = 132, .g = 223, .b = 94 }, "Hello, World!");
    try std.testing.expectEqualStrings(
        "\x1b[38;2;132;223;94mHello, World!\x1b[0m",
        buf.items,
    );
    buf.clearAndFree(ally);
}
