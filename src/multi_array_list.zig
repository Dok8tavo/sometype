// MIT License
//
// Copyright (c) 2025 Dok8tavo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

const std = @import("std");

pub const With = struct {
    item_type: ?type = null,
};

pub const Error = error{
    NotAStruct,
    IsTuple,
    /// There's no `Slice` declaration in the given type.
    NoSlice,
    /// The `Slice` declaration isn't a `type`.
    SliceNotAType,
    SliceTypeNotAStruct,
    SliceTypeIsTuple,
    /// There's no `get` declaration in the `Slice` declaration
    SliceNoGet,
    /// The `Slice.get` declaration isn't a function
    SliceGetNotAFunction,
    /// The `Slice.get` function doesn't have a return type
    SliceGetNoReturnType,
    /// The items of the given type aren't those specified in the `with` parameter.
    ItemNotItem,
    /// The `std.MultiArrayList` only supports structs and tagged unions
    UnsupportedItem,
    /// The given type respects a lot of requirements, but in the end wasn't returned from
    /// `std.MultiArrayList`.
    NotFromFunction,
};

pub inline fn expect(comptime T: type, comptime with: With) Error!void {
    comptime {
        const info = @typeInfo(T);

        if (info != .@"struct")
            return Error.NotAStruct;

        if (info.@"struct".is_tuple)
            return Error.IsTuple;

        if (!@hasDecl(T, "Slice"))
            return Error.NoSlice;

        if (@TypeOf(T.Slice) != type)
            return Error.SliceNotAType;

        const slice_info = @typeInfo(T.Slice);

        if (slice_info != .@"struct")
            return Error.SliceTypeNotAStruct;

        if (slice_info.@"struct".is_tuple)
            return Error.SliceTypeIsTuple;

        if (!@hasDecl(T.Slice, "get"))
            return Error.SliceNoGet;

        const get_info = @typeInfo(@TypeOf(T.Slice.get));

        if (get_info != .@"fn")
            return Error.SliceGetNotAFunction;

        if (get_info.@"fn".return_type == null)
            return Error.SliceGetNoReturnType;

        const Item = get_info.@"fn".return_type.?;

        switch (@typeInfo(Item)) {
            .@"union" => |u| if (u.tag_type == null)
                return Error.UnsupportedItem,
            .@"struct" => {},
            else => return Error.UnsupportedItem,
        }

        if (with.item_type) |item_type| if (item_type != get_info.@"fn".return_type.?)
            return Error.ItemNotItem;

        if (T != std.MultiArrayList(Item))
            return Error.NotFromFunction;
    }
}

pub inline fn assert(comptime T: type, comptime with: With) void {
    expect(T, with) catch |e| @compileError(logError(e, T, with));
}

pub inline fn logError(comptime e: Error, comptime T: type, comptime with: With) []const u8 {
    comptime {
        const fmt = std.fmt.comptimePrint;
        return fmt("The type `{s}` isn't a `std.MultiArrayList({s})` because {s}!", .{
            @typeName(T), if (with.item_type) |Item| @typeName(Item) else "...", switch (e) {
                Error.IsTuple => "it's a tuple",
                Error.ItemNotItem => fmt(
                    "its items are `{s}`",
                    .{@typeName(@typeInfo(T.Slice.get).@"fn".return_type.?)},
                ),
                Error.NoSlice => "it has no `Slice` declaration",
                Error.NotASruct => "it's not a `struct`",
                Error.NotFromFunction => "it's not a result of the right function",
                Error.SliceGetNoReturnType => "the `Slice.get` function has no clear return type",
                Error.SliceGetNotAFunction => fmt(
                    "the `Slice.get` declaration isn't a function but a `.{s}` instead",
                    .{@tagName(@typeInfo(@TypeOf(T.Slice.get)))},
                ),
                Error.SliceNoGet => "the `Slice` declaration doesn't have a `get` declaration",
                Error.SliceNotAType => fmt(
                    "its `Slice` declaration isn't a type but a `.{s}` insead",
                    .{@typeName(@TypeOf(T.Slice))},
                ),
                Error.SliceTypeIsTuple => "the `Slice` declaration is the type of a tuple",
                Error.SliceTypeNotAStruct => fmt(
                    "the `Slice` declaration isn't the type of a `struct` but a `.{s}` instead",
                    .{@tagName(@typeInfo(T.Slice))},
                ),
                Error.UnsupportedItem => fmt("its item type is a {s}, instead of a {s}", .{
                    switch (@typeInfo(T.Slice.get).@"fn".return_type.?) {
                        .@"union" => "`" ++
                            @typeName(@typeInfo(T.Slice.get).@"fn".return_type.?) ++
                            "` which is a bare union",
                        .@"struct" => unreachable,
                        else => "`" ++ @typeName(@typeInfo(T.Slice.get).@"fn".return_type.?) ++
                            "` which is a `." ++
                            @tagName(@typeInfo(@typeInfo(T.Slice.get).@"fn".return_type.?)) ++
                            "`",
                    },
                    "tagged union or a struct",
                }),
            },
        });
    }
}

pub inline fn Reify(comptime T: type, comptime with: With) type {
    assert(T, with);
    const Item = @typeInfo(@TypeOf(T.Slice.get)).@"fn".return_type.?;
    return std.MultiArrayList(Item);
}

pub inline fn reify(
    multi_array_list: anytype,
    comptime with: With,
) Reify(@TypeOf(multi_array_list), with) {
    return multi_array_list;
}

fn expectError(comptime T: type, comptime with: With, comptime err: Error) !void {
    try std.testing.expectError(err, expect(T, with));
}

test "expect(.{ .item_type = null })" {
    const with = With{ .item_type = null };

    try expect(std.MultiArrayList(union(enum) { lol, lmao }), with);

    inline for (@typeInfo(Error).error_set.?) |error_info| {
        const err: Error = @field(Error, error_info.name);
        try expectError(switch (err) {
            Error.NotAStruct => enum {},
            Error.IsTuple => struct { []const u8, bool },
            Error.NoSlice => struct { field: bool },
            Error.SliceNotAType => struct {
                pub const Slice = "Not a type";
            },
            Error.SliceTypeNotAStruct => struct {
                pub const Slice = @TypeOf("Not a struct");
            },
            Error.SliceTypeIsTuple => struct {
                pub const Slice = struct { @TypeOf("a tuple!") };
            },
            Error.SliceNoGet => struct {
                pub const Slice = struct {
                    pub const no = .get;
                };
            },
            Error.SliceGetNotAFunction => struct {
                pub const Slice = struct {
                    pub const get = .not_a_function;
                };
            },
            Error.SliceGetNoReturnType => struct {
                pub const Slice = struct {
                    pub fn get(comptime T: type) T {
                        return undefined;
                    }
                };
            },
            Error.UnsupportedItem => struct {
                pub const Slice = struct {
                    pub fn get() u8 {
                        return 0;
                    }
                };
            },
            Error.NotFromFunction => struct {
                pub const Slice = struct {
                    pub fn get() struct { u8 } {
                        return .{0};
                    }
                };
            },
            // impossible to reach with `.item_type = null`
            Error.ItemNotItem => continue,
        }, with, err);
    }
}

test "expect(.{ .item_type = ... })" {
    const Item = struct { field_1: usize, field_2: []const u8 };
    const NotItem = struct { field_1: usize, field_2: []const u8 };
    const with = With{ .item_type = Item };

    try expect(std.MultiArrayList(Item), with);

    inline for (@typeInfo(Error).error_set.?) |error_info| {
        const err: Error = @field(Error, error_info.name);
        try expectError(switch (err) {
            Error.NotAStruct => enum {},
            Error.IsTuple => struct { []const u8, bool },
            Error.NoSlice => struct { field: bool },
            Error.SliceNotAType => struct {
                pub const Slice = "Not a type";
            },
            Error.SliceTypeNotAStruct => struct {
                pub const Slice = @TypeOf("Not a struct");
            },
            Error.SliceTypeIsTuple => struct {
                pub const Slice = struct { @TypeOf("a tuple!") };
            },
            Error.SliceNoGet => struct {
                pub const Slice = struct {
                    pub const no = .get;
                };
            },
            Error.SliceGetNotAFunction => struct {
                pub const Slice = struct {
                    pub const get = .not_a_function;
                };
            },
            Error.SliceGetNoReturnType => struct {
                pub const Slice = struct {
                    pub fn get(comptime T: type) T {
                        return undefined;
                    }
                };
            },
            Error.UnsupportedItem => struct {
                pub const Slice = struct {
                    pub fn get() u8 {
                        return 0;
                    }
                };
            },
            Error.ItemNotItem => struct {
                pub const Slice = struct {
                    pub fn get() NotItem {
                        return undefined;
                    }
                };
            },
            Error.NotFromFunction => struct {
                pub const Slice = struct {
                    pub fn get() Item {
                        return undefined;
                    }
                };
            },
        }, with, err);
    }
}
