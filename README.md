# ⚡ Sometype

A Zig module that helps dealing with `anytype` parameters. It provides functions for testing 
whether a given type was returned by an interface in the standard library, or is a certain kind of
builtin.

# ⚙️ Features

I'm not planning to support any version but the latest stable release and the dev branch. For now,
it's only the dev branch.

Each interface has an associated With type that defines optional constraints that can be applied
when verifying a type (e.g., requiring a specific Item type for std.ArrayList). In some cases, a
required constraint is included when multiple interfaces share the same expect function but differ
in API, such as managed vs. unmanaged variants.

Full test coverage requires testing all possible combinations of sum-type parameters. Each test must validate every potential error case, in addition to at least one passing case.

## Zig 0.14-dev

| Interface                            | Implementation | Testing |
|--------------------------------------|----------------|---------|
| `std.ArrayList` and similar          | ✅              | 🚧      |
| `std.ArrayHashMap` and similar       | 🚫             | 🚫      |
| `std.BoundedArray` and similar       | 🚫             | 🚫      |
| `std.BufMap`                         | 🚫             | 🚫      |
| `std.BufSet`                         | 🚫             | 🚫      |
| `std.StaticStringMap`                | 🚫             | 🚫      |
| `std.StaticStringMapWithEql`         | ❗[^1]          | ❗[^1]   |
| `std.DoublyLinkedList`               | 🚫             | 🚫      |
| `std.EnumArray`                      | 🚫             | 🚫      |
| `std.EnumMap`                        | 🚫             | 🚫      |
| `std.EnumSet`                        | 🚫             | 🚫      |
| `std.HashMap` and similar            | 🚫             | 🚫      |
| `std.MultiArrayList`                 | ✅              | 🚫      |
| `std.PriorityQueue`                  | ❗[^2]          | ❗[^2]   |
| `std.PriorityDeQueue`                | ❗[^2]          | ❗[^2]   |
| `std.SegmentedList`                  | 🚫             | 🚫      |
| `std.SinglyLinkedList`               | 🚫             | 🚫      |
| `std.StaticBitSet` and similar       | 🚫             | 🚫      |
| `std.StringHashMap` and similar      | 🚫             | 🚫      |
| `std.StringArrayHashMap` and similar | 🚫             | 🚫      |
| `std.Treap`                          | ❗[^3]          | ❗[^3]   |
| `std.io.GenericReader`               | ❗[^4]          | ❗[^4]   |
| `std.io.GenericWriter`               | ❗[^5]          | ❗[^5]   |

[^1]: Doesn't expose its `eql: fn (a: []const u8, b: []const u8) bool` parameter.
[^2]: Doesn't expose its `compareFn: fn (context: Context, a: T, b: T) Order` parameter.
[^3]: Doesn't expose its `compareFn: anytype` parameter.
[^4]: Doesn't expose its `readFn: fn (context: Context, buffer: []u8) ReadError!usize` parameter.
[^5]: Doesn't expose its `writeFn: fn (context: Context, bytes: []const u8) WriteError!usize` parameter.


# 📃 License

MIT License

Copyright (c) 2025 Dok8tavo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
