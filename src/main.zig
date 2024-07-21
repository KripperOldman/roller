const std = @import("std");
const Allocator = std.mem.Allocator;
const io = std.io;
const debug = std.debug;
const root = @import("root.zig");
const StandardColors = @import("color.zig").StandardColors;
const clap = @import("clap");

pub const std_options = .{
    .log_level = .warn,
};

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
    \\Usage: {0?s} [--color <pattern>]... [files]...
    \\Colorize text based on regex patterns.
    \\
    \\With no file, or when file is -, read standard input.
    \\
    \\
;

const examples =
    \\Examples:
    \\  {0?s} --red='[0-9]' f - g
    \\      Output contents of f, then stdin, then g, with numbers in red.
    \\  {0?s} --red='[a-zA-Z]' --blue='[0-9]'
    \\      Copy stdin to stdout, with letters in red and numbers in blue.
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
            const isStdin = std.mem.eql(u8, filename, "-");
            var file = if (isStdin)
                std.io.getStdIn()
            else
                try std.fs.cwd().openFile(filename, .{});

            defer if (!isStdin)
                file.close();

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

        try stderr.writeByte('\n');
        try stderr.print(examples, .{exe_arg});
        std.process.exit(0);
    } else if (args.usage != 0) {
        const stderr = std.io.getStdErr().writer();
        try stderr.print(usage, .{exe_arg});
        try stderr.print(examples, .{exe_arg});
        std.process.exit(0);
    }
}

fn verifyFilesExist(files: []const []const u8) !void {
    for (files) |file| {
        if (!std.mem.eql(u8, file, "-")) {
            try std.fs.cwd().access(file, .{});
        }
    }
}

fn getColorPatterns(allocator: Allocator, args: anytype) ![]root.Color8Pattern {
    var colorPatterns = std.ArrayList(root.Color8Pattern).init(allocator);
    errdefer colorPatterns.deinit();

    inline for (@typeInfo(StandardColors).Enum.fields) |color| {
        const mapped = comptime mapColorToFlag(@enumFromInt(color.value));

        if (mapped) |tag_name| {
            if (@field(args, tag_name)) |pat| {
                try colorPatterns.append(.{
                    .color = color.value,
                    .pattern = pat,
                });
            }
        }
    }

    return colorPatterns.toOwnedSlice();
}

fn mapColorToFlag(color: StandardColors) ?[]const u8 {
    return switch (color) {
        StandardColors.Bold => "bold",
        StandardColors.Black => "black",
        StandardColors.Red => "red",
        StandardColors.Green => "green",
        StandardColors.Yellow => "yellow",
        StandardColors.Blue => "blue",
        StandardColors.Magenta => "magenta",
        StandardColors.Cyan => "cyan",
        StandardColors.White => "white",
        StandardColors.BrightBlack => "gray",
        StandardColors.BrightRed => "bright-red",
        StandardColors.BrightGreen => "bright-green",
        StandardColors.BrightYellow => "bright-yellow",
        StandardColors.BrightBlue => "bright-blue",
        StandardColors.BrightMagenta => "bright-magenta",
        StandardColors.BrightCyan => "bright-cyan",
        StandardColors.BrightWhite => "bright-white",
        else => null,
    };
}

test {
    std.testing.refAllDecls(@This());
}
