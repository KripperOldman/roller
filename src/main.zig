const std = @import("std");
const pcre2 = @import("pcre2.zig");
const Regex = pcre2.Regex;
const color = @import("color.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const ally = gpa.allocator();
    var re: Regex = undefined;

    const pattern = "abc+";
    switch (try Regex.init(ally, pattern, .{})) {
        .ok => |regex| {
            re = regex;
        },
        .fail => |err| {
            var padding = std.ArrayList(u8).init(ally);
            defer padding.deinit();
            try padding.appendNTimes(' ', err.offset);
            std.debug.print(
                \\Error {} compiling pattern at position {}:
                \\"{s}"
                \\{s}^
                \\
            , .{ err.code, err.offset, pattern, padding.items });
            std.process.exit(1);
        },
    }
    defer re.deinit();

    const s = "fldkajsabcccccaldkjabc";
    var offset: usize = 0;

    while (true) {
        const res = try re.match(s, offset, .{});
        switch (res) {
            .ok => |match| {
                defer ally.destroy(match);
                defer offset = match.end;

                const writer = std.io.getStdOut().writer();
                _ = try writer.write(s[0..match.start]);
                try color.writeColorized(
                    writer,
                    @intFromEnum(color.StandardColors.BrightRed),
                    s[match.start..match.end],
                );
                _ = try writer.write(s[match.end..]);
                try writer.writeByte('\n');
            },
            .fail => |err| {
                std.debug.print("Error: {s}\n", .{@tagName(err)});
                break;
            },
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
