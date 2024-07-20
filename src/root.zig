const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const color = @import("color.zig");
const pcre2 = @import("pcre2.zig");
const Regex = pcre2.Regex;
const testing = std.testing;

pub const Color8Pattern = struct {
    color: color.Color8,
    pattern: []const u8,
};

const ColoringData8 = struct {
    start: usize,
    end: usize,
    color: color.Color8,
};

pub fn colorizePatterns(
    allocator: Allocator,
    reader: anytype,
    writer: anytype,
    colorPatterns: []const Color8Pattern,
) !void {
    var bw = std.io.bufferedWriter(writer);
    const bufWriter = bw.writer();

    var compiledPatterns = try allocator.alloc(Regex, colorPatterns.len);
    defer allocator.free(compiledPatterns);
    for (colorPatterns, 0..) |colorPattern, i| {
        const compileResult = try Regex.init(allocator, colorPattern.pattern, .{});
        switch (compileResult) {
            .ok => |re| compiledPatterns[i] = re,
            .fail => return error.RegexCompilationError,
        }
    }
    defer {
        for (compiledPatterns) |re| {
            re.deinit();
        }
    }

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();
    const lineWriter = line.writer();

    while (reader.streamUntilDelimiter(lineWriter, '\n', null)) {
        defer line.clearRetainingCapacity();
        const str = line.items;

        var colorList = std.ArrayList(ColoringData8).init(allocator);
        defer colorList.deinit();
        for (colorPatterns, compiledPatterns) |colorPattern, re| {
            var offset: usize = 0;
            matchLoop: while (true) {
                switch (try re.match(str, offset, .{ .NOTEMPTY = true })) {
                    .ok => |match| {
                        defer {
                            offset = match.end;
                            allocator.destroy(match);
                        }

                        try colorList.append(ColoringData8{
                            .start = match.start,
                            .end = match.end,
                            .color = colorPattern.color,
                        });
                    },
                    .fail => |err| {
                        switch (err) {
                            .NoMatch => break :matchLoop,
                            else => return error.MatchError,
                        }
                    },
                }
            }
        }

        try writeWithColors(bufWriter, colorList.items, str);
        try bw.flush();
    } else |err| {
        switch (err) {
            error.EndOfStream => {},
            else => return err,
        }
    }
}

fn writeWithColors(
    writer: anytype,
    colorList: []ColoringData8,
    str: []const u8,
) !void {
    const lessThanFn = comptime struct {
        fn lessThanFn(_: void, lhs: ColoringData8, rhs: ColoringData8) bool {
            if (lhs.start == rhs.start) {
                return (rhs.end - rhs.start) < (lhs.end - lhs.start);
            } else {
                return lhs.start < rhs.start;
            }
        }
    }.lessThanFn;
    std.mem.sort(ColoringData8, colorList, {}, lessThanFn);

    var offset: usize = 0;
    for (colorList) |colorData| {
        defer offset = @max(offset, colorData.end);

        if (offset > colorData.start) {
            if (!builtin.is_test) {
                std.log.warn(
                    "Overlapping match at {}:{}",
                    .{ colorData.start, colorData.end },
                );
            }
            if (offset < colorData.end) {
                try color.writeColorized(
                    writer,
                    colorData.color,
                    str[offset..colorData.end],
                );
            }
        } else {
            _ = try writer.write(str[offset..colorData.start]);
            try color.writeColorized(
                writer,
                colorData.color,
                str[colorData.start..colorData.end],
            );
        }
    }

    _ = try writer.write(str[offset..]);
    try writer.writeByte('\n');
}

test "single pattern test" {
    const ally = std.testing.allocator;
    var buf = std.ArrayList(u8).init(ally);
    defer buf.deinit();
    const writer = buf.writer();

    const str = "___abcd12345hello\n";
    var stream = std.io.fixedBufferStream(str);
    const reader = stream.reader();

    const colorPatterns = [_]Color8Pattern{
        Color8Pattern{
            .pattern = "[a-z]*",
            .color = @intFromEnum(color.StandardColors.Blue),
        },
    };

    try colorizePatterns(ally, reader, writer, &colorPatterns);

    try testing.expectEqualStrings(
        "___\x1b[34mabcd\x1b[0m12345\x1b[34mhello\x1b[0m\n",
        buf.items,
    );
}

test "multi pattern test" {
    const ally = std.testing.allocator;
    var buf = std.ArrayList(u8).init(ally);
    defer buf.deinit();
    const writer = buf.writer();

    const str = "___abcd12345hello\n";
    var stream = std.io.fixedBufferStream(str);
    const reader = stream.reader();

    const colorPatterns = [_]Color8Pattern{
        Color8Pattern{
            .pattern = "[a-z]*",
            .color = @intFromEnum(color.StandardColors.Blue),
        },
        Color8Pattern{
            .pattern = "[0-9]*",
            .color = @intFromEnum(color.StandardColors.Red),
        },
    };

    try colorizePatterns(ally, reader, writer, &colorPatterns);

    try testing.expectEqualStrings(
        "___\x1b[34mabcd\x1b[0m\x1b[31m12345\x1b[0m\x1b[34mhello\x1b[0m\n",
        buf.items,
    );
}

test "multi line test" {
    const ally = std.testing.allocator;
    var buf = std.ArrayList(u8).init(ally);
    defer buf.deinit();
    const writer = buf.writer();

    const str =
        \\___abcd12345hello
        \\123kljl21lj
        \\
    ;
    var stream = std.io.fixedBufferStream(str);
    const reader = stream.reader();

    const colorPatterns = [_]Color8Pattern{
        Color8Pattern{
            .pattern = "[a-z]*",
            .color = @intFromEnum(color.StandardColors.Blue),
        },
        Color8Pattern{
            .pattern = "[0-9]*",
            .color = @intFromEnum(color.StandardColors.Red),
        },
    };

    try colorizePatterns(ally, reader, writer, &colorPatterns);

    try testing.expectEqualStrings(
        "___\x1b[34mabcd\x1b[0m\x1b[31m12345\x1b[0m\x1b[34mhello\x1b[0m\n" ++
            "\x1b[31m123\x1b[0m\x1b[34mkljl\x1b[0m\x1b[31m21\x1b[0m\x1b[34mlj\x1b[0m\n",
        buf.items,
    );
}

test "overlapping patterns test" {
    const ally = std.testing.allocator;
    var buf = std.ArrayList(u8).init(ally);
    defer buf.deinit();
    const writer = buf.writer();

    const str = "___abcd12345hello\n";

    var stream = std.io.fixedBufferStream(str);
    const reader = stream.reader();

    const colorPatterns1 = [_]Color8Pattern{
        Color8Pattern{
            .pattern = "_abc",
            .color = @intFromEnum(color.StandardColors.Blue),
        },
        Color8Pattern{
            .pattern = "bcd",
            .color = @intFromEnum(color.StandardColors.Red),
        },
    };

    try colorizePatterns(ally, reader, writer, &colorPatterns1);

    try testing.expectEqualStrings(
        "__\x1b[34m_abc\x1b[0m\x1b[31md\x1b[0m12345hello\n",
        buf.items,
    );
}

test "overlapping patterns out of order test" {
    const ally = std.testing.allocator;
    var buf = std.ArrayList(u8).init(ally);
    defer buf.deinit();
    const writer = buf.writer();

    const str = "___abcd12345hello\n";

    var stream = std.io.fixedBufferStream(str);
    const reader = stream.reader();

    const colorPatterns1 = [_]Color8Pattern{
        Color8Pattern{
            .pattern = "bcd",
            .color = @intFromEnum(color.StandardColors.Red),
        },
        Color8Pattern{
            .pattern = "_abc",
            .color = @intFromEnum(color.StandardColors.Blue),
        },
    };

    try colorizePatterns(ally, reader, writer, &colorPatterns1);

    try testing.expectEqualStrings(
        "__\x1b[34m_abc\x1b[0m\x1b[31md\x1b[0m12345hello\n",
        buf.items,
    );
}

test "fully overlapping patterns test" {
    const ally = std.testing.allocator;
    var buf = std.ArrayList(u8).init(ally);
    defer buf.deinit();
    const writer = buf.writer();

    const str = "___abcd12345hello\n";

    var stream = std.io.fixedBufferStream(str);
    const reader = stream.reader();

    const colorPatterns1 = [_]Color8Pattern{
        Color8Pattern{
            .pattern = "bc",
            .color = @intFromEnum(color.StandardColors.Red),
        },
        Color8Pattern{
            .pattern = "_abcd",
            .color = @intFromEnum(color.StandardColors.Blue),
        },
    };

    try colorizePatterns(ally, reader, writer, &colorPatterns1);

    try testing.expectEqualStrings(
        "__\x1b[34m_abcd\x1b[0m12345hello\n",
        buf.items,
    );
}

test "highlight longer match first test" {
    const ally = std.testing.allocator;
    var buf = std.ArrayList(u8).init(ally);
    defer buf.deinit();
    const writer = buf.writer();

    const str = "abc\n";

    var stream = std.io.fixedBufferStream(str);
    const reader = stream.reader();

    const colorPatterns1 = [_]Color8Pattern{
        Color8Pattern{
            .pattern = "bc",
            .color = @intFromEnum(color.StandardColors.Red),
        },
        Color8Pattern{
            .pattern = ".",
            .color = @intFromEnum(color.StandardColors.Black),
        },
    };

    try colorizePatterns(ally, reader, writer, &colorPatterns1);

    try testing.expectEqualStrings(
        "\x1b[30ma\x1b[0m\x1b[31mbc\x1b[0m\n",
        buf.items,
    );
}
