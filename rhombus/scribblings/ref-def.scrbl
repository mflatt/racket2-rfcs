#lang scribble/rhombus/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open)

@title{Definitions}

@doc(
  defn.macro 'def $bind = $expr'
  defn.macro 'def $bind:
                $body
                ...'
){

 Binds the identifiers of @rhombus(bind) to the value of @rhombus(expr) or the
 @rhombus(body) sequence. The @rhombus(body) itself can include
 definitions, and it normally ends with an expression to provide the
 result value.

 A @rhombus(bind) can be just an identifier or @rhombus(id_name), or it
 can be constructed with a binding operator, such as a pattern form or
 @rhombus(::) for annotations.

 An identifier is bound in the @rhombus(expr, ~space) @tech{space}, and most
 binding operators also create bindings in the @rhombus(expr, ~space) space.

@examples(
  ~repl:
    def pi = 3.14
    pi
  ~repl:
    def pi:
      def tau = 6.28
      tau/2
    pi
  ~repl:
    def [x, y, z] = [1+2, 3+4, 5+6]
    y
  ~repl:
    def ns :: List = [1+2, 3+4, 5+6]
    ns
)

}


@doc(
  defn.macro 'let $bind = $expr'
  defn.macro 'let $bind:
                $body
                ...'
){

 Like @rhombus(def), but for bindings that become visible only after the
 @rhombus(let) form within its definition context. The @rhombus(let) form
 cannot be used in a top-level context outside of a module or local block.

@examples(
  block:
    let v = 1
    fun get_v(): v
    let v = v+1
    [get_v(), v]
)

}


@doc(
  bind.macro '$id_name . $id'
){

 The @rhombus(., ~bind) operator works somewhat like a binding operator
 that works only with identifiers, and it specifies a namespace-prefixed
 identifier to bind as an extension of an already-defined namespace. More
 precisely, @litchar{.} to join identifiers in a binding position is
 recognized literally as an operator, along the same lines as @litchar{.}
 used to reference a binding within a namespace or import.

 See @secref("namespaces") for more information about extending
 namespaces.

@examples(
  namespace geometry:
    export: pi
    def pi: 3.14
  def geometry.tau: 2 * geometry.pi
  geometry.tau
)

}
