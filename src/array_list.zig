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
    Item: ?type = null,

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
    SliceNotAPointerType,
    /// The `Slice` declaration isn't the type of a slice.
    SliceNotASliceType,
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
            return Error.SliceNotAPointerType;

        if (slice_info.pointer.size != .slice)
            return Error.SliceNotASliceType;

        const Item = slice_info.pointer.child;
        const alignment = slice_info.pointer.alignment;

        if (with.Item) |item_type| if (item_type != Item)
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
            Error.ItemNotItem => fmt("{s}, ...", .{@typeName(with.Item.?)}),
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
            Error.SliceNotAPointerType => fmt(
                "its `Slice` declaration isn't the type of a pointer but of a `.{s}` instead",
                .{@tagName(@typeInfo(T.Slice))},
            ),
            Error.SliceNotASliceType => fmt(
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

pub inline fn reify(
    array_list: anytype,
    comptime with: With,
) *const Reify(@TypeOf(array_list.*), with) {
    return array_list;
}

pub inline fn reifyVar(
    array_list: anytype,
    comptime with: With,
) *Reify(@TypeOf(array_list.*), with) {
    return array_list;
}

fn expectError(comptime T: type, comptime with: With, comptime err: Error) !void {
    try std.testing.expectError(err, expect(T, with));
}

test expect {
    // with only `.allocaator = true` anything that's passed to `std.ArrayListAligned` will work
    try expect(std.ArrayList(u8), .{});
    try expect(std.ArrayListAligned(u32, 1), .{});

    // but anything that's passed to `std.ArrayListUnmanagedAligned` won't
    try expectError(std.ArrayListUnmanaged(u8), .{}, Error.NoAllocator);
    try expectError(std.ArrayListAlignedUnmanaged(*const anyopaque, 1024), .{}, Error.NoAllocator);

    // with only `.allocator = false` anything that's passed to `std.ArrayListUnmanagedAligned`
    // will work
    try expect(std.ArrayListUnmanaged(enum {}), .{ .allocator = false });
    try expect(std.ArrayListAlignedUnmanaged(struct { field: bool }, 64), .{ .allocator = false });

    // but anything that's passed to `std.ArrayListAligned` won't
    try expectError(std.ArrayList(u8), .{ .allocator = false }, Error.HasAllocator);
    try expectError(
        std.ArrayListAligned(*const anyopaque, 1024),
        .{ .allocator = false },
        Error.HasAllocator,
    );

    // when the `.Item` is set, the passed `T` type must correspond
    try expect(std.ArrayList([]const u8), .{ .Item = []const u8 });
    try expectError(std.ArrayList(i32), .{ .Item = f64 }, Error.ItemNotItem);

    // when the `.alignment` is `.natural`, the alignment must be the natural alignment of the item
    try expect(std.ArrayList(i32), .{ .alignment = .natural });
    try expect(std.ArrayListAligned(i32, @alignOf(i32)), .{ .alignment = .natural });
    try expectError(
        std.ArrayListAligned(i32, @alignOf(i32) / 2),
        .{ .alignment = .natural },
        Error.AlignmentNotExact,
    );

    try expectError(
        std.ArrayListAligned(i32, @alignOf(i32) * 2),
        .{ .alignment = .natural },
        Error.AlignmentNotExact,
    );

    // when the `.alignment` is `.exactly`, the alignment must be the given alignment
    try expect(std.ArrayListAligned(i32, 8), .{ .alignment = .{ .exact = 8 } });
    try expect(std.ArrayListAligned(u8, 8), .{ .alignment = .{ .exact = 8 } });
    try expectError(
        std.ArrayListAligned(i32, 16),
        .{ .alignment = .{ .exact = 8 } },
        Error.AlignmentNotExact,
    );

    try expectError(
        std.ArrayListAligned(i32, 4),
        .{ .alignment = .{ .exact = 8 } },
        Error.AlignmentNotExact,
    );

    try expectError(
        std.ArrayList(u8),
        .{ .alignment = .{ .exact = @alignOf(u8) * 2 } },
        Error.AlignmentNotExact,
    );

    try expectError(
        std.ArrayList(i32),
        .{ .alignment = .{ .exact = @alignOf(i32) / 2 } },
        Error.AlignmentNotExact,
    );

    // when the `.alignment` is `.at_least_natural`, the alignment must be the natural alignment or more
    try expect(std.ArrayList(i32), .{ .alignment = .at_least_natural });
    try expect(std.ArrayListAligned(u8, @alignOf(u8) * 2), .{ .alignment = .at_least_natural });
    try expectError(
        std.ArrayListAligned(i32, @alignOf(i32) / 2),
        .{ .alignment = .at_least_natural },
        Error.AlignmentTooSmall,
    );

    // when the `.alignment` is `.at_least`, the alignment mustt be the given alignment or more
    try expect(std.ArrayList(i32), .{ .alignment = .{ .at_least = 1 } });
    try expect(
        std.ArrayListAligned(u8, @alignOf(u8) * 2),
        .{ .alignment = .{ .at_least = @alignOf(u8) } },
    );

    try expectError(
        std.ArrayListAligned(i32, 1),
        .{ .alignment = .{ .at_least = 2 } },
        Error.AlignmentTooSmall,
    );

    try expectError(
        std.ArrayListAligned(u8, 128),
        .{ .alignment = .{ .at_least = 256 } },
        Error.AlignmentTooSmall,
    );

    // an `Error.NotAStruct` occurs when passing a non-struct type
    try expectError(enum { not_a_struct }, .{}, Error.NotAStruct);

    // an `Error.IsTuple` occurs when passing a tuple type
    try expectError(struct { @TypeOf(.is_a_tuple) }, .{}, Error.IsTuple);

    // an `Error.AllocatorNotAnAllocator` occurs when the `allocator` field of the struct type
    // isn't an instance of `std.mem.Allocator`.
    try expectError(struct {
        allocator: @TypeOf(.not_an_allocator),
        is_a_struct: bool = true,
    }, .{}, Error.AllocatorNotAnAllocator);

    // an `Error.NoSlice` occurs when the struct type doesn't have a `Slice` declaration
    try expectError(struct {
        allocator: std.mem.Allocator,
    }, .{}, Error.NoSlice);

    // an `Error.SliceNotAType` occurs when `Slice` declaration isn't a type
    try expectError(struct {
        allocator: std.mem.Allocator,

        pub const Slice = .not_a_slice;
    }, .{}, Error.SliceNotAType);

    // an `Error.SliceNotAPointerType` occurs when the `Slice` declaration isn't a pointer type
    try expectError(struct {
        allocator: std.mem.Allocator,

        pub const Slice = @TypeOf(.not_a_pointer);
    }, .{}, Error.SliceNotAPointerType);

    // an `Error.SliceNotASliceType` occurs when the `Slice` declaration isn't a slice type
    try expectError(struct {
        allocator: std.mem.Allocator,

        pub const Slice = @TypeOf("not a slice");
    }, .{}, Error.SliceNotASliceType);

    // an `Error.NotFromFunction` occurs when even though all other condition was fullfilled,
    // the given type doesn't come from `std.ArrayListAligned` or `std.ArrayListAlignedUnmanaged`
    try expectError(struct {
        allocator: std.mem.Allocator,

        pub const Slice = []u8;
    }, .{}, Error.NotFromFunction);

    // we can even make a structural equivalent of an array list
    const ArrayList = std.ArrayList(u8);
    const NotArrayList = struct {
        items: []u8,
        capacity: usize,
        allocator: std.mem.Allocator,

        // this doesn't exactly make `NotArrayList` an actual structural equivalent of `ArrayList`,
        // but it's for the demonstration
        pub usingnamespace ArrayList;
    };

    try expect(ArrayList, .{});
    try expectError(NotArrayList, .{}, Error.NotFromFunction);
}
