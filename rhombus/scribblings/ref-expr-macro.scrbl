#lang scribble/rhombus/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm":
      open
      except: expr
    "macro.rhm")

@(def macro_eval: macro.make_macro_eval())

@(def macro_meta_eval: make_rhombus_eval())
@examples(
  ~eval: macro_meta_eval
  ~hidden:
    import: meta -1: rhombus/meta open
)

@(def dollar: @rhombus($))

@title{Expression Macros}

@doc(
  space.enforest expr
){

 The @tech{space} for bindings of identifiers and operators that can be
 used in expression, definition, and declaration positions.

}


@doc(
  def expr_meta.space :: SpaceMeta
){

@provided_meta()

 A compile-time value that identifies the same space as
 @rhombus(expr, ~space). See also @rhombus(SpaceMeta, ~annot).

}


@doc(
  ~nonterminal:
    macro_pattern: macro
    option: macro

  defn.macro 'expr.macro $macro_patterns'

  grammar macro_patterns:
    $macro_case
    Z| $macro_case
     | ...
    $op_or_id_name:
      $option; ...
      match
      | $macro_case
      | ...

  grammar macro_case:
    $macro_pattern:
      $option; ...
      $body
      ...
){

 Like @rhombus(macro), but arbitrary compile-time code can appear in the
 body after each @rhombus(macro_pattern).

 If a @rhombus(macro_pattern) ends with
 @rhombus(#,(@rhombus($, ~bind))()) or
 @rhombus(#,(@rhombus($, ~bind))#,(@rhombus(id, ~var)) #,(@rhombus(..., ~bind))), then a match
 covers all subsequent terms in the enclosing group of a use of the
 macro. In that case, the @rhombus(body) after the pattern can return two
 values: an expansion for the consumed part of the input match, and a
 tail for the unconsumed part. Returning a single value is the same as
 return an empty tail.

 The @rhombus(expr.macro) form does not define an @tech{assignment operator}
 that works with mutable targets. To define an assignment operator, use
 @rhombus(assign.macro), instead.

}


@doc(
  syntax_class expr_meta.Parsed:
    kind: ~group
    field group
  syntax_class expr_meta.AfterPrefixParsed(op_name):
    kind: ~group
    field group
    field [tail, ...]
  syntax_class expr_meta.AfterInfixParsed(op_name):
    kind: ~group
    field group
    field [tail, ...]
){

@provided_meta()

 Syntax classes that match by parsing expressions. The value of the
 binding in each case is an opaque syntax object that represents the @tech{parsed}
 expression form, while the @rhombus(group) field holds a syntax object
 for the original terms that were parsed.

 The @rhombus(expr_meta.AfterPrefixParsed, ~stxclass) and
 @rhombus(expr_meta.AfterInfixParsed, ~stxclass) syntax classes expect an operator
 name that is bound as a prefix or infix operator, respectively. Parsing
 procedes as if immediately after the given operator---stopping when an
 infix operator of weaker precencence is encountered, for example. The
 result is in pattern variable's value plus a @rhombus(tail) field
 that contains the remaining unparsed input.

@examples(
  ~eval: macro_eval
  ~defn:
    :
      // an infix `no_fail` that works without a right-hand side
      // expression, and that has weak precendence
      expr.macro
      | '$left no_fail $()':
          ~weaker_than: ~other
          'try: $left; ~catch _: #false'
      | '$left no_fail $(right :: expr_meta.AfterInfixParsed('no_fail')) $()':
           values('try: $left; ~catch _: $right', '$right.tail ...')
  ~repl:
    1/0 no_fail
    1/0 no_fail 0
    1/0 no_fail 0 + 1
    1+0 no_fail 0 + 1
    (1+0 no_fail 0) + 1
)

}


@doc(
  fun expr_meta.pack_expr(group :: Syntax) :: Syntax
){

@provided_meta()

 Converts a syntax object, which can be a multi-term syntax object, into
 an @tech{parsed} term, but one that represents an expression with
 delayed parsing. The function is intended for use in combination with
 @rhombus(expr_meta.pack_s_exp).

@examples(
  ~eval: macro_meta_eval
  expr_meta.pack_expr('x + 1')
)

}


@doc(
  fun expr_meta.pack_s_exp(tree) :: Syntax
){

@provided_meta()

 Converts a tree of terms, which can include @tech{parsed} terms, into a
 new parsed term representing a Racket parenthesized form. The intent is
 that the result is a Racket form to be used in a Rhombus context.

 A ``tree'' is a syntax object or a list of trees (i.e., syntax objects
 and arbitrary nestings of them within lists). Each syntax object must
 contain a single term.

 Any @tech{parsed} form as a leaf of @rhombus(tree) is exposed directly
 in the parenthesized sequence, which enables the construction of parsed
 terms that combine other parsed terms.

@examples(
  ~eval: macro_meta_eval
  expr_meta.pack_s_exp(['lambda', ['x'], 'x'])
  expr_meta.pack_s_exp(['lambda', ['x'], expr_meta.pack_expr('x + 1')])
)

}


@«macro.close_eval»(macro_eval)
