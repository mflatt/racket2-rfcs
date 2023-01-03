#lang scribble/rhombus/manual
@(import:
    "util.rhm" open
    "common.rhm" open)

@(def posn_eval = make_rhombus_eval())

@title(~tag: "classes_and_patterns"){Classes and Patterns}

In the same way that @rhombus(fun) and @rhombus(fun) defines a variable
or function, @rhombus(class) defines a new class. By convention, class
names start with a capital letter.

@(
  demo:
    ~eval: posn_eval
    ~defn:
      class Posn(x, y))

A class name can be used like a function to construct an instance of the
class. An instance expression followed by @rhombus(.) and a field name
extracts the field value from the instance.

@(
  demo:
    ~eval: posn_eval
    ~defn:
      def origin = Posn(0, 0)
    ~repl:
      origin
      origin.x
)

A class name followed by @rhombus(.) and a field name gets an accessor
function to extract the field value from an instance of the class:

@(
  demo:
    ~eval: posn_eval
    Posn.x(origin)
)

Comparing @rhombus(Posn.x) to a function that uses @rhombus(.x) on its
argument, the difference is that @rhombus(Posn.x) works only on
@rhombus(Posn) instances. That constraint makes field access via
@rhombus(Posn.x) more efficient than a generic lookup of a field with
@rhombus(.x).

An @deftech{annotation} associated with a binding or expression can make
field access with @rhombus(.x) the same as using a class-specific
accessor. Annotations are particularly encouraged for a function
argument that is a class instance, and the annotation is written after
the argument name with @rhombus(-:, ~bind) and the class name:

@(
  demo:
    ~eval: posn_eval
    ~defn:
      fun flip(p -: Posn):
        Posn(p.y, p.x)
    ~repl:
      flip(Posn(1, 2))
)

Using @rhombus(-:, ~bind) makes an assertion about values that are provided as
arguments, but that assertion is not checked when the argument is
provided. In effect, the annotation simply selects a class-specific
field accessor for @rhombus(.x). If @rhombus(flip) is called with
@rhombus(0), then a run-time error will occur at the point that
@rhombus(p.y) attempts to access the @rhombus(y) field of a
@rhombus(Posn) instance:

@(
  demo:
    ~eval: posn_eval
    ~error: flip(0)
)

The @rhombus(::, ~bind) binding operator is another way to annotate a variable.
Unlike @rhombus(-:, ~bind), @rhombus(::, ~bind) installs a run-time check that a value
supplied for the variable satisfies its annotation. The following
variant of the @rhombus(flip) function will report an error if its
argument is not a @rhombus(Posn) instance, and the error is from
@rhombus(flip) instead of delayed to the access of @rhombus(y):

@(
  demo:
    ~eval: posn_eval
    ~defn:
      fun flip(p :: Posn):
        Posn(p.y, p.x)
    ~repl:
      ~error: flip(0)
)

A run-time check implied by @rhombus(::, ~bind) can be expensive, depending on
the annotation and context. In the case of @rhombus(flip), this check is
unlikely to matter, but if a programmer uses @rhombus(::, ~bind) everywhere to
try to get maximum checking and maximum guarantees, it’s easy to create
expensive function boundaries. Rhombus programmers are encouraged to use
@rhombus(-:, ~bind) when the goal is to hint for better performance, and use
@rhombus(::, ~bind) only where a defensive check is needed, such as for the
arguments of an exported function.

The use of @rhombus(-:, ~bind) or @rhombus(::, ~bind) as above is not specific to
@rhombus(fun). The @rhombus(-:, ~bind) and @rhombus(::, ~bind) binding operators work
in any binding position, including the one for @rhombus(def):

@(
  demo:
    ~eval: posn_eval
    ~defn:
      def (flipped -: Posn) = flip(Posn(1, 2))
    ~repl:
      flipped.x
)

The @rhombus(class Posn(x, y)) definition does not place any constraints
on its @rhombus(x) and @rhombus(y) fields, so using @rhombus(Posn) as a
annotation similarly does not imply any annotations on the field
results. Instead of using just @rhombus(Posn) as a annotation, however,
you can use @rhombus(Posn.of) followed by parentheses containing
annotations for the @rhombus(x) and @rhombus(y) fields. More generally,
a @rhombus(class) definition binds the name so that @rhombus(.of)
accesses an annotation constructor.

@(
  demo:
    ~eval: posn_eval
    ~defn:
      fun flip_ints(p :: Posn.of(Integer, Integer)):
        Posn(p.y, p.x)
    ~repl:
      flip_ints(Posn(1, 2))
      ~error: flip_ints(Posn("a", 2))
)

Finally, a class name like @rhombus(Posn) can also work in binding
positions as a pattern-matching form. Here’s a implementation of
@rhombus(flip) that uses pattern matching for its argument:

@(
  demo:
    ~eval: posn_eval
    ~defn:
      fun flip(Posn(x, y)):
        Posn(y, x)
    ~repl:
      ~error: flip(0)
      flip(Posn(1, 2))
)

As a function-argument pattern, @rhombus(Posn(x, y)) both requires the
argument to be a @rhombus(Posn) instance and binds the identifiers
@rhombus(x) and @rhombus(y) to the values of the instance’s fields.
There’s no need to skip the check that the argument is a @rhombus(Posn),
because the check is anyway part of extracting @rhombus(x) and
@rhombus(y) fields.

As you would expect, the fields in a @rhombus(Posn) binding pattern are
themselves patterns. Here’s a function that works only on the origin:

@(
  demo:
    ~eval: posn_eval
    ~defn:
      fun flip_origin(Posn(0, 0)):
        origin
    ~repl:
      ~error: flip_origin(Posn(1, 2))
      flip_origin(origin)
)

Finally, a function can have a result annotation, which is written with
@rhombus(-:) or @rhombus(::) after the parentheses for the function’s
argument. With a @rhombus(::) result annotation, every return value from
the function is checked against the annotation. Beware that a function’s
body does not count as being tail position when the function is declared
with a @rhombus(::) result annotation.

@(
  demo:
    ~eval: posn_eval
    ~defn:
      fun same_posn(p) -: Posn:
        p
    ~repl:
      same_posn(origin)
      same_posn(5)  // no error, since `-:` does not check
      same_posn(origin).x  // uses efficient field access
    ~defn:
      fun checked_same_posn(p) :: Posn:
        p
    ~repl:
      checked_same_posn(origin)
      ~error: checked_same_posn(5)
)

The @rhombus(let) form is like @rhombus(def), but it makes bindings
available only @emph{after} the definition, and it shadows any binding
before, which is useful for binding a sequence of results to the same
name. The @rhombus(let) form does not change the binding region of other
definitions, so a @rhombus(def) after @rhombus(let) binds a name that is
visible before the @rhombus(let) form.

@(
  rhombusblock:
    #lang rhombus

    fun get_after(): after

    def accum = 0
    let accum = accum+1
    let accum = accum+1
    accum  // prints 2

    def after = 3
    get_after()  // prints 3
)

The identifier @rhombus(_, ~bind) is similar to @rhombus(Posn) and
@rhombus(-:, ~bind) in the sense that it’s a binding operator. As a
binding, @rhombus(_, ~bind) matches any value and binds no variables.
Use it as an argument name or subpattern form when you don’t need the
corresponding argument or value, but @rhombus(_, ~bind) nested in a
binding pattern like @rhombus(::, ~bind) can still constrain allowed
values.

@(
  demo:
    ~eval: posn_eval
    ~defn:
      fun omnivore(_): "yum"
      fun omnivore2(_, _): "yum"
      fun nomivore(_ :: Number): "yum"
    ~repl:
      omnivore(1)
      omnivore("apple")
      omnivore2("a", 1)
      nomivore(1)
      ~error: nomivore("a")
)


@close_eval(posn_eval)
