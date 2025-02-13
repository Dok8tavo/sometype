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

pub const doubly = @import("doubly_linked_list.zig");
pub const singly = @import("singly_linked_list.zig");

pub const With = struct {
    /// This can't be null because the doubly and singly linked lists have different APIs
    linked: Linked = .singly,
    Item: ?type = null,

    pub const Linked = enum { doubly, singly };
};

pub const Error = doubly.Error || singly.Error;

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

        switch (with.linked) {
            .doubly => if (!@hasField(T.Node, "prev")) return Error.NodeNoPrev,
            .singly => if (@hasField(T.Node, "prev")) return Error.NodeHasPrev,
        }

        const Item = @TypeOf(@field(@as(T.Node, undefined), "data"));

        if (with.Item) |ItemType| if (Item != ItemType)
            return Error.ItemNotItem;

        const from_function = switch (with.linked) {
            .doubly => T == std.DoublyLinkedList(Item),
            .singly => T == std.SinglyLinkedList(Item),
        };

        if (!from_function)
            return Error.NotFromFunction;
    }
}

pub inline fn assert(comptime T: type, comptime with: With) void {
    comptime expect(T, with) catch |e| @compileError(logError(e, T, with));
}

pub inline fn logError(comptime e: Error, comptime T: type, comptime with: With) []const u8 {
    comptime {
        const fmt = std.fmt.comptimePrint;
        const isnt_linked_list = fmt("The type `{s}` isn't a `std.{s}List({s})` because {{s}}!", .{
            @typeName(T),
            switch (with.linked) {
                .doubly => "Doubly",
                .singly => "Singly",
            },
            if (with.Item) |Item| @typeName(Item) else "...",
        });

        const reason = switch (e) {
            Error.IsTuple => "it's a tuple type",
            Error.ItemNotItem => fmt("its items are `{s}`", .{@FieldType(T.Node, "data")}),
            Error.NodeHasPrev => "its `Node` declaration has a `prev` field, " ++
                " so it might be doubly linked instead",
            Error.NodeIsTupleType => "its `Node` declaration is a tuple type",
            Error.NodeNoData => "its `Node` declaration has no `data` field",
            Error.NodeNoPrev => "its `Node` declaraion has no `prev` field, " ++
                " so it might be singly linked instead",
            Error.NodeNotAStructType => "its `Node` declaraion is not a struct type",
            Error.NodeNotAType => "its `Node` declaration is not a type",
            Error.NoNode => "it has no `Node` declaraion",
            Error.NotAStruct => "it's not a struct type",
            Error.NotFromFunction => fmt(
                "it's not the result of the `std.{s}LinkedList` function",
                .{switch (with.linked) {
                    .doubly => "Doubly",
                    .singly => "Singly",
                }},
            ),
        };

        return fmt(isnt_linked_list, .{reason});
    }
}

pub inline fn Reify(comptime T: type, comptime with: With) type {
    assert(T, with);
    const Item = @TypeOf(@field(@as(T.Node, undefined), "data"));
    return switch (with.linked) {
        .doubly => std.DoublyLinkedList(Item),
        .singly => std.SinglyLinkedList(Item),
    };
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
    // when `with.linked` is set to `.doubly`, anything that's passed to `std.DoublyLinkedList`
    // will work
    try expect(std.DoublyLinkedList(u8), .{ .linked = .doubly });
    try expect(std.DoublyLinkedList(struct {}), .{ .linked = .doubly });

    // when `with.linked` is set to `.singly`, anything that's passed to `std.SinglyLinkedList`
    // will work
    try expect(std.SinglyLinkedList(u8), .{ .linked = .singly });
    try expect(std.SinglyLinkedList(struct {}), .{ .linked = .singly });

    // an `Error.NodeNoPrev` occurs when passing a list with singly instead of doubly linked
    try expectError(std.SinglyLinkedList([4]bool), .{ .linked = .doubly }, Error.NodeNoPrev);
    // an `Error.NodeHasPrev` occurs when passing a list with doubly instead of singly linked
    try expectError(std.DoublyLinkedList([4]bool), .{ .linked = .singly }, Error.NodeHasPrev);

    // an `Error.NotAStruct` occurs when passing a non-struct type
    try expectError(enum { not_a_struct }, .{}, Error.NotAStruct);

    // an `Error.IsTuple` occurs when passing a tuple type
    try expectError(struct { @TypeOf(.is_a_tuple) }, .{}, Error.IsTuple);

    // an `Error.NoNode` occurs when the passed struct doesn't have a `Node` declaration
    try expectError(struct {
        node_declaration: bool = false,
    }, .{}, Error.NoNode);

    // an `Error.NodeNotAType` occurs when the `Node` declaration isn't a type
    try expectError(struct {
        node_declaration: bool = true,

        pub const Node = .not_a_type;
    }, .{}, Error.NodeNotAType);

    // an `Error.NodeNotAStructType` occurs when the `Node` declaration isn't a struct type
    try expectError(struct {
        node_declaration: bool = true,

        pub const Node = @TypeOf(.not_a_struct);
    }, .{}, Error.NodeNotAStructType);

    // an `Error.NodeIsTupleType` occurs when the `Node` declaration is a tuple type.
    try expectError(struct {
        node_declaration: bool = true,

        pub const Node = struct { @TypeOf(.tuple) };
    }, .{}, Error.NodeIsTupleType);

    // an `Error.NodeNoData` occurs when the `Node` declaration doesn't have a `data` field.
    try expectError(struct {
        node_declaration: bool = true,

        pub const Node = struct {
            not_data: @TypeOf(.lol),
        };
    }, .{}, Error.NodeNoData);

    // an `Error.NotFromFunction` occurs when even though all other condition was fullfilled,
    // the given type doesn't come from `std.DoublyLinkedList` or `std.SinglyLinkedList`
    try expectError(struct {
        node_declaration: bool = true,

        pub const Node = struct { data: []const u8 };
    }, .{}, Error.NotFromFunction);
}
