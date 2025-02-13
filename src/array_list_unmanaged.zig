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

const array_list = @import("array_list.zig");
const std = @import("std");

pub const With = struct {
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
    HasAllocator,
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
    return @errorCast(array_list.expect(T, .{
        .allocator = false,
        .alignment = with.alignment,
        .Item = with.Item,
    }));
}

pub inline fn assert(comptime T: type, comptime with: With) void {
    comptime expect(T, with) catch |e| @compileError(logError(e, T, with));
}

pub inline fn logError(comptime e: Error, comptime T: type, comptime with: With) []const u8 {
    return array_list.logError(@intCast(e), T, .{
        .alignment = with.alignment,
        .allocator = false,
        .Item = with.Item,
    });
}

pub inline fn Reify(comptime T: type, comptime with: With) type {
    assert(T, with);
    const Item = @TypeOf(@as(T, undefined).items[0]);
    const alignment = @typeInfo(T.Slice).pointer.alignment;
    return std.ArrayListAlignedUnmanaged(Item, alignment);
}

pub inline fn reify(
    array_list_unmanaged_ptr: anytype,
    comptime with: With,
) *const Reify(@TypeOf(array_list_unmanaged_ptr.*), with) {
    return array_list_unmanaged_ptr;
}

pub inline fn reifyVar(
    array_list_unmanaged_ptr: anytype,
    comptime with: With,
) *Reify(@TypeOf(array_list_unmanaged_ptr.*), with) {
    return array_list_unmanaged_ptr;
}
