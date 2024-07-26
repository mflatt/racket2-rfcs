#lang rhombus/scribble/manual
@(import:
    "common.rhm" open)

@(def macro_eval = make_rhombus_eval())

@title(~tag: "bind-macro"){Binding and Annotation Macros}

Macros can extend binding-position syntax, too, via
@rhombus(bind.macro). In the simplest case, a binding operator is implemented
by expanding to other binding operators, like this definition of @rhombus($$$)
as a prefix operator to constrain a pattern to number inputs:

@examples(
  ~eval: macro_eval
  ~defn:
    import:
      rhombus/meta open

    bind.macro '$$$ $n':
      '$n :: Number'
  ~repl:
    def $$$salary = 100.0

    salary
)

More expressive binding operators can use a lower-level protocol where a
binding is represented by transformers that generate checking and
binding code. It gets complicated, and it’s tied up with the propagation
of static information, so the details are in @secref("bind-macro-protocol").
After an expressive set of binding forms are implemented with the
low-level interface, however, many others can be implemented though
simple expansion.

The @rhombus(annot.macro) form is similar to @rhombus(bind.macro), but for
annotations.

@rhombusblock(
  use_static

  annot.macro 'PosnList': 'List.of(Posn)'

  fun nth_x(ps :~ PosnList, n):
    ps[n].x
)

For details on the low-level annotation protocol, see @secref("annotation-macro").


@(close_eval(macro_eval))
