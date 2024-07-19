const std = @import("std");
const Allocator = std.mem.Allocator;
const io = std.io;
const debug = std.debug;
const root = @import("root.zig");
const StandardColors = @import("color.zig").StandardColors;
const clap = @import("clap");

const params = clap.parseParamsComptime(
    \\-h, --help                      Display this help and exit.
    \\    --usage                     Display usage and exit.
    \\    --bold           <pattern>  Pattern to display in bold.
    \\    --black          <pattern>  Pattern to display in black.
    \\    --red            <pattern>  Pattern to display in red.
    \\    --green          <pattern>  Pattern to display in green.
    \\    --yellow         <pattern>  Pattern to display in yellow.
    \\    --blue           <pattern>  Pattern to display in blue.
    \\    --magenta        <pattern>  Pattern to display in magenta.
    \\    --cyan           <pattern>  Pattern to display in cyan.
    \\    --white          <pattern>  Pattern to display in white.
    \\    --gray           <pattern>  Pattern to display in gray.
    \\    --bright-red     <pattern>  Pattern to display in bright red.
    \\    --bright-green   <pattern>  Pattern to display in bright green.
    \\    --bright-yellow  <pattern>  Pattern to display in bright yellow.
    \\    --bright-blue    <pattern>  Pattern to display in bright blue.
    \\    --bright-magenta <pattern>  Pattern to display in bright magenta.
    \\    --bright-cyan    <pattern>  Pattern to display in bright cyan.
    \\    --bright-white   <pattern>  Pattern to display in bright white.
    \\<file>...
);

const usage =
    \\Colorize text based on regex patterns.
    \\With no file, or when file is -, read standard input.
    \\
    \\Usage: {?s} [--color <pattern>] [files]
    \\
    \\
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ally = gpa.allocator();

    const parsers = comptime .{
        .pattern = clap.parsers.string,
        .file = clap.parsers.string,
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = ally,
    }) catch |err| {
        diag.report(io.getStdErr().writer(), err) catch {};
        std.process.exit(1);
    };
    defer res.deinit();

    try handleHelpAndUsage(res.args, res.exe_arg.?);

    try verifyFilesExist(res.positionals);

    const colorPatterns = try getColorPatterns(ally, &res.args);
    defer ally.free(colorPatterns);

    if (res.positionals.len == 0) {
        try root.colorizePatterns(
            ally,
            io.getStdIn().reader(),
            io.getStdOut().writer(),
            colorPatterns,
        );
    } else {
        for (res.positionals) |filename| {
            var file = try std.fs.cwd().openFile(filename, .{});
            defer file.close();

            try root.colorizePatterns(
                ally,
                file.reader(),
                io.getStdOut().writer(),
                colorPatterns,
            );
        }
    }
}

fn handleHelpAndUsage(args: anytype, exe_arg: []const u8) !void {
    if (args.help != 0) {
        const stderr = std.io.getStdErr().writer();

        try stderr.print(usage, .{exe_arg});

        try clap.help(stderr, clap.Help, &params, .{
            .indent = 2,
            .max_width = 80,
            .description_on_new_line = false,
            .spacing_between_parameters = 0,
        });
        std.process.exit(0);
    } else if (args.usage != 0) {
        const stderr = std.io.getStdErr().writer();
        try stderr.print(usage, .{exe_arg});
        std.process.exit(0);
    }
}

fn verifyFilesExist(files: []const []const u8) !void {
    for (files) |file| {
        try std.fs.cwd().access(file, .{});
    }
}

fn getColorPatterns(allocator: Allocator, args: anytype) ![]root.Color8Pattern {
    var colorPatterns = std.ArrayList(root.Color8Pattern).init(allocator);
    errdefer colorPatterns.deinit();

    if (args.bold) |bold_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.Bold),
            .pattern = bold_pat,
        });
    }
    if (args.black) |black_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.Black),
            .pattern = black_pat,
        });
    }
    if (args.red) |red_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.Red),
            .pattern = red_pat,
        });
    }
    if (args.green) |green_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.Green),
            .pattern = green_pat,
        });
    }
    if (args.yellow) |yellow_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.Yellow),
            .pattern = yellow_pat,
        });
    }
    if (args.blue) |blue_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.Blue),
            .pattern = blue_pat,
        });
    }
    if (args.magenta) |magenta_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.Magenta),
            .pattern = magenta_pat,
        });
    }
    if (args.cyan) |cyan_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.Cyan),
            .pattern = cyan_pat,
        });
    }
    if (args.white) |white_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.White),
            .pattern = white_pat,
        });
    }
    if (args.gray) |gray_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.BrightBlack),
            .pattern = gray_pat,
        });
    }
    if (args.@"bright-red") |bright_red_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.BrightRed),
            .pattern = bright_red_pat,
        });
    }
    if (args.@"bright-green") |bright_green_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.BrightGreen),
            .pattern = bright_green_pat,
        });
    }
    if (args.@"bright-yellow") |bright_yellow_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.BrightYellow),
            .pattern = bright_yellow_pat,
        });
    }
    if (args.@"bright-blue") |bright_blue_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.BrightBlue),
            .pattern = bright_blue_pat,
        });
    }
    if (args.@"bright-magenta") |bright_magenta_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.BrightMagenta),
            .pattern = bright_magenta_pat,
        });
    }
    if (args.@"bright-cyan") |bright_cyan_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.BrightCyan),
            .pattern = bright_cyan_pat,
        });
    }
    if (args.@"bright-white") |bright_white_pat| {
        try colorPatterns.append(.{
            .color = @intFromEnum(StandardColors.BrightWhite),
            .pattern = bright_white_pat,
        });
    }

    return colorPatterns.toOwnedSlice();
}

test {
    std.testing.refAllDecls(@This());
}
