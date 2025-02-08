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
    allocator: ?bool = true,
    alignment: ?Alignment = null,
    item_type: ?type = null,

    pub const Alignment = union(enum) {
        exact: u16,
        at_least: u16,
        at_least_natural,
        natural,
    };
};

pub inline fn is(comptime T: type, comptime with: With) bool {
    comptime {
        const info = @typeInfo(T);

        if (info != .@"struct")
            return false;

        if (info.@"struct".is_tuple)
            return false;

        if (!@hasDecl(T, "Slice"))
            return false;

        if (@TypeOf(T.Slice) != type)
            return false;

        if (with.allocator) |allocator| {
            if (allocator != @hasField(T, "allocator"))
                return false;

            if (allocator and (std.mem.Allocator == @TypeOf(@as(T, undefined).allocator)))
                return false;
        }

        const slice_info = @typeInfo(T.Slice);

        if (slice_info != .pointer)
            return false;

        if (slice_info.pointer.size != .slice)
            return false;

        const Item = slice_info.pointer.child;
        const alignment = slice_info.pointer.alignment;

        if (with.item_type) |item_type| if (item_type != Item)
            return false;

        if (with.alignment) |with_alignment| switch (with_alignment) {
            .exactly => |exact_alignment| if (exact_alignment != alignment)
                return false,
            .at_least => |least_alignment| if (least_alignment <= alignment)
                return false,
            .at_least_natural => if (@alignOf(Item) <= alignment)
                return false,
            .natural => if (@alignOf(Item) != alignment)
                return false,
        };

        return if (with.allocator) |allocator| switch (allocator) {
            true => T == std.ArrayListAligned(Item, alignment),
            false => T == std.ArrayListAlignedUnmanaged(Item, alignment),
        } else T == std.ArrayListAligned(Item, alignment) or
            T == std.ArrayListAlignedUnmanaged(Item, alignment);
    }
}

fn expect(comptime T: type, comptime with: With, comptime result: bool) !void {
    try std.testing.expect(result == is(T, with));
}

const Item1 = u8;
const Item2 = union {};

const natural_align_1 = @alignOf(Item1);
const natural_align_2 = @alignOf(Item2);

const more_than_natural_align_1 = natural_align_1 * 2;
const more_than_natural_align_2 = natural_align_2 * 2;

const less_than_natural_align_1 = natural_align_1 / 2;
const less_than_natural_align_2 = natural_align_2 / 2;

test "is(non_array_list, .{})" {
    try expect(u8, .{}, false);
    try expect(struct {}, .{}, false);
    try expect(struct {
        capacity: usize,
        items: Slice,

        pub const Slice = []u8;
    }, .{}, false);
}

test "is(..., .{})" {
    try expect(std.ArrayList(Item1), .{}, true);
    try expect(std.ArrayList(Item2), .{}, true);

    try expect(std.ArrayListUnmanaged(Item1), .{}, true);
    try expect(std.ArrayListUnmanaged(Item2), .{}, true);

    try expect(std.ArrayListAligned(Item1, more_than_natural_align_1), .{}, true);
    try expect(std.ArrayListAligned(Item2, more_than_natural_align_2), .{}, true);

    try expect(std.ArrayListAlignedUnmanaged(Item1, more_than_natural_align_1), .{}, true);
    try expect(std.ArrayListAlignedUnmanaged(Item2, more_than_natural_align_2), .{}, true);
}

test "is(..., .{ .allocator = true })" {
    try expect(std.ArrayList(Item1), .{ .allocator = true }, true);
    try expect(std.ArrayList(Item2), .{ .allocator = true }, true);

    try expect(std.ArrayListUnmanaged(Item1), .{ .allocator = true }, false);
    try expect(std.ArrayListUnmanaged(Item2), .{ .allocator = true }, false);

    try expect(std.ArrayListAligned(Item1, more_than_natural_align_1), .{ .allocator = true }, true);
    try expect(std.ArrayListAligned(Item2, more_than_natural_align_2), .{ .allocator = true }, true);

    try expect(std.ArrayListAlignedUnmanaged(Item1, more_than_natural_align_1), .{ .allocator = true }, false);
    try expect(std.ArrayListAlignedUnmanaged(Item2, more_than_natural_align_2), .{ .allocator = true }, false);
}

test "is(..., .{ .allocator = false })" {
    try expect(std.ArrayList(Item1), .{ .allocator = false }, false);
    try expect(std.ArrayList(Item2), .{ .allocator = false }, false);

    try expect(std.ArrayListUnmanaged(Item1), .{ .allocator = false }, true);
    try expect(std.ArrayListUnmanaged(Item2), .{ .allocator = false }, true);

    try expect(std.ArrayListAligned(Item1, more_than_natural_align_1), .{ .allocator = false }, false);
    try expect(std.ArrayListAligned(Item2, more_than_natural_align_2), .{ .allocator = false }, false);

    try expect(std.ArrayListAlignedUnmanaged(Item1, more_than_natural_align_1), .{ .allocator = false }, true);
    try expect(std.ArrayListAlignedUnmanaged(Item2, more_than_natural_align_2), .{ .allocator = false }, true);
}
