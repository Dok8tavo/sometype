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

pub const array_list = @import("array_list.zig");
pub const array_list_managed = @import("array_list_managed.zig");
pub const array_list_unmanaged = @import("array_list_unmanaged.zig");

pub const bounded_array = @import("bounded_array.zig");

pub const linked_list = @import("linked_list.zig");
pub const singly_linked_list = @import("singly_linked_list.zig");
pub const doubly_linked_list = @import("doubly_linked_list.zig");

pub const multi_array_list = @import("multi_array_list.zig");

// array lists
pub const expectArrayList = array_list.expect;
pub const assertArrayList = array_list.assert;
pub const reifyArrayList = array_list.reify;
pub const reifyVarArrayList = array_list.reifyVar;

pub const expectArrayListManaged = array_list_managed.expect;
pub const assertArrayListManaged = array_list_managed.assert;
pub const reifyArrayListManaged = array_list_managed.reify;
pub const reifyVarArrayListManaged = array_list_managed.reifyVar;

pub const expectArrayListUnanaged = array_list_unmanaged.expect;
pub const assertArrayListUnanaged = array_list_unmanaged.assert;
pub const reifyArrayListUnanaged = array_list_unmanaged.reify;
pub const reifyVarArrayListUnanaged = array_list_unmanaged.reifyVar;

// bounded array
pub const expectBoundedArray = bounded_array.expect;
pub const assertBoundedArray = bounded_array.assert;
pub const reifyBoundedArray = bounded_array.reify;
pub const reifyVarBoundedArray = bounded_array.reifyVar;

// linked lists
pub const expectLinkedList = linked_list.expect;
pub const assertLinkedListt = linked_list.assert;
pub const reifyLinkedList = linked_list.reify;
pub const reifyVarLinkedList = linked_list.reifyVar;

pub const expectSinglyLinkedList = singly_linked_list.expect;
pub const assertSinglyLinkedList = singly_linked_list.assert;
pub const reifySinglyLinkedList = singly_linked_list.reify;
pub const reifyVarSinglyLinkedList = singly_linked_list.reifyVar;

pub const expectDoublyLinkedList = doubly_linked_list.expect;
pub const assertDoublyLinkedList = doubly_linked_list.assert;
pub const reifyDoublyLinkedList = doubly_linked_list.reify;
pub const reifyVarDoublyLinkedList = doubly_linked_list.reifyVar;

pub const expectMultiArrayList = multi_array_list.expect;
pub const assertMultiArrayList = multi_array_list.assert;
pub const reifyMultiArrayList = multi_array_list.reify;
pub const reifyVarMultiArrayList = multi_array_list.reifyVar;

test {
    _ = array_list;
    _ = array_list_managed;
    _ = array_list_unmanaged;

    _ = bounded_array;

    _ = linked_list;
    _ = doubly_linked_list;
    _ = singly_linked_list;

    _ = multi_array_list;
}
