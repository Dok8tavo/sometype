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
    capacity: ?Capacity = null,
    alignment: ?Alignment = null,
    Item: ?type = null,

    pub const Capacity = union(enum) {
        exact: usize,
        at_least: usize,
    };

    pub const Alignment = union(enum) {
        natural,
        at_least_natural,
        exact: u29,
        at_least: u29,
    };
};

pub const Error = error{
    NotAStruct,
    IsTuple,
    /// an `Error.NoBuffer` occurs when the given type doesn't have a "buffer" field
    NoBuffer,
    BufferNotArray,
    ItemNotItem,
    AlignmentNotExact,
    AlignmentTooSmall,
    CapacityTooSmall,
    CapacityNotExact,
    NotFromFunction,
};

pub inline fn expect(comptime T: type, comptime with: With) Error!void {
    comptime {
        const info = @typeInfo(T);

        if (info != .@"struct")
            return Error.NotAStruct;

        if (info.@"struct".is_tuple)
            return Error.IsTuple;

        const buffer_field: std.builtin.Type.StructField = for (info.@"struct".fields) |field| {
            if (std.mem.eql(u8, field.name, "buffer")) break field;
        } else return Error.NoBuffer;

        const Buffer = buffer_field.type;
        const alignment = buffer_field.alignment;

        const buffer_info = @typeInfo(Buffer);

        if (buffer_info != .array)
            return Error.BufferNotArray;

        const Item = buffer_info.array.child;
        const capacity = buffer_info.array.len;

        if (with.Item) |I| if (I != Item)
            return Error.ItemNotItem;

        if (with.alignment) |with_alignment| switch (with_alignment) {
            .natural => if (alignment != @alignOf(Item)) return Error.AlignmentNotExact,
            .exact => |exact| if (alignment != exact) return Error.AlignmentNotExact,
            .at_least_natural => if (alignment < @alignOf(Item)) return Error.AlignmentTooSmall,
            .at_least => |at_least| if (alignment < at_least) return Error.AlignmentTooSmall,
        };

        if (with.capacity) |with_capacity| switch (with_capacity) {
            .at_least => if (capacity < with_capacity) return Error.CapacityTooSmall,
            .exact => if (capacity != with_capacity) return Error.CapacityNotExact,
        };

        return if (T != std.BoundedArrayAligned(Item, alignment, capacity))
            Error.NotFromFunction;
    }
}

pub inline fn assert(comptime T: type, comptime with: With) void {
    comptime expect(T, with) catch |e| @compileError(logError(e, T, with));
}

pub inline fn logError(comptime e: Error, comptime T: type, comptime with: With) []const u8 {
    comptime {
        const fmt = std.fmt.comptimePrint;
        const function = "std.BoundedArray" ++ if (with.alignment) |alignment| switch (alignment) {
            .natural => "",
            else => "Aligned",
        } else "Aligned";
        const first_argument = (if (with.Item) |Item| @typeName(Item) else "...") ++ ",";
        const second_argument = if (with.alignment) |alignment| switch (alignment) {
            .exact => |exact| fmt("{},", .{exact}),
            .natural => "",
            .at_least => |at_least| fmt(">={},", .{at_least}),
            .at_least_natural => fmt(">=@alignOf({s}),", first_argument[0..first_argument.len -| 1]),
        } else "...,";
        const third_argument = if (with.capacity) |capacity| switch (capacity) {
            .exact => |exact| fmt("{}", .{exact}),
            .at_least => |at_least| fmt(">={}", .{at_least}),
        } else "...";

        return fmt(
            "The type `{s}` isn't a `{s}({s})` because {s}!",
            .{
                @typeName(T),
                function,
                first_argument ++ second_argument ++ third_argument,
                switch (e) {
                    Error.AlignmentNotExact, Error.AlignmentTooSmall => fmt(
                        "its `buffer` field alignment is {}",
                        .{std.meta.fieldInfo(T, "buffer").alignment},
                    ),
                    Error.BufferNotArray => "its `buffer` field isn't an array",
                    Error.CapacityNotExact, Error.CapacityTooSmall => fmt(
                        "its capacity is {}",
                        .{@typeInfo(std.meta.fieldInfo(T, "buffer").type).array.len},
                    ),
                    Error.IsTuple => "it's a tuple",
                    Error.ItemNotItem => fmt(
                        "its items are `{s}`",
                        .{@typeName(@typeInfo(std.meta.fieldInfo(T, "buffer").type).array.child)},
                    ),
                    Error.NoBuffer => "it doesn't have a `buffer` field",
                    Error.NotAStruct => "it isn't a struct type",
                    Error.NotFromFunction => fmt("it wasn't returned by `{s}`", .{function}),
                },
            },
        );
    }
}

pub inline fn Reify(comptime T: type, comptime with: With) type {
    assert(T, with);
    const buffer_info = std.meta.fieldInfo(T, "buffer");
    const Item = @typeInfo(buffer_info.type).array.child;
    const alignment = buffer_info.alignment;
    const capacity = @typeInfo(buffer_info.type).array.len;
    return std.BoundedArrayAligned(Item, alignment, capacity);
}

pub inline fn reify(
    bounded_array_ptr: anytype,
    comptime with: With,
) *const Reify(@TypeOf(bounded_array_ptr.*), with) {
    return bounded_array_ptr;
}

pub inline fn reifyVar(
    bounded_array_ptr: anytype,
    comptime with: With,
) *Reify(@TypeOf(bounded_array_ptr.*), with) {
    return bounded_array_ptr;
}
