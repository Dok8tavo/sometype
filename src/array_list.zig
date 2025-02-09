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
    /// This can't be null becausse the managed and unmanaged array lists have different APIs
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

        if (with.allocator != @hasField(T, "allocator")) return switch (with.allocator) {
            true => Error.NoAllocator,
            false => Error.HasAllocator,
        };

        if (with.allocator and (std.mem.Allocator != @TypeOf(@as(T, undefined).allocator)))
            return Error.AllocatorNotAnAllocator;

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
