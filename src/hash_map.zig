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
    allocator: bool = true,
    Context: ?ContextType = null,
    max_load_percentage: ?u64 = null,
    Key: ?type = null,
    Value: ?type = null,

    pub const ContextType = union(enum) {
        none,
        some,
        this: type,
    };
};

pub const Error = error{
    InvalidMaxLoadPercentage,
    NotAStruct,
    IsTuple,
    NoUnmanaged,
    UnmanagedNotAStructType,
    UnmanagedIsTupleType,
    UnmanagedNoKeyValue,
    UnmanagedKeyValueNotAType,
    UnmanagedKeyValueNotAStructType,
    UnmanagedKeyValueNotIsATupleType,
    UnmanagedKeyValueNoValue,
    UnmanagedKeyValueNoKey,
    UnmanagedNoPromoteContext,
    UnmanagedPromoteContextNotAFunction,
    UnmanagedPromoteContextNot3Parameters,
    UnmanagedPromoteContextGeneric3rdParameter,
    NonEmptyContext,
    EmptyContext,
    ContextNotContext,
    NotMaxLoadPercentage,
    NotFromFunction,
};

pub inline fn expect(comptime T: type, comptime with: With) Error!void {
    comptime {
        if (with.max_load_percentage) |max_load_percentage|
            if (max_load_percentage <= 0 or 100 < max_load_percentage)
                return Error.InvalidMaxLoadPercentage;

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

        const U = if (!with.allocator)
            T
        else if (!@hasDecl(T, "Unmanaged"))
            return Error.NoUnmanaged
        else
            T.Unmanaged;

        const u_info = @typeInfo(U);

        if (u_info != .@"struct")
            return Error.UnmanagedNotAStructType;

        if (u_info.@"struct".is_tuple)
            return Error.UnmanagedIsTupleType;

        if (!@hasDecl(U, "KV"))
            return Error.UnmanagedNoKeyValue;

        if (U.KV != type)
            return Error.UnmanagedKeyValueNotAType;

        const kv_info = @typeInfo(U.KV);

        if (kv_info != .@"struct")
            return Error.UnmanagedKeyValueNotAStructType;

        if (kv_info.@"struct".is_tuple)
            return Error.UnmanagedKeyValueNotIsATupleType;

        if (!@hasField(U.KV, "value"))
            return Error.UnmanagedKeyValueNoValue;

        if (!@hasField(U.KV, "key"))
            return Error.UnmanagedKeyValueNoKey;

        const Key = @TypeOf(@as(U.KV, undefined).key);
        const Value = @TypeOf(@as(U.KV, undefined).value);

        if (!@hasDecl(U, "promoteContext"))
            return Error.UnmanagedNoPromoteContext;

        const pc_info = @typeInfo(@TypeOf(U.promoteContext));

        if (pc_info != .@"fn")
            return Error.UnmanagedPromoteContextNotAFunction;

        if (pc_info.@"fn".params.len != 3)
            return Error.UnmanagedPromoteContextNot3Parameters;

        const Context = if (pc_info.@"fn".params[2].type) |C|
            C
        else
            return Error.UnmanagedPromoteContextGeneric3rdParameter;

        if (with.Context) |with_context| switch (with_context) {
            .none => if (@sizeOf(Context) != 0) return Error.NonEmptyContext,
            .some => if (@sizeOf(Context) == 0) return Error.EmptyContext,
            .this => |This| if (Context != This) return Error.ContextNotContext,
        };

        if (with.max_load_percentage) |max_load_percentage| return switch (with.allocator) {
            true => if (T != std.HashMap(Key, Value, Context, max_load_percentage))
                return Error.NotMaxLoadPercentage,
            false => if (T != std.HashMapUnmanaged(Key, Value, Context, max_load_percentage))
                return Error.NotMaxLoadPercentage,
        };

        if (figureMlpOut(T, with.allocator, Key, Value, Context) == null)
            return Error.NotFromFunction;
    }
}

pub inline fn assert(comptime T: type, comptime with: With) void {
    expect(T, with) catch |e| logError(T, with, e);
}

pub inline fn Reify(comptime T: type, comptime with: With) type {
    assert(T, with);
    const has_allocator = @hasField(T, "allocator");
    const Unmanaged = if (has_allocator) T.Unmanaged else T;
    const Key = @TypeOf(@as(Unmanaged.KV, undefined).key);
    const Value = @TypeOf(@as(Unmanaged.KV, undefined).value);

    const Context = @typeInfo(@TypeOf(Unmanaged.promoteContext)).@"fn".params[2].type.?;

    const HashMap = switch (with.allocator) {
        true => std.HashMap,
        false => std.HashMapUnmanaged,
    };

    return HashMap(Key, Value, Context, figureMlpOut(T, with.allocator, Key, Value, Context).?);
}

pub inline fn reify(
    hash_map: anytype,
    comptime with: With,
) *const Reify(@TypeOf(hash_map.*), with) {
    return hash_map;
}

pub inline fn reifyVar(
    hash_map: anytype,
    comptime with: With,
) *Reify(@TypeOf(hash_map.*), with) {
    return hash_map;
}

pub inline fn logError(comptime T: type, comptime with: With, comptime e: Error) []const u8 {
    comptime {
        const fmt = std.fmt.comptimePrint;
        const isnt_hash_map = fmt("The type `{s}` isn't a `std.HashMap{s}({s})` because {{s}}!", .{
            @typeName(T), if (with.allocator) "" else "Unmanaged", if (with.Context == null and
                with.Key == null and
                with.Value == null and
                with.max_load_percentage == null)
                "..."
            else
                fmt("{s}, {s}, {s}, {}", .{
                    if (with.Key) |Key| @typeName(Key) else "...",
                    if (with.Value) |Value| @typeName(Value) else "...",
                    if (with.Context) |Context| @typeName(Context) else "...",
                    if (with.max_load_percentage) |mlp| mlp else "...",
                }),
        });

        const reason = switch (e) {
            Error.ContextNotContext => "its context type is `{s}`",
            Error.EmptyContext => "it has an empty context",
            Error.InvalidMaxLoadPercentage => fmt(
                "{}% isn't a valid percentage",
                .{with.max_load_percentage.?},
            ),
            Error.IsTuple => "it's a tuple type",
            Error.NonEmptyContext => "it doesn't have an empty context type",
            Error.NotAStruct => "it's not a struct type",
            Error.NotFromFunction => fmt(
                "it's not returned by the `std.HashMap{s}` function",
                .{if (with.allocator) "" else "Unmanaged"},
            ),
            Error.NotMaxLoadPercentage => fmt(
                "it's max load isn't {}%",
                .{with.max_load_percentage.?},
            ),
            Error.NoUnmanaged => "it doesn't have an `Unmanaged` declaration",
            Error.UnmanagedIsTupleType => "its `Unmanaged` declaration is a tuple type",
            Error.UnmanagedKeyValueNoKey => "its `Unmanaged.KV` doesn't have a `key` field",
            Error.UnmanagedKeyValueNotAStructType => "its `Unmanaged.KV` isn't a struct type",
            Error.UnmanagedKeyValueNotAType => "its `Unmanaged.KV` declaration isn't a type",
            Error.UnmanagedKeyValueNoValue => "its `Unmanaged.KV` doesn't have a `value` field",
            Error.UnmanagedNoKeyValue => "its `Unmanaged` doesn't have a `KV` declaration",
            Error.UnmanagedNoPromoteContext => "its `Unmanaged` doesn't have a `promoteContext`",
            Error.UnmanagedNotAStructType => "its `Unmanaged` declaration isn't struct type",
            Error.UnmanagedPromoteContextGeneric3rdParameter => "its `promoteContext` function " ++
                "has a generic as a third parameter",
            Error.UnmanagedPromoteContextNot3Parameters => "its `promoteContext` function " ++
                "doesn't have a third parameter",
            Error.UnmanagedPromoteContextNotAFunction => "its `promoteContext` declaraation" ++
                "isn't a function",
        };

        return fmt(isnt_hash_map, .{reason});
    }
}

inline fn figureMlpOut(
    comptime T: type,
    comptime managed: bool,
    comptime K: type,
    comptime V: type,
    comptime C: type,
) ?u64 {
    const HashMap = if (managed) std.HashMap else std.HashMapUnmanaged;
    return for (.{ .{ 80, 100 }, .{ 1, 80 } }) |r| for (r[0]..r[1]) |mlp| {
        if (T == HashMap(K, V, C, mlp)) break mlp;
    } else null;
}
