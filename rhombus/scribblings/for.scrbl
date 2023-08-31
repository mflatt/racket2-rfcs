#lang scribble/rhombus/manual
@(import:
    "util.rhm" open
    "common.rhm" open)

@title(~tag: "for"){Iteration}

Many simple forms of iteration can be expressed through repetitions. For
other cases. Rhombus supports a proper implementation of tail-call
handling (i.e., tail calls do not extend the continuation), so looping
can be written as a recursive function. Still, a looping construct is
convenient and useful for writing iterations that are not simple enough
for repetitions but also do not need the full expressiveness of
functions.

The @rhombus(for) form supports iteration over @tech{sequences},
which includes lists, arrays, maps, and sets. In the body of a @rhombus(for)
form, each @rhombus(each, ~for_clause) clause binds to an element of a sequence for
each iteration. The length of the sequence determines the number of
iterations. The @rhombus(..) operator creates a sequence of integers
from a starting integer (inclusive) to an ending integer (exclusive):

@demo(
  for:
    each i: 1..4
    println(i)
)

As a shorthand, an initial @rhombus(each, ~for_clause) form can be written
using parentheses before the @rhombus(for) body block:

@demo(
  for (i: 1..4):
    println(i)
)

If a @rhombus(for) body includes multiple @rhombus(each, ~for_clause) clauses, they
are nested. That is, for each element of the first @rhombus(each, ~for_clause) clause,
all elements are used for the second @rhombus(each, ~for_clause) clause, and so on.

@demo(
  for:
    each friend: ["Alice", "Bob", "Carol"]
    each say: ["Hello", "Goodbye"]
    println(say +& ", " +& friend +& "!")
)

An advantage of having @rhombus(each, ~for_clause) clauses in the body of
@rhombus(for), instead of putting them before the body as in many other
languages, is that definitions or expressions can be written among
@rhombus(each, ~for_clause) clauses.

@demo(
  for:
    each friend: ["Alice", "Bob", "Carol"]
    def dear_friend = "dear " +& friend
    each say: ["Hello", "Goodbye"]
    println(say +& ", " +& dear_friend +& "!")
)

To draw elements from sequences in parallel, use a block of bindings
immediately after @rhombus(each, ~for_clause).

@demo(
  for:
    each:
      friend: ["Alice", "Bob", "Carol"]
      index: 1..4
    println(index +& ". " +& friend)
)

Note that the shorthand form using parentheses for an initial
@rhombus(each, ~for_clause) clause corresponds to this parallel mode,
since the short is for a single @rhombus(each, ~for_clause) clause:

@demo(
  for (friend: ["Alice", "Bob", "Carol"],
       index: 1..4):
    println(index +& ". " +& friend)
)

In this latest example, the sequence for @rhombus(index) could be
@rhombus(1..) to avoid needing the length of the list for
@rhombus(friend). When @rhombus(..) has no second argument, it creates
an infinite sequence of integers, and when @rhombus(for) iterates over
sequences in parallel, it stops when the shortest sequence stops.

The @rhombus(for) form acts as a comprehension form when a
@deftech{reducer} is specified before the @rhombus(for) body block.
@rhombus(List, ~reducer) serves as a reducer to generate a list,
accumulating the values produced by each iteration of the @rhombus(for)
body.

@demo(
  for List (i: 1..4):
    "number " +& i
  for List:
    each i: [1, 2]
    each j: ["a", "b", "c"]
    [i, j]
)

If you prefer, you can put the reducer at the end of a @rhombus(for)
body with @rhombus(~into).

@demo(
  for (i: 1..4):
    "number " +& i
    ~into List
)

@rhombus(Map, ~reducer) works as a reducer where the body of the
@rhombus(for) form must produce two values for each iteration: a key and
a value.

@demo(
  for Map (friend: ["alice", "bob", "carol"],
           index: 1..):
    values(index, friend)
)

The @rhombus(values, ~reducer) reducer implements the general case, where
@rhombus(values) is followed by a parenthesized sequence of identifiers
with initial values, the @rhombus(for) body can refer to those
identifiers to get values from the previous iteration (or the initial
values in the case of the first iteration), and the @rhombus(for) body
returns as many values as identifiers to provide new values for the
identifiers.

@demo(
  fun sum(l :~ List):
    for values(sum = 0):
      each i: l
      sum+i
  sum([2, 3, 4])
)

In the same way that a @rhombus(List, ~annot) annotation specializes
element access via @litchar{[}...@litchar{]}, it also specializes how
@rhombus(each, ~for_clause) within @rhombus(for) iterates through a list. In the
following example, @rhombus(ll) is annotated as a list of lists, so both
the outer and inner iterations are specialized---although that
specialization is visible only as a change in performance, if at all.

@demo(
  fun sum2d(ll :~ List.of(List.of(Number))):
    for values(sum = 0):
      each l: ll
      each i: l
      sum+i
  sum2d([[1], [2, 3, 4], [5, 6, 7], [8, 9]])
)
