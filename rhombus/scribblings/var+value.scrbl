#lang scribble/rhombus/manual
@(import:
    "util.rhm" open
    "common.rhm" open)

@title(~tag: "mutable-vars"){Variables and Values}

Variables are immutable unless they are declared with the
@rhombus(mutable, ~bind) binding operator. The @rhombus(:=) infix operator
assigns to a mutable variable.

@demo(
  ~defn:
    def mutable todays_weather = "sunny"
  ~repl:
    todays_weather
    todays_weather := "rainy"
    todays_weather
  ~defn:
    fun f(mutable x):
      x := x + 8
      x
  ~repl:
    f(10)
    ~error: f := 5
)

The @rhombus(:=) operator can also change object fields accessed via
@rhombus(.) when a class field is declared @rhombus(mutable, ~bind).

@demo(
  ~defn:
    class Box(mutable content)
  ~repl:
    def present = Box("socks")
    present.content
    present.content := "toy"
    present.content
)

Most expressions in Rhombus produce a single value. The @rhombus(values)
form, however, returns multiple values:

@demo(
  values(1, "apple")
)

When an expression in a module body returns multiple values, each one is
printed. Returning multiple values is different that returning one value
that is a list of values, similar to the way that passing multiple
arguments to a function is different than passing one argument that is a
list. To receive multiple values from an expression, you need to use a
special binding form.

When the @rhombus(def) binding form is followed by parentheses with @math{N}
groups, then the right-hand side should produce @math{N} values, and each
value is matched against the corresponding group.

@demo(
  ~defn:
    def (n, s) = values(1, "apple")
  ~repl:
    n
    s
)

A definition binding with with @rhombus(val) or @rhombus(def) can also
use @rhombus(values) in the outermost pattern, and that’s the same as
not writing @rhombus(values), but it makes the receiver and sender side
look more the same:

@demo(
  ~defn:
    def values(n, s) = values(1, "apple")
  ~repl:
    n
    s
)