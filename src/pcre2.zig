const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const pcre2 = @cImport({
    @cDefine("PCRE2_STATIC", {});
    @cDefine("PCRE2_CODE_UNIT_WIDTH", "8");
    @cInclude("pcre2.h");
});

pub const CompiledCode = pcre2.pcre2_code_8;

pub const CompileError = struct {
    code: c_int,
    offset: usize,
};

pub const CompileOptions = packed struct(u32) {
    ALLOW_EMPTY_CLASS: bool = false,
    ALT_BSUX: bool = false,
    AUTO_CALLOUT: bool = false,
    CASELESS: bool = false,
    DOLLAR_ENDONLY: bool = false,
    DOTALL: bool = false,
    DUPNAMES: bool = false,
    EXTENDED: bool = false,
    FIRSTLINE: bool = false,
    MATCH_UNSET_BACKREF: bool = false,
    MULTILINE: bool = false,
    NEVER_UCP: bool = false,
    NEVER_UTF: bool = false,
    NO_AUTO_CAPTURE: bool = false,
    NO_AUTO_POSSESS: bool = false,
    NO_DOTSTAR_ANCHOR: bool = false,
    NO_START_OPTIMIZE: bool = false,
    UCP: bool = false,
    UNGREEDY: bool = false,
    UTF: bool = false,
    NEVER_BACKSLASH_C: bool = false,
    ALT_CIRCUMFLEX: bool = false,
    ALT_VERBNAMES: bool = false,
    USE_OFFSET_LIMIT: bool = false,
    EXTENDED_MORE: bool = false,
    LITERAL: bool = false,
    MATCH_INVALID_UTF: bool = false,
    _reserved1: u2 = 0,
    ENDANCHORED: bool = false,
    NO_UTF_CHECK: bool = false,
    ANCHORED: bool = false,
};

const ResultEnum = enum { ok, fail };
pub const CompileResult = union(ResultEnum) {
    ok: Regex,
    fail: *CompileError,
};

pub const MatchOptions = packed struct(u32) {
    NOTBOL: bool = false,
    NOTEOL: bool = false,
    NOTEMPTY: bool = false,
    NOTEMPTY_ATSTART: bool = false,
    PARTIAL_SOFT: bool = false,
    PARTIAL_HARD: bool = false,
    _reserved1: u7 = 0,
    NO_JIT: bool = false,
    COPY_MATCHED_SUBJECT: bool = false,
    _reserved2: u14 = 0,
    ENDANCHORED: bool = false,
    NO_UTF_CHECK: bool = false,
    ANCHORED: bool = false,
};
pub const Match = struct {
    start: usize,
    end: usize,
};
pub const MatchError = enum(c_int) {
    NoMatch = pcre2.PCRE2_ERROR_NOMATCH,
    Partial = pcre2.PCRE2_ERROR_PARTIAL,
    BadMagic = pcre2.PCRE2_ERROR_BADMAGIC,
    BadMode = pcre2.PCRE2_ERROR_BADMODE,
    BadOffset = pcre2.PCRE2_ERROR_BADOFFSET,
    BadOption = pcre2.PCRE2_ERROR_BADOPTION,
    BadUtfOffset = pcre2.PCRE2_ERROR_BADUTFOFFSET,
    Callout = pcre2.PCRE2_ERROR_CALLOUT,
    DepthLimit = pcre2.PCRE2_ERROR_DEPTHLIMIT,
    HeapLimit = pcre2.PCRE2_ERROR_HEAPLIMIT,
    Internal = pcre2.PCRE2_ERROR_INTERNAL,
    JitStacklimit = pcre2.PCRE2_ERROR_JIT_STACKLIMIT,
    MatchLimit = pcre2.PCRE2_ERROR_MATCHLIMIT,
    NoMemory = pcre2.PCRE2_ERROR_NOMEMORY,
    Null = pcre2.PCRE2_ERROR_NULL,
    RecurseLoop = pcre2.PCRE2_ERROR_RECURSELOOP,
    _,
};
pub const MatchResult = union(ResultEnum) {
    ok: *Match,
    fail: MatchError,
};

pub const Regex = struct {
    allocator: Allocator,
    compiledCode: *CompiledCode,

    pub fn init(allocator: Allocator, pattern: []const u8, options: ?CompileOptions) !CompileResult {
        const opts = options orelse CompileOptions{};
        var err = try allocator.create(CompileError);
        const compilationResult = pcre2.pcre2_compile_8(
            pattern.ptr,
            pattern.len,
            @bitCast(opts),
            &err.code,
            &err.offset,
            null,
        );

        if (compilationResult) |compiled| {
            allocator.destroy(err);
            return CompileResult{
                .ok = Regex{
                    .allocator = allocator,
                    .compiledCode = compiled,
                },
            };
        } else {
            return CompileResult{ .fail = err };
        }
    }

    pub fn deinit(self: Regex) void {
        pcre2.pcre2_code_free_8(self.compiledCode);
    }

    pub fn match(self: Regex, string: []const u8, offset: usize, options: ?MatchOptions) !MatchResult {
        const opts = options orelse MatchOptions{};
        const matchData = pcre2.pcre2_match_data_create_8(1, null).?;
        defer pcre2.pcre2_match_data_free_8(matchData);

        const returnCode = pcre2.pcre2_match_8(
            self.compiledCode,
            string.ptr,
            string.len,
            offset,
            @bitCast(opts),
            matchData,
            null,
        );

        if (returnCode < 0) {
            return MatchResult{ .fail = @enumFromInt(returnCode) };
        } else {
            const ovector = pcre2.pcre2_get_ovector_pointer_8(matchData);
            var matched = try self.allocator.create(Match);

            matched.start = ovector[0];
            matched.end = ovector[1];

            return MatchResult{ .ok = matched };
        }
    }
};

test "compile success" {
    const ally = testing.allocator;
    const pattern = "abc+";

    switch (try Regex.init(ally, pattern, .{})) {
        .ok => |re| re.deinit(),
        .fail => try testing.expect(false),
    }
}

test "compile fail" {
    const ally = testing.allocator;
    const pattern = "abc+\\";

    switch (try Regex.init(ally, pattern, .{})) {
        .ok => try testing.expect(false),
        .fail => |err| {
            defer ally.destroy(err);
            try testing.expectEqualDeep(CompileError{
                .code = 101,
                .offset = 5,
            }, err.*);
        },
    }
}

test "match test" {
    const ally = testing.allocator;
    var re: Regex = undefined;

    const pattern = "abc+";
    switch (try Regex.init(ally, pattern, .{})) {
        .ok => |regex| {
            re = regex;
        },
        .fail => try testing.expect(false),
    }
    defer re.deinit();

    const s = "fldkajsabcccccaldkjabc";
    var res = try re.match(s, 0, .{});
    switch (res) {
        .ok => |match| {
            defer ally.destroy(match);
            try testing.expectEqualDeep(
                Match{ .start = 7, .end = 14 },
                match.*,
            );
        },
        .fail => try testing.expect(false),
    }

    res = try re.match(s, 14, .{});
    switch (res) {
        .ok => |match| {
            defer ally.destroy(match);
            try testing.expectEqualDeep(
                Match{ .start = 19, .end = 22 },
                match.*,
            );
        },
        .fail => try testing.expect(false),
    }

    res = try re.match(s, 22, .{});
    switch (res) {
        .ok => try testing.expect(false),
        .fail => |err| {
            try testing.expectEqual(err, MatchError.NoMatch);
        },
    }
}
