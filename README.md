# ⚡ Sometype

A Zig module that helps dealing with `anytype` parameters. It provides functions for testing whether
a given type was returned by an interface in the standard library, or is a certain kind of builtin.

# ⚙️ Features

I'm not planning to support any version but the latest stable release and the dev branch.
For now, it's only the dev branch.

## Zig 0.14-dev

| Interface                            | Coverage              |
|--------------------------------------|-----------------------|
| `std.ArrayList` and similar          | Partially tested      |
| `std.ArrayHashMap` and similar       | Not implemented       |
| `std.BoundedArray` and similar       | Not implemented       |
| `std.BufMap`                         | Not implemented       |
| `std.BufSet`                         | Not implemented       |
| `std.StaticStringMap`                | Not implemented       |
| `std.StaticStringMapWithEql`         | Can't be implemented¹ |
| `std.DoublyLinkedList`               | Not implemented       |
| `std.EnumArray`                      | Not implemented       |
| `std.EnumMap`                        | Not implemented       |
| `std.EnumSet`                        | Not implemented       |
| `std.HashMap` and similar            | Not implemented       |
| `std.MultiArrayList`                 | Not implemented       |
| `std.PriorityQueue`                  | Can't be implemented² |
| `std.PriorityDeQueue`                | Can't be implemented² |
| `std.SegmentedList`                  | Not implemented       |
| `std.SinglyLinkedList`               | Not implemented       |
| `std.StaticBitSet` and similar       | Not implemented       |
| `std.StringHashMap` and similar      | Not implemented       |
| `std.StringArrayHashMap` and similar | Not implemented       |
| `std.Treap`                          | Can't be implemented³ |
| `std.io.GenericReader`               | Can't be implemented⁴ |
| `std.io.GenericWriter`               | Can't be implemented⁵ |

---

Doesn't expose its `eql: fn (a: []const u8, b: []const u8) bool` parameter¹

Doesn't expose its `compareFn: fn (context: Context, a: T, b: T) Order` parameter²

Doesn't expose its `compareFn: anytype` parameter³

Doesn't expose its `readFn: fn (context: Context, buffer: []u8) ReadError!usize` parameter⁴

Doesn't expose its `writeFn: fn (context: Context, bytes: []const u8) WriteError!usize` parameter⁵


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
