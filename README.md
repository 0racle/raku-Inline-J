NAME
===

Inline::J - Use the [J programming language](https://www.jsoftware.com) inside Raku.

SYNOPSIS
========

```raku
use Inline::J;

my \j = Inline::J.new(:load-profile);

say j.eval('i. 6');
# 0 1 2 3 4 5

say my $n = j.noun('>: 2 4 $ i. 8');
# 1 2 3 4
# 5 6 7 8

say j.eval("{(1,2) »×» 10} + $n");
# 11 12 13 14
# 25 26 27 28

say my $a = $n.getm;
# [[1 2 3 4]
#  [5 6 7 8]]

say $a.^name => $a.shape;
# Array[Int] => [2 4]

say j.gets(‘2 5 $ 'HelloWorld'’);
# [[H e l l o]
#  [W o r l d]]
```

WARNING
=======

This module is under development. As such, the API is subject to change at any time, and there might be bugs.
The use of this module in Production is not recommended.

INSTALLATION
============

To install this module you need to have J already installed. See the [J Software Wiki](https://code.jsoftware.com/wiki/System/Installation) for more info.

During installation of this module, it will attempt to locate the `bin` path where J shared lib is located. It will search the most common install locations for POSIX or Windows depending on your system. Alternatively, you can export the `bin` location the environment variable `JBINPATH` before installation.


GETTING STARTED
===============

The start using `Inline::J`, first create a new `Inline::J` object.
To load the default J profile, pass a truthy `load-profile` named argument.
You should `load-profile` if you wish to use names defined in the [Standard Library](https://code.jsoftware.com/wiki/Standard_Library/Overview).

```raku
my \j = Inline::J.new(:load-profile);
say j.eval(‘toupper 'hello, world!'’);
# HELLO, WORLD!
```

Alternatively you can use the `load-profile` method, which return `self`.
```raku
my \y = Inline::J.new.load-profile;
```

Note that each object is it's own separate interpreter.
```raku
j.eval('n =: 1');
y.eval('echo n');  # fail: value error
```

USAGE
=====

## Inline::J

do
--

The `do` method accepts a single J expression and passes it to the J interpreter. Any non-Str values will be coerced to a Str.

If there are any errors, it will return a [Failure](https://docs.raku.org/type/Failure) with the error message.

This method returns `self`, so that multiple expressions can be chained.

```raku
j.do('a =. i. 3').do('a =. 5 + a');  # ok
j.do('notaverb 1');                  # fail: value error
```

getr
----

The `getr` method returns the output of the last expression passed to `do`, with the trailing newline `chomp`d.

```raku
j.do('a').getr;
# 5 6 7
```

eval
----
This is a convenience function that simply chains a `do` and `getr` call into one function

```raku
say j.eval('(+/ % #) 3 1 4 1 5 9');
# 3.83333
```

Since this wraps `do`, the `eval` method can also return a Failure.

free
----
This calls the `JFree` C function to free the J interpreters memory. Ideally, this should not need to be run, as `Inline::J` objects call this method on `DESTROY`.

```raku
END { j.free }
```

noun
----
This method creates an `Inline::J::Noun` object that references a noun in J. The `gist` of this object is the J representation of this noun.

If a noun already exists in J, you can create an `Inline::J::Noun` by providing it's name.

```raku
my $a = j.noun(name => 'a');
say $a;
# 5 6 7
```

**NOTE:** When an Inline::J::Noun object is `DESTROY`'d, the J noun will be erased and it's storage freed by calling `(4!:55) <'name'` in J.

Alternatively, you can declare a new variable in J by also providing an expression

```raku
my $b = j.noun('10 20 30', name => 'b');
say $b;
# 10 20 30
```

This is essentially the same as doing `j.eval(b =. 10 20 30)`, only now you have a Raku object that references the noun.

If you do not provide a name, a random name will be generated for you.

```raku
my $v = j.noun('42');
say $v.name;
# ijn_d63a244e
```

## Inline::J::Noun

An `Inline::J::Noun` (`IJN`) object references a noun in J. The `gist` of this object is the J representation of this noun.

**EXPERIMENTAL:** Currently, an `IJN` stringifies to it's name. This allows them to be interpolated into J expressions.

```raku
say j.eval("a + $b");
# 15 26 37
```

I'm not sure if this is a good idea yet, but it's fun. The alternative would be to explicitly interpolate it's name into expressions, eg.

```raku
say j.eval("a + {$b.name}");
```

Which is not as much fun.

### Methods

The following examples will use the following value

```raku
my $m = j.noun('2 3 4 $ i. 24');
```

gist
----

Returns the J representation of the noun
An objects `.gist` method is called automatically by `say`.

```raku
say $m;
#  0  1  2  3
#  4  5  6  7
#  8  9 10 11
#
# 12 13 14 15
# 16 17 18 19
# 20 21 22 23
```

name (Str)
----------

Returns the name of the noun in J, which may be different from the variable name in Raku, and is randomly generated when not specified

This method is also called when coercing the object to a string (eg. `$m.Str`, `"$m"`, `~$m`, `put $m`, etc.)

```raku
say $m.name;
# ijn_f39324d1
```

datatype
--------

Returns an Inline::J::Datatype enum.

The numeric value of the enum will match J's type identifier

```raku
say $m.datatype;
# integer
say +$m.datatype;
# 4
```

shape
-----

Returns a Seq of Ints that count the length (number of items) in each axis.

```raku
say $m.shape;
# (2 3 4)
```

tally
-----

Returns an Int of the count of _items_ in the array.

As per the J documentation

    > The items of an array are the cells whose rank is 1 lower than the rank of the array.
    > Thus, the items of a list are atoms, and the items of a table are lists.

The tally can also be derived from the shape by taking the first element of the shape.

```raku
say $m.tally;
# 2
```

rank
----

Returns an Int of the count of axis in the array.

The rank can be derived from the shape by taking the count of element of the shape.

```raku
say $m.rank;
# 3
```

elems
-----

Returns an Int of the total count of scalar items in the array

The elems can be derived from the shape by taking the product of the shape.

```raku
say $m.elems;
# 24
```

AT-POS
------

**EXPERIMENTAL**

I've added an `.AT-POS` method (which is called when you index into an object).

Currently this just returns a string from J.

```raku
say $m[1;0];
# 12 13 14 15
```

## Inline::J::Verb

Similar to `IJN`'s, an `Inline::J::Verb` (`IJV`) object references a verb defined in J. The object `does Callable` so that it acts like a Raku function.

Currently `IJV` callables accept 1 or 2 `IJN`'s, 1 or 2 Raku `Real` numbers, or 1 or 2 shaped Raku shaped arrays.

`Real`s are just _stringified_ and interpreted by J.
Shaped `Array`s will be converted to an `IJN` and passed to the verb.

Callables accept 0, 1, or 2 arguments. When calling with 0 arguments, the J function is actually called with the empty string value. `IJV`'s will call `j.noun`, and hence, return an `IJN` which you can (attempt to) convert to a Raku type by calling `.getm` on the returned value.

```raku
my &f = j.verb('>:');

my $n = j.noun('i. 10');
my $i = j.noun(4);

say f($n);
# 1 2 3 4 5 6 7 8 9 10

say f($i, $n);
# 1 1 1 1 1 0 0 0 0 0
```

Example of passing a Raku Array to a J verb

```raku
# Raku shaped Array
say my Int @a[4;4] = ([1..4] xx 4);
# [[1 2 3 4]
#  [1 2 3 4]
#  [1 2 3 4]
#  [1 2 3 4]]

# Passing it to a IJV, returns an IJN
# Convert back to Raku by calling .getm
say j.verb('|."_1~ i.@#')(@a).getm;
# [[1 2 3 4]
#  [2 3 4 1]
#  [3 4 1 2]
#  [4 1 2 3]]
```

Like `IJN`s, `IJV`'s also get a random name (if none is provided)

```raku
my &t = j.verb('|:');
say &t.name;
# ijv_c79ce86a
```

They can tell you their rank, and have a hard-coded arity/count of 1/2.

```raku
say &t.rank;
# _ 1 _

say &t.arity;
# 1

say &t.count;
# 2
```

**LIMITATION:** Currently only monadic and dyadic verbs are supported, `(4!:0)` will be checked to ensure a value of `3` (verb) type, otherwise an Exception is thrown

```raku
my &c =. j.verb(';.');  # dies: Not a verb
```

**EXPERIMENTAL:** Since `IJV`'s are Raku objects, Raku operators could provide multi's specific for them. Once experiment I've added is a multi for `&infix:<∘>`, which will compose 2 `IJV`s in J using `@:` ([At](https://code.jsoftware.com/wiki/Vocabulary/atco))

```raku
my $x = j.noun(<1 2 3>);
my $y = j.noun(<2 2 2>);

my &f = j.verb('+/');
my &g = j.verb('*:');
my &h = j.verb('-');

#| sum of squared differences
my &sum-sq-diff = &f ∘ &g ∘ &h;
say sum-sq-diff($x, $y);
# 2
```

**NOTE:** Doing the compose (`∘`) _in J_ avoids unnecessary `IJN` creation, which happens when `IJV`'s return data to Raku.

DATA CONVERSION
===============

**WARNING:** The code for handling data conversion is in a messy state and largely untested.

J to Raku
---------

J scalars, lists, and matrices can be converted to Raku scalars and arrays. Currently this module strongly prefers creating shaped & typed Raku arrays.

Currently the only J datatypes supported are:

  * boolean  -> Bool
  * literal  -> Str
  * integer  -> Int
  * floating -> Num
  * unicode  -> Str
  * unicode4 -> Str  (**EXPERIMENTAL**)

unicode values are encoded as UTF-16 in J, but normalised to UTF-8 when converted to Raku.
unicode4 values are encoded as UTF-32 in J. Raku (specifically, it's VM) does not have a UTF-32 decoder, so I have written a naïve `utf32-to-utf8` function in pure Raku, which may be buggy, and is likely to be slow on large inputs.

Current notable omissions are 'extended', 'rational', and 'complex' numbers, as well as 'boxed' arrays.

getm
----

The `Inline::J` object provides the following method to get a J noun and convert it to a Raku

```raku
my $arr = j.getm($m.name);
say $arr;
# [[[0 1 2 3]
#   [4 5 6 7]
#   [8 9 10 11]]
#  [[12 13 14 15]
#   [16 17 18 19]
#   [20 21 22 23]]]
```

Note however, that `Inline::J::Noun` objects also have a `getm` method available, so the above could also be expressed as:

```raku
my $arr = $m.getm;
```

As stated, the Raku array returned is shaped and typed.

```raku
say  $arr.^name => $arr.shape;
# Array[Int] => [2 3 4]
```

The only minor issue with `getm` is that it relies on the noun existing in J. This is probably fine on a small scale, but on a larger scale could cause an explosion of declared nouns in J if not handled properly.

gets
----

Sometimes, you might want to create a Raku data structure from a J expression without declaring a noun. J provides a foreign function `(3!:3)` which displays an ASCII (hex) representation of the data, which `Inline::J` can parse.

```raku
say j.gets('2 5 $ i. 10');
# [[0 1 2 3 4]
#  [5 6 7 8 9]]
```

For (currently) no obvious reason, `Inline::J::Noun` objects also have a `gets` method, which bypasses the underlying `JGetM` C function, and parses the ASCII representation instead

```raku
say $a.gets;
# [5 6 7]
```

**WARNING:** This relies on string output from J. By default, J truncates to 256 columns and 222 rows. I have increased this arbitrarily by 2000 (to 2256 columns 2222 rows), but if you are trying to `gets` a value where the ASCII representation does not fit into this limitation, it will fail in strange ways. You can always increase the values with `(9!:37)`, but trying to convert values so large is not recommended.


Raku to J
---------

**WARNING:** Barely developed.

Currently, only Raku shaped and typed Arrays can be converted to J arrays and matrices.

The only Raku types currently supported are:

  * Bool -> boolean
  * Str  -> literal (or unicode\*)
  * Int  -> integer
  * Num  -> floating

\* When converting an Array of Str to J, `Inline::J` will check if any codepoints are > 255, and if so, the Str's are encoded as UTF-16 (J's `unicode`) before passing to J.

setm
----

The `Inline::J` object provides the following method to set a J noun from a Raku data structure

```raku
my Bool @b[2;2] = [(True, False), (False, True)];
j.setm('b', @b);
say j.eval('b');
# 1 0
# 0 1
```

In addition to creating a noun in the J instance, the `setm` method also returns an `IJN`.
```raku
my $b = j.setm('b', @b);  # Eqv to `my $b = j.noun('b');`
say $b.^name;
# Inline::J::Noun
```

Existing `IJN` objects can also have their value over-written with the `setm` method

```raku
$m.setm(Array[Str].new(:shape(2;3), [<A B Ć>, <D E F>]));

say $m;
# ABĆ
# DEF

say $m.^name => $m.datatype;
# Inline::J::Noun => unicode
```

CAVEATS AND LIMITATION
======================

This module was developed on a x86-64 (little endian) system, and byte-data returned from J is assumed to be 64-bit little endian. Expect things to fail when running on 32-bit builds/systems, or systems that use big endian.

It should be possible to support 32-bit (and/or big endian) systems with a bit of effort, although I do not have a need for it, and will not be developing this support. Pull requests welcome.

TODO
====

The following items are pending further development

  * Support more values for `setm`
    - Add support for Scalars
    - Maybe allow non-shaped arrays (eg. infer shape recursive .elems?)
  * export helper subs
    - Ease passing of Raku data to J

Pull request welcome.

FINAL THOUGHTS
==============

I'm not a C programmer, and I've barely used NativeCall in the past, so it's entirely possibly I'm doing things in a less-than-optimum way. If anyone is a C/NativeCall guru, I would appreciate and feedback on whether there are better ways I could be handling the data conversions. The header file for `libj` is [here](https://github.com/jsoftware/jsource/blob/7a3945dc6f46176fd9c7741477c677ed114f32b0/jsrc/jlib.h).

So far it's just been me playing around with this module, trying to work out what useful methods and functionality would be useful. I haven't had a good look at it, but a potential source to mine ideas from is [Py'n'APL](https://github.com/Dyalog/pynapl/) library.

In general, I'm open to feedback from fellow J+Raku users on settling on the API of this module.
