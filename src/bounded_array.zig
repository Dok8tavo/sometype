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
        mod_suggested_vector_length,
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
    CapacityNotModSuggestedVectorLength,
    NoSuggestedVectorLength,
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
            .mod_suggested_vector_length => if (std.simd.suggestVectorLength(Item)) |svl| {
                if (capacity % svl != 0) return Error.CapacityNotModSuggestedVectorLength;
            } else return Error.NoSuggestedVectorLength,
        };

        return if (T != std.BoundedArrayAligned(Item, alignment, capacity))
            Error.NotFromFunction;
    }
}
