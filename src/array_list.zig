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
    /// This can't be null because the managed and unmanaged array lists have different APIs
    allocator: bool = true,
    alignment: ?Alignment = null,
    item_type: ?type = null,

    pub const Alignment = union(enum) {
        exact: u16,
        at_least: u16,
        at_least_natural,
        natural,
    };
};

pub const Error = error{
    NotAStruct,
    IsTuple,
    NoAllocator,
    HasAllocator,
    /// The `allocator` field isn't of type `std.mem.Allocator`.
    AllocatorNotAnAllocator,
    /// There's no `Slice` declaration in the given type.
    NoSlice,
    /// The `Slice` declaration isn't a `type`.
    SliceNotAType,
    /// The `Slice` declaration isn't the type of a pointer.
    SliceTypeNotAPointer,
    /// The `Slice` declaration isn't the type of a slice.
    SliceTypeNotASlice,
    /// The items of the given type aren't those specified in the `with` parameter.
    ItemNotItem,
    /// The alignment of the items isn't exactly the one specified in the `with` parameter.
    AlignmentNotExact,
    /// The alignment of the items doesn't guarantee the one specified in the `with` parameter.
    AlignmentTooSmall,
    /// The given type respects a lot of requirements, but in the end wasn't returned from
    /// `std.ArrayList` or its managed/aligned versions.
    NotFromFunction,
};

pub inline fn expect(comptime T: type, comptime with: With) Error!void {
    comptime {
        const info = @typeInfo(T);

        if (info != .@"struct")
            return Error.NotAStruct;

        if (info.@"struct".is_tuple)
            return Error.IsTuple;

        if (with.allocator != @hasField(T, "allocator")) return switch (with.allocator) {
            true => Error.NoAllocator,
            false => Error.HasAllocator,
        };

        if (with.allocator and (std.mem.Allocator != @TypeOf(@as(T, undefined).allocator)))
            return Error.AllocatorNotAnAllocator;

        if (!@hasDecl(T, "Slice"))
            return Error.NoSlice;

        if (@TypeOf(T.Slice) != type)
            return Error.SliceNotAType;

        const slice_info = @typeInfo(T.Slice);

        if (slice_info != .pointer)
            return Error.SliceTypeNotAPointer;

        if (slice_info.pointer.size != .slice)
            return Error.SliceTypeNotASlice;

        const Item = slice_info.pointer.child;
        const alignment = slice_info.pointer.alignment;

        if (with.item_type) |item_type| if (item_type != Item)
            return Error.ItemNotItem;

        if (with.alignment) |with_alignment| switch (with_alignment) {
            .exact => |exact_alignment| if (exact_alignment != alignment)
                return Error.AlignmentNotExact,
            .at_least => |least_alignment| if (alignment < least_alignment)
                return Error.AlignmentTooSmall,
            .at_least_natural => if (alignment < @alignOf(Item))
                return Error.AlignmentTooSmall,
            .natural => if (@alignOf(Item) != alignment)
                return Error.AlignmentNotExact,
        };

        const right_function = T == if (with.allocator)
            std.ArrayListAligned(Item, alignment)
        else
            std.ArrayListAlignedUnmanaged(Item, alignment);

        if (!right_function)
            return Error.NotFromFunction;
    }
}

pub inline fn assert(comptime T: type, comptime with: With) void {
    expect(T, with) catch |e| @compileError(logError(e, T, with));
}

pub inline fn logError(comptime e: Error, comptime T: type, comptime with: With) []const u8 {
    comptime {
        const fmt = std.fmt.comptimePrint;
        const isnt_array_list = fmt(
            "The type `{s}` isn't a `std.ArrayList{s}{s}({{s}})` because {{s}}!",
            .{
                @typeName(T),
                if (with.alignment) |_| "Aligned" else "",
                if (with.allocator) "" else "Unmanaged",
            },
        );

        const args = switch (e) {
            Error.AlignmentNotExact => fmt("..., {}", .{switch (with.alignment.?) {
                .exact => |exact| exact,
                .natural => @alignOf(@typeInfo(T.Slice).pointer.child),
                .at_least, .at_least_natural => unreachable,
            }}),
            Error.AlignmentTooSmall => fmt("..., >={}", .{switch (with.alignment.?) {
                .at_least => |at_least| at_least,
                .at_least_natural => @alignOf(@typeInfo(T.Slice).pointer.child),
                .exact, .natural => unreachable,
            }}),
            Error.ItemNotItem => fmt("{s}, ...", .{@typeName(with.item_type.?)}),
            else => "...",
        };

        const reason = switch (e) {
            Error.AlignmentNotExact, Error.AlignmentTooSmall => fmt(
                "its items alignment is {}",
                .{@typeInfo(T.Slice).pointer.alignment},
            ),
            Error.AllocatorNotAnAllocator => fmt(
                "its `allocator` field isn't a `std.mem.Allocator`, but `{s}` instead",
                .{@typeName(@TypeOf(@as(T, undefined).allocator))},
            ),
            Error.HasAllocator => "it's not supposed to bundle an allocator",
            Error.IsTuple => "it's a tuple",
            Error.ItemNotItem => fmt(
                "its items are `{s}`s",
                .{@typeName(@typeInfo(T.Slice).pointer.child)},
            ),
            Error.NoAllocator => "it's supposed to bundle an allocator",
            Error.NoSlice => "it has no `Slice` declaration",
            Error.NotAStruct => "it's not a `struct`",
            Error.NotFromFunction => "it's not a result of the right function",
            Error.SliceNotAType => fmt(
                "its `Slice` declaration isn't a type but a `{s}` insead",
                .{@typeName(@TypeOf(T.Slice))},
            ),
            Error.SliceTypeNotAPointer => fmt(
                "its `Slice` declaration isn't the type of a pointer but of a `.{s}` instead",
                .{@tagName(@typeInfo(T.Slice))},
            ),
            Error.SliceTypeNotASlice => fmt(
                "its `Slice` declaration isn't the type of a slice but a pointer of size `.{s}` instead",
                .{@tagName(@typeInfo(T.Slice).pointer.size)},
            ),
        };

        return fmt(isnt_array_list, .{ args, reason });
    }
}

pub inline fn Reify(comptime T: type, comptime with: With) type {
    assert(T, with);
    const Item = @TypeOf(@as(T, undefined).items[0]);
    const alignment = @typeInfo(T.Slice).pointer.alignment;
    return if (with.allocator)
        std.ArrayListAligned(Item, alignment)
    else
        std.ArrayListAlignedUnmanaged(Item, alignment);
}

pub inline fn reify(array_list: anytype, comptime with: With) Reify(@TypeOf(array_list), with) {
    return array_list;
}

fn expectError(comptime T: type, comptime with: With, comptime err: Error) !void {
    try std.testing.expectError(err, expect(T, with));
}

test "expect(.{ .allocator = true })" {
    const with = With{ .allocator = true };

    // passing
    try expect(std.ArrayList(u8), with);
    try expect(std.ArrayList(struct {}), with);

    inline for (@typeInfo(Error).error_set.?) |error_info| {
        const err: Error = @field(Error, error_info.name);
        try expectError(switch (err) {
            Error.NotAStruct => i32,
            Error.IsTuple => struct { i32 },
            Error.NoAllocator => std.ArrayListUnmanaged(u8),
            Error.AllocatorNotAnAllocator => struct {
                allocator: @TypeOf(.not_an_allocator),
            },
            Error.NoSlice => struct { allocator: std.mem.Allocator },
            Error.SliceNotAType => struct {
                allocator: std.mem.Allocator,
                pub const Slice = "This is a string, not a type";
            },
            Error.SliceTypeNotAPointer => struct {
                allocator: std.mem.Allocator,
                pub const Slice = @TypeOf(.this_isnt_a_pointer);
            },
            Error.SliceTypeNotASlice => struct {
                allocator: std.mem.Allocator,
                pub const Slice = @TypeOf("This is a pointer, but not a slice");
            },
            Error.NotFromFunction => struct {
                allocator: std.mem.Allocator,
                pub const Slice = []u8;
            },
            // impossible to reach with `.allocator = true`
            Error.HasAllocator,
            // impossible to reach with `.item_type = null`
            Error.ItemNotItem,
            // impossible to reach with `.alignment = null`
            Error.AlignmentNotExact,
            Error.AlignmentTooSmall,
            => continue,
        }, with, err);
    }
}

test "expect(.{ .allocator = false })" {
    const with = With{ .allocator = false };

    // passing
    try expect(std.ArrayListUnmanaged(u8), with);
    try expect(std.ArrayListUnmanaged(struct {}), with);

    inline for (@typeInfo(Error).error_set.?) |error_info| {
        const err: Error = @field(Error, error_info.name);
        try expectError(switch (err) {
            Error.NotAStruct => i32,
            Error.IsTuple => struct { i32 },
            Error.HasAllocator => std.ArrayList(u8),
            Error.NoSlice => struct { is_struct: bool = true },
            Error.SliceNotAType => struct {
                is_struct: bool = true,
                pub const Slice = "This is a string, not a type";
            },
            Error.SliceTypeNotAPointer => struct {
                is_struct: bool = true,
                pub const Slice = @TypeOf(.this_isnt_a_pointer);
            },
            Error.SliceTypeNotASlice => struct {
                is_struct: bool = true,
                pub const Slice = @TypeOf("This is a pointer, but not a slice");
            },
            Error.NotFromFunction => struct {
                is_struct: bool = true,
                pub const Slice = []u8;
            },
            // impossible to reach with `.allocator = false`
            Error.NoAllocator,
            Error.AllocatorNotAnAllocator,
            // impossible to reach with `.item_type = null`
            Error.ItemNotItem,
            // impossible to reach with `.alignment = null`
            Error.AlignmentNotExact,
            Error.AlignmentTooSmall,
            => continue,
        }, with, err);
    }
}

test "expect(.{ .allocator = true, .item_type = ... })" {
    const Item = union { v1: i32, v2: f32 };
    const with = With{ .allocator = true, .item_type = Item };

    // passing
    try expect(std.ArrayList(Item), with);

    inline for (@typeInfo(Error).error_set.?) |error_info| {
        const err: Error = @field(Error, error_info.name);
        try expectError(switch (err) {
            Error.NotAStruct => i32,
            Error.IsTuple => struct { i32 },
            Error.ItemNotItem => std.ArrayList(u8),
            Error.NoAllocator => std.ArrayListUnmanaged(Item),
            Error.AllocatorNotAnAllocator => struct {
                allocator: @TypeOf(.not_an_allocator),
            },
            Error.NoSlice => struct { allocator: std.mem.Allocator },
            Error.SliceNotAType => struct {
                allocator: std.mem.Allocator,
                pub const Slice = "This is a string, not a type";
            },
            Error.SliceTypeNotAPointer => struct {
                allocator: std.mem.Allocator,
                pub const Slice = @TypeOf(.this_isnt_a_pointer);
            },
            Error.SliceTypeNotASlice => struct {
                allocator: std.mem.Allocator,
                pub const Slice = @TypeOf("This is a pointer, but not a slice");
            },
            Error.NotFromFunction => struct {
                allocator: std.mem.Allocator,
                pub const Slice = []Item;
            },
            // impossible to reach with `.allocator = true`
            Error.HasAllocator,
            // impossible to reach with `.alignment = null`
            Error.AlignmentNotExact,
            Error.AlignmentTooSmall,
            => continue,
        }, with, err);
    }
}

test "expect(.{ .allocator = false, .item_type = ... })" {
    const Item = struct { field: bool };
    const with = With{ .allocator = false, .item_type = Item };

    // passing
    try expect(std.ArrayListUnmanaged(Item), with);

    inline for (@typeInfo(Error).error_set.?) |error_info| {
        const err: Error = @field(Error, error_info.name);
        try expectError(switch (err) {
            Error.NotAStruct => i32,
            Error.IsTuple => struct { i32 },
            Error.HasAllocator => std.ArrayList(u8),
            Error.NoSlice => struct { is_struct: bool = true },
            Error.SliceNotAType => struct {
                is_struct: bool = true,
                pub const Slice = "This is a string, not a type";
            },
            Error.SliceTypeNotAPointer => struct {
                is_struct: bool = true,
                pub const Slice = @TypeOf(.this_isnt_a_pointer);
            },
            Error.SliceTypeNotASlice => struct {
                is_struct: bool = true,
                pub const Slice = @TypeOf("This is a pointer, but not a slice");
            },
            Error.ItemNotItem => struct {
                is_struct: bool = true,
                pub const Slice = []u8;
            },
            Error.NotFromFunction => struct {
                is_struct: bool = true,
                pub const Slice = []Item;
            },
            // impossible to reach with `.allocator = false`
            Error.NoAllocator,
            Error.AllocatorNotAnAllocator,
            // impossible to reach with `.alignment = null`
            Error.AlignmentNotExact,
            Error.AlignmentTooSmall,
            => continue,
        }, with, err);
    }
}

test "expect(.{ .allocator = true, .alignment = .natural })" {
    const with = With{ .allocator = true, .alignment = .natural };

    // passing
    try expect(std.ArrayList(u8), with);
    try expect(std.ArrayList(struct {}), with);

    inline for (@typeInfo(Error).error_set.?) |error_info| {
        const err: Error = @field(Error, error_info.name);
        try expectError(switch (err) {
            Error.NotAStruct => i32,
            Error.IsTuple => struct { i32 },
            Error.NoAllocator => std.ArrayListUnmanaged(u8),
            Error.AllocatorNotAnAllocator => struct {
                allocator: @TypeOf(.not_an_allocator),
            },
            Error.NoSlice => struct { allocator: std.mem.Allocator },
            Error.SliceNotAType => struct {
                allocator: std.mem.Allocator,
                pub const Slice = "This is a string, not a type";
            },
            Error.SliceTypeNotAPointer => struct {
                allocator: std.mem.Allocator,
                pub const Slice = @TypeOf(.this_isnt_a_pointer);
            },
            Error.SliceTypeNotASlice => struct {
                allocator: std.mem.Allocator,
                pub const Slice = @TypeOf("This is a pointer, but not a slice");
            },
            Error.NotFromFunction => struct {
                allocator: std.mem.Allocator,
                pub const Slice = []u8;
            },
            Error.AlignmentNotExact => std.ArrayListAligned(u8, 2 * @alignOf(u8)),
            // impossible to reach with `.allocator = true`
            Error.HasAllocator,
            // impossible to reach with `.item_type = null`
            Error.ItemNotItem,
            // impossible to reach with `.alignment = .natural`
            Error.AlignmentTooSmall,
            => continue,
        }, with, err);
    }
}

test "expect(.{ .allocator = false, .alignment = .natural })" {
    const with = With{ .allocator = false, .alignment = .natural };

    // passing
    try expect(std.ArrayListUnmanaged(u8), with);
    try expect(std.ArrayListUnmanaged(struct {}), with);

    inline for (@typeInfo(Error).error_set.?) |error_info| {
        const err: Error = @field(Error, error_info.name);
        try expectError(switch (err) {
            Error.NotAStruct => i32,
            Error.IsTuple => struct { i32 },
            Error.HasAllocator => std.ArrayList(u8),
            Error.NoSlice => struct { is_struct: bool = true },
            Error.SliceNotAType => struct {
                is_struct: bool = true,
                pub const Slice = "This is a string, not a type";
            },
            Error.SliceTypeNotAPointer => struct {
                is_struct: bool = true,
                pub const Slice = @TypeOf(.this_isnt_a_pointer);
            },
            Error.SliceTypeNotASlice => struct {
                is_struct: bool = true,
                pub const Slice = @TypeOf("This is a pointer, but not a slice");
            },
            Error.NotFromFunction => struct {
                is_struct: bool = true,
                pub const Slice = []u8;
            },
            Error.AlignmentNotExact => std.ArrayListAlignedUnmanaged(u8, 2 * @alignOf(u8)),
            // impossible to reach with `.allocator = false`
            Error.NoAllocator,
            Error.AllocatorNotAnAllocator,
            // impossible to reach with `.item_type = null`
            Error.ItemNotItem,
            // impossible to reach with `.alignment = .natural`
            Error.AlignmentTooSmall,
            => continue,
        }, with, err);
    }
}

test "expect(.{ .allocator = true, .item_type = ..., .alignment = .natural })" {
    const Item = enum {};
    const with = With{
        .allocator = true,
        .item_type = Item,
        .alignment = .natural,
    };

    // passing
    try expect(std.ArrayList(Item), with);

    inline for (@typeInfo(Error).error_set.?) |error_info| {
        const err: Error = @field(Error, error_info.name);
        try expectError(switch (err) {
            Error.NotAStruct => i32,
            Error.IsTuple => struct { i32 },
            Error.ItemNotItem => std.ArrayList(u8),
            Error.NoAllocator => std.ArrayListUnmanaged(Item),
            Error.AllocatorNotAnAllocator => struct {
                allocator: @TypeOf(.not_an_allocator),
            },
            Error.NoSlice => struct { allocator: std.mem.Allocator },
            Error.SliceNotAType => struct {
                allocator: std.mem.Allocator,
                pub const Slice = "This is a string, not a type";
            },
            Error.SliceTypeNotAPointer => struct {
                allocator: std.mem.Allocator,
                pub const Slice = @TypeOf(.this_isnt_a_pointer);
            },
            Error.SliceTypeNotASlice => struct {
                allocator: std.mem.Allocator,
                pub const Slice = @TypeOf("This is a pointer, but not a slice");
            },
            Error.NotFromFunction => struct {
                allocator: std.mem.Allocator,
                pub const Slice = []Item;
            },
            Error.AlignmentNotExact => std.ArrayListAligned(Item, 2 * @alignOf(Item)),
            // impossible to reach with `.allocator = true`
            Error.HasAllocator,
            // impossible to reach with `.alignment = .natural`
            Error.AlignmentTooSmall,
            => continue,
        }, with, err);
    }
}

test "expect(.{ .allocator = false, .item_type = ..., .alignment = .natural })" {
    const Item = struct {
        pub const im = .a_namespace;
    };

    const with = With{ .allocator = false, .item_type = Item, .alignment = .natural };

    // passing
    try expect(std.ArrayListUnmanaged(Item), with);

    inline for (@typeInfo(Error).error_set.?) |error_info| {
        const err: Error = @field(Error, error_info.name);
        try expectError(switch (err) {
            Error.NotAStruct => i32,
            Error.IsTuple => struct { i32 },
            Error.ItemNotItem => std.ArrayListUnmanaged(u8),
            Error.HasAllocator => std.ArrayList(Item),
            Error.NoSlice => struct { is_struct: bool = true },
            Error.SliceNotAType => struct {
                is_struct: bool = true,
                pub const Slice = "This is a string, not a type";
            },
            Error.SliceTypeNotAPointer => struct {
                is_struct: bool = true,
                pub const Slice = @TypeOf(.this_isnt_a_pointer);
            },
            Error.SliceTypeNotASlice => struct {
                is_struct: bool = true,
                pub const Slice = @TypeOf("This is a pointer, but not a slice");
            },
            Error.NotFromFunction => struct {
                is_struct: bool = true,
                pub const Slice = []Item;
            },
            Error.AlignmentNotExact => std.ArrayListAlignedUnmanaged(Item, 2 * @alignOf(Item)),
            // impossible to reach with `.allocator = false`
            Error.NoAllocator,
            Error.AllocatorNotAnAllocator,
            // impossible to reach with `.alignment = .natural`
            Error.AlignmentTooSmall,
            => continue,
        }, with, err);
    }
}

test "expect(.{ .allocator = true, .alignment = .at_least_natural })" {
    // TODO
}

test "expect(.{ .allocator = false, .alignment = .at_least_natural })" {
    // TODO
}

test "expect(.{ .allocator = true, .item_type = ..., .alignment = .at_least_natural })" {
    // TODO
}

test "expect(.{ .allocator = false, .item_type = ..., .alignment = .at_least_natural })" {
    // TODO
}

test "expect(.{ .allocator = true, .alignment = .{ .exact = ... } })" {
    // TODO
}

test "expect(.{ .allocator = false, .alignment = .{ .exact = ... } })" {
    // TODO
}

test "expect(.{ .allocator = true, .item_type = ..., .alignment = .{ .exact = ... } })" {
    // TODO
}

test "expect(.{ .allocator = false, .item_type = ..., .alignment = .{ .exact = ... } })" {
    // TODO
}

test "expect(.{ .allocator = true, .alignment = .{ .at_least = ... } })" {
    // TODO
}

test "expect(.{ .allocator = false, .alignment = .{ .at_least = ... } })" {
    // TODO
}

test "expect(.{ .allocator = true, .item_type = ..., .alignment = .{ .at_least = ... } })" {
    // TODO
}

test "expect(.{ .allocator = false, .item_type = ..., .alignment = .{ .at_least = ... } })" {
    // TODO
}
