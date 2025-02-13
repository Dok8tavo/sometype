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

const linked_list = @import("linked_list.zig");
const std = @import("std");

pub const With = struct { Item: ?type = null };

pub const Error = error{
    NotAStruct,
    IsTuple,
    /// There's no `Node` declaration in the given type.
    NoNode,
    NodeNotAType,
    NodeNotAStructType,
    NodeIsTupleType,
    /// The `Node` type has no `data` field
    NodeNoData,
    /// The `Node` type has a `prev` field
    NodeHasPrev,
    /// The items of the given type aren't those specified in the `with` parameter.
    ItemNotItem,
    /// The given type respects a lot of requirements, but in the end wasn't returned from
    /// `std.SinglyLinkedList`.
    NotFromFunction,
};

pub inline fn expect(comptime T: type, comptime with: With) Error!void {
    return @errorCast(linked_list.expect(T, .{ .linkage = .single, .Item = with.Item }));
}

pub inline fn assert(comptime T: type, comptime with: With) void {
    comptime expect(T, with) catch |e| @compileError(logError(e, T, with));
}

pub inline fn logError(comptime e: Error, comptime T: type, comptime with: With) []const u8 {
    return linked_list.logError(@errorCast(e), T, .{ .Item = with.Item, .linkage = .single });
}

pub inline fn Reify(comptime T: type, comptime with: With) type {
    assert(T, with);
    const Item = @TypeOf(@field(@as(T.Node, undefined), "data"));
    return std.SinglyLinkedList(Item);
}

pub inline fn reify(
    doubly_linked_list_ptr: anytype,
    comptime with: With,
) *const Reify(@TypeOf(doubly_linked_list_ptr.*), with) {
    return doubly_linked_list_ptr;
}

pub inline fn reifyVar(
    singly_linked_list_ptr: anytype,
    comptime with: With,
) *Reify(@TypeOf(singly_linked_list_ptr.*), with) {
    return singly_linked_list_ptr;
}
