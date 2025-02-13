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
    Item: ?type = null,
};

pub const Error = error{
    NotAStruct,
    IsTuple,
    /// There's no `Slice` declaration in the given type.
    NoSlice,
    /// The `Slice` declaration isn't a `type`.
    SliceNotAType,
    SliceNotAStructType,
    SliceIsTupleType,
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
            return Error.SliceNotAStructType;

        if (slice_info.@"struct".is_tuple)
            return Error.SliceIsTupleType;

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

        if (with.Item) |item_type| if (item_type != get_info.@"fn".return_type.?)
            return Error.ItemNotItem;

        if (T != std.MultiArrayList(Item))
            return Error.NotFromFunction;
    }
}

pub inline fn assert(comptime T: type, comptime with: With) void {
    comptime expect(T, with) catch |e| @compileError(logError(e, T, with));
}

pub inline fn logError(comptime e: Error, comptime T: type, comptime with: With) []const u8 {
    comptime {
        const fmt = std.fmt.comptimePrint;
        return fmt("The type `{s}` isn't a `std.MultiArrayList({s})` because {s}!", .{
            @typeName(T), if (with.Item) |Item| @typeName(Item) else "...", switch (e) {
                Error.IsTuple => "it's a tuple",
                Error.ItemNotItem => fmt(
                    "its items are `{s}`",
                    .{@typeName(@typeInfo(T.Slice.get).@"fn".return_type.?)},
                ),
                Error.NoSlice => "it has no `Slice` declaration",
                Error.NotAStruct => "it's not a `struct`",
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
                Error.SliceIsTupleType => "the `Slice` declaration is the type of a tuple",
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
) *const Reify(@TypeOf(multi_array_list.*), with) {
    return multi_array_list;
}

pub inline fn reifyVar(
    multi_array_list_ptr: anytype,
    comptime with: With,
) *Reify(@TypeOf(multi_array_list_ptr.*), with) {
    return multi_array_list_ptr;
}

fn expectError(comptime T: type, comptime with: With, comptime err: Error) !void {
    try std.testing.expectError(err, expect(T, with));
}

test expect {
    // anything that's passed to `std.MultiArrayList` will work
    try expect(std.MultiArrayList(union(enum) {}), .{});
    try expect(std.MultiArrayList(struct {}), .{});

    // if a `with.Item` is given, it can reach a `Error.ItemNotItem`
    const Item = struct { field: bool };
    try expect(std.MultiArrayList(Item), .{ .Item = Item });
    try expectError(std.MultiArrayList(struct {}), .{ .Item = Item }, Error.ItemNotItem);

    // an `Error.NotAStruct` occurs when passing a non-struct type
    try expectError(enum { not_a_struct }, .{}, Error.NotAStruct);

    // an `Error.IsTuple` occurs when passing a tuple type
    try expectError(struct { @TypeOf(.is_a_tuple) }, .{}, Error.IsTuple);

    // an `Error.NoSlice` occurs when the passed struct type doesn't have a `Slice` declaration
    try expectError(struct {
        is_a_struct: bool = true,
        has_a_slice_declaration: bool = false,
    }, .{}, Error.NoSlice);

    // an `Error.SliceNotAType` occurs when the `Slice` declaration of the passed struct type isn't
    // a type
    try expectError(struct {
        is_a_struct: bool = true,
        has_a_slice_declaration: bool = true,
        slice_is_a_type: bool = false,

        pub const Slice = .is_not_a_type;
    }, .{}, Error.SliceNotAType);

    // an `Error.SliceNotAStructType` occurs when the `Slice` declaration of the passed struct type
    // isn't a struct type itself
    try expectError(struct {
        is_a_struct: bool = true,
        has_a_slice_declaration: bool = true,
        slice_is_a_type: bool = true,
        slice_is_a_struct_type: bool = false,

        pub const Slice = @TypeOf(.not_a_struct);
    }, .{}, Error.SliceNotAStructType);

    // an `Error.SliceIsTupleType` occurs when the `Slice` declaration of the passed struct type is
    // a tuple type
    try expectError(struct {
        is_a_struct: bool = true,
        has_a_slice_declaration: bool = true,
        slice_is_a_type: bool = true,
        slice_is_a_struct_type: bool = true,
        slice_isnt_a_tuple_type: bool = false,

        pub const Slice = struct { @TypeOf("field of a tuple") };
    }, .{}, Error.SliceIsTupleType);

    // an `Error.SliceNoGet` occurs when the `Slice` declaration of the passed struct type has no
    // `get` declaration
    try expectError(struct {
        is_a_struct: bool = true,
        has_a_slice_declaration: bool = true,
        slice_is_a_type: bool = true,
        slice_is_a_struct_type: bool = true,
        slice_isnt_a_tuple_type: bool = true,
        slice_has_a_get_declaration: bool = false,

        pub const Slice = struct {
            pub const not_get = "declaration";
        };
    }, .{}, Error.SliceNoGet);

    // an `Error.SliceGetNotAFunction` occurs when the `Slice.get` declaration of the passed struct
    // type isn't a function
    try expectError(struct {
        is_a_struct: bool = true,
        has_a_slice_declaration: bool = true,
        slice_is_a_type: bool = true,
        slice_is_a_struct_type: bool = true,
        slice_isnt_a_tuple_type: bool = true,
        slice_has_a_get_declaration: bool = true,
        slice_get_isnt_a_function: bool = false,

        pub const Slice = struct {
            pub const get = .not_a_function;
        };
    }, .{}, Error.SliceGetNotAFunction);

    // an `Error.SliceGetNoReturnType` occurs when the `Slice.get` function of the passed struct
    // type doesn't have a return type
    try expectError(struct {
        is_a_struct: bool = true,
        has_a_slice_declaration: bool = true,
        slice_is_a_type: bool = true,
        slice_is_a_struct_type: bool = true,
        slice_isnt_a_tuple_type: bool = true,
        slice_has_a_get_declaration: bool = true,
        slice_get_isnt_a_function: bool = true,
        slice_get_has_a_return_type: bool = false,

        pub const Slice = struct {
            pub fn get(comptime T: type) T {
                return undefined;
            }
        };
    }, .{}, Error.SliceGetNoReturnType);

    // an `Error.SliceGetNoReturnType` occurs when the `Slice.get` function of the passed struct
    // type doesn't have a return type
    try expectError(struct {
        is_a_struct: bool = true,
        has_a_slice_declaration: bool = true,
        slice_is_a_type: bool = true,
        slice_is_a_struct_type: bool = true,
        slice_isnt_a_tuple_type: bool = true,
        slice_has_a_get_declaration: bool = true,
        slice_get_isnt_a_function: bool = true,
        slice_get_has_a_return_type: bool = true,

        pub const Slice = struct {
            pub fn get(comptime T: type) T {
                return undefined;
            }
        };
    }, .{}, Error.SliceGetNoReturnType);

    // an `Error.UnsupportedItem` occurs when the `Slice.get` return type isn't supported by the
    // `std.MultiArrayList` interface
    try expectError(struct {
        is_a_struct: bool = true,
        has_a_slice_declaration: bool = true,
        slice_is_a_type: bool = true,
        slice_is_a_struct_type: bool = true,
        slice_isnt_a_tuple_type: bool = true,
        slice_has_a_get_declaration: bool = true,
        slice_get_isnt_a_function: bool = true,
        slice_get_has_a_return_type: bool = true,
        silce_get_return_type_is_supported: bool = false,

        pub const Slice = struct {
            pub fn get() union { untagged: void } {
                return undefined;
            }
        };
    }, .{}, Error.UnsupportedItem);

    // an `Error.NotFromFunction` occurs when even though all other condition was fullfilled,
    // the given type doesn't come from `std.MultiArrayList`
    try expectError(struct {
        is_a_struct: bool = true,
        has_a_slice_declaration: bool = true,
        slice_is_a_type: bool = true,
        slice_is_a_struct_type: bool = true,
        slice_isnt_a_tuple_type: bool = true,
        slice_has_a_get_declaration: bool = true,
        slice_get_isnt_a_function: bool = true,
        slice_get_has_a_return_type: bool = true,
        silce_get_return_type_is_supported: bool = true,

        pub const Slice = struct {
            pub fn get() union(enum) { tagged: void } {
                return undefined;
            }
        };
    }, .{}, Error.NotFromFunction);

    // we can even make a structural equivalent of a multi-array list
    const MultiArrayList = std.MultiArrayList(Item);
    const NotMultiArrayList = struct {
        bytes: [*]align(@alignOf(Item)) u8 = undefined,
        len: usize = 0,
        capacity: usize = 0,

        // this doesn't exactly make `NotMultiArrayList` an actual structural equivalent of
        // `MultiArrayList`, but it's for the demonstration
        pub usingnamespace MultiArrayList;
    };

    try expect(MultiArrayList, .{});
    try expectError(NotMultiArrayList, .{}, Error.NotFromFunction);
}
