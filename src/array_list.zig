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

pub const Error = error{
    NotAStruct,
    IsTuple,
    NoSlice,
    SliceNotAType,
    NoAllocator,
    HasAllocator,
    AllocatorNotAnAllocator,
    SliceTypeNotAPointer,
    SliceTypeNotASlice,
    ItemNotItem,
    AlignmentNotExact,
    AlignmentTooSmall,
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

        if (with.allocator) |allocator| {
            if (allocator != @hasField(T, "allocator")) return switch (allocator) {
                true => Error.NoAllocator,
                false => Error.HasAllocator,
            };

            if (allocator and (std.mem.Allocator == @TypeOf(@as(T, undefined).allocator)))
                return Error.AllocatorNotAnAllocator;
        }

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
            .exactly => |exact_alignment| if (exact_alignment != alignment)
                return Error.AlignmentNotExact,
            .at_least => |least_alignment| if (least_alignment <= alignment)
                return Error.AlignmentTooSmall,
            .at_least_natural => if (@alignOf(Item) <= alignment)
                return Error.AlignmentTooSmall,
            .natural => if (@alignOf(Item) != alignment)
                return Error.AlignmentNotExact,
        };

        const right_function = if (with.allocator) |allocator| switch (allocator) {
            true => T == std.ArrayListAligned(Item, alignment),
            false => T == std.ArrayListAlignedUnmanaged(Item, alignment),
        } else T == std.ArrayListAligned(Item, alignment) or
            T == std.ArrayListAlignedUnmanaged(Item, alignment);

        if (!right_function)
            return Error.NotFromFunction;
    }
}

test "Non Array lists" {
    try std.testing.expectError(Error.NotAStruct, expect(u8, .{}));
    try std.testing.expectError(Error.IsTuple, expect(struct { u8 }, .{}));
    try std.testing.expectError(Error.NoSlice, expect(struct { field: void }, .{}));
    try std.testing.expectError(Error.SliceNotAType, expect(struct {
        pub const Slice = "This isn't a type";
    }, .{}));
    try std.testing.expectError(Error.SliceTypeNotAPointer, expect(struct {
        pub const Slice = @TypeOf(.this_is_the_type_of_a_non_pointer);
    }, .{}));
    try std.testing.expectError(Error.SliceTypeNotASlice, expect(struct {
        pub const Slice = @TypeOf("This is the type of a non-slice pointer!");
    }, .{}));
    try std.testing.expectError(Error.NotFromFunction, expect(struct {
        pub const Slice = []u8;
    }, .{}));
}
