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

pub fn isArrayListAligned(comptime T: type) bool {
    comptime {
        const info = @typeInfo(T);

        if (info != .@"struct")
            return false;

        if (info.@"struct".is_tuple)
            return false;

        if (!@hasField(T, "Slice"))
            return false;

        if (@TypeOf(T.Slice) != type)
            return false;

        const slice_info = @typeInfo(T.Slice);

        if (slice_info != .pointer)
            return false;

        if (slice_info.pointer.size != .slice)
            return false;

        const Item = slice_info.pointer.child;
        const alignment = slice_info.pointer.alignment;

        return std.ArrayListAligned(Item, alignment);
    }
}
