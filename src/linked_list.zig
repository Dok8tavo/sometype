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
    /// This can't be null because the doubly and singly linked lists have different APIs
    linkage: Linkage = .single,
    Item: ?type = null,

    pub const Linkage = enum { double, single };
};

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
    /// The `Node` type has no `prev` field when `linkage` is `.double`
    NodeNoPrev,
    /// The `Node` type has a `prev` field when `linkage` is `.single`
    NodeHasPrev,
    /// The items of the given type aren't those specified in the `with` parameter.
    ItemNotItem,
    /// The given type respects a lot of requirements, but in the end wasn't returned from
    /// `std.SinglyLinkedList` or `std.DoublyLinkedList`.
    NotFromFunction,
};

pub inline fn expect(comptime T: type, comptime with: With) Error!void {
    comptime {
        const info = @typeInfo(T);

        if (info != .@"struct")
            return Error.NotAStruct;

        if (info.@"struct".is_tuple)
            return Error.IsTuple;

        if (!@hasDecl(T, "Node"))
            return Error.NoNode;

        if (@TypeOf(T.Node) != type)
            return Error.NodeNotAType;

        const node_info = @typeInfo(T.Node);

        if (node_info != .@"struct")
            return Error.NodeNotAStructType;

        if (node_info.@"struct".is_tuple)
            return Error.NodeIsTupleType;

        if (!@hasField(T.Node, "data"))
            return Error.NodeNoData;

        switch (with.linkage) {
            .double => if (!@hasField(T.Node, "prev")) return Error.NodeNoPrev,
            .single => if (@hasField(T.Node, "prev")) return Error.HasPrev,
        }

        const Item = @FieldType(T.Node, "data");

        if (with.Item) |ItemType| if (Item != ItemType)
            return Error.ItemNotItem;

        const from_function = switch (with.linkage) {
            .double => T == std.DoublyLinkedList(Item),
            .single => T == std.SinglyLinkedList(Item),
        };

        if (!from_function)
            return from_function;
    }
}
