# ⚡ Sometype

A Zig module that helps dealing with `anytype` parameters. It provides functions for testing 
whether a given type was returned by an interface in the standard library, or is a certain kind of
builtin.


# ⚙️ Features

I'm not planning to support any version but the latest stable release and the dev branch. For now,
it's only the dev branch.

Each interface has an associated `With` type that defines optional constraints that can be applied
when verifying a type (e.g., requiring a specific `Item` type for `std.ArrayList`). In some cases, a
required constraint is included when multiple interfaces share the same expect function but differ
in API, such as managed vs. unmanaged variants.

Full test coverage requires testing all possible combinations of sum-type parameters. Each test must validate every potential error case, in addition to at least one passing case.

## Zig 0.14-dev

| Interface                                                                                                                    | Implementation |
|------------------------------------------------------------------------------------------------------------------------------|----------------|
| [`std.ArrayList` and similar](https://ziglang.org/documentation/master/std/#std.array_list)                                  | ✅              |
| [`std.ArrayHashMap` and similar](https://ziglang.org/documentation/master/std/#std.array_hash_map.ArrayHashMapWithAllocator) | 🚫             |
| [`std.BoundedArray` and similar](https://ziglang.org/documentation/master/std/#std.bounded_array)                            | 🚫             |
| [`std.BufMap`](https://ziglang.org/documentation/master/std/#std.buf_map.BufMap)                                             | 🚫             |
| [`std.BufSet`](https://ziglang.org/documentation/master/std/#std.buf_set.BufSet)                                             | 🚫             |
| [`std.StaticStringMap`](https://ziglang.org/documentation/master/std/#std.static_string_map.StaticStringMap)                 | 🚫             |
| [`std.StaticStringMapWithEql`](https://ziglang.org/documentation/master/std/#std.static_string_map.StaticStringMapWithEql)   | ❗[^1]          |
| [`std.linked_list` doubly and singly](https://ziglang.org/documentation/master/std/#std.linked_list)                         | 🚧             |
| [`std.EnumArray`](https://ziglang.org/documentation/master/std/#std.enums.EnumArray)                                         | 🚫             |
| [`std.EnumMap`](https://ziglang.org/documentation/master/std/#std.enums.EnumMap)                                             | 🚫             |
| [`std.EnumSet`](https://ziglang.org/documentation/master/std/#std.enums.EnumSet)                                             | 🚫             |
| [`std.HashMap` and similar](https://ziglang.org/documentation/master/std/#std.hash_map.HashMap)                              | 🚫             |
| [`std.MultiArrayList`](https://ziglang.org/documentation/master/std/#std.multi_array_list.MultiArrayList)                    | ✅              |
| [`std.PriorityQueue`](https://ziglang.org/documentation/master/std/#std.priority_queue.PriorityQueue)                        | ❗[^2]          |
| [`std.PriorityDeQueue`](https://ziglang.org/documentation/master/std/#std.priority_dequeue.PriorityDequeue)                  | ❗[^2]          |
| [`std.SegmentedList`](https://ziglang.org/documentation/master/std/#std.segmented_list.SegmentedList)                        | 🚫             |
| [`std.StaticBitSet` and similar](https://ziglang.org/documentation/master/std/#std.bit_set)                                  | 🚫             |
| [`std.StringHashMap` and similar](https://ziglang.org/documentation/master/std/#std.hash_map.StringHashMap)                  | 🚫             |
| [`std.StringArrayHashMap` and similar](https://ziglang.org/documentation/master/std/#std.array_hash_map.StringArrayHashMap)  | 🚫             |
| [`std.Treap`](https://ziglang.org/documentation/master/std/#std.treap.Treap)                                                 | ❗[^3]          |
| [`std.io.GenericReader`](https://ziglang.org/documentation/master/std/#std.io.GenericReader)                                 | ❗[^4]          |
| [`std.io.GenericWriter`](https://ziglang.org/documentation/master/std/#std.io.GenericWriter)                                 | ❗[^5]          |

[^1]: Doesn't expose its `eql: fn (a: []const u8, b: []const u8) bool` parameter.
[^2]: Doesn't expose its `compareFn: fn (context: Context, a: T, b: T) Order` parameter.
[^3]: Doesn't expose its `compareFn: anytype` parameter.
[^4]: Doesn't expose its `readFn: fn (context: Context, buffer: []u8) ReadError!usize` parameter.
[^5]: Doesn't expose its `writeFn: fn (context: Context, bytes: []const u8) WriteError!usize` parameter.


# 📝 Usage

## 🌐 Fetch the package

In your project directory, fetch `sometype` with the following command:

```sh
zig fetch --save=sometype git+https://github.com/Dok8tavo/sometype
```

Normally, it sould add an entry in your `build.zig.zon`, in the `dependencies` field, that look like this:

```zig
// the name "sometype" can be changed with the `--save=[name]` option
.sometype = .{
    // this url will point to a specific commit
    .url = "git+https://github.com/Dok8tavo/sometype",
    // this hash will ensure that the commit didn't change
    .hash = ...,
},
```

## 📁 Include in project

In your `build.zig` file:

```zig
pub fn build(b: *std.Build) !void {
    ...

    const sometype = b.dependency(
        // this is the `--save=[name]` option you chose
        "sometype",

        // those aren't mandatory
        .{
            .target = ...,
            .optimize = ...,
        },
    );

    // the argument must be "sometype", it's defined inside the module
    const sometype_module = sometype.module("sometype");
    // those are the internal tests of the module
    const sometype_tests = sometype.artifact("test");

    ...

    your_module.addImport(
        // this argument is yours to define, it'll affect the `@import()` function in your source code
        "sometype", 
        sometype_module,
    );

    your_artifact.root_module.addImport("sometype", sometype_module);

    ...
}
```

## 💻 Use in code

```zig
// the argument of `@import` is the one defined in the `addImport` call in your `build.zig` file.
const sometype = @import("sometype");

pub fn genericFunction(should_be_an_array_list: anytype) void {
    // this line will at compile-time determine whether the passed argument was returned by
    // `std.ArrayList`
    sometype.array_list.assert(@TypeOf(should_be_an_array_list), .{});

    // this is equivalent
    sometype.assertArrayList(@TypeOf(should_be_an_array_list), .{});

    // and this too but it could also help zls
    const array_list = sometype.array_list.reify(should_be_an_array_list);
}

// the argument could be `std.ArrayListUnmanaged` or `std.MultiArrayList`, so we need to recover
pub fn genericFunction2(multi_or_not: anytype) void {
    sometype.expectArrayList(@TypeOf(multi_or_not), .{ .allocator = false }) catch
        sometype.assertMultiArrayList(@TypeOf(multi_or_not), .{});
}
```


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
