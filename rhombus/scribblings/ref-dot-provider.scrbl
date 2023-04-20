#lang scribble/rhombus/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open
    "macro.rhm")

@title{Dot Providers}

@doc(
  space.transform dot
){

 The @tech{space} for bindings of identifiers as @tech{dot providers}.

}

@doc(
  ~nonterminal:
    prefix_macro_patterns: defn.macro
    defined_name: defn.macro

  defn.macro 'dot.macro $prefix_macro_patterns'

  grammar option:
    ~op_stx: $id
    ~is_static: $id
    ~tail: $id

){

 Similar to @rhombus(defn.macro, ~expr), but binds a @tech{dot provider} that
 is normally referenced indirectly via @tech{static information},
 instead of directly. The @rhombus(pattern) sequence after the leading
 @rhombus(defined_name) should match a sequence of three
 terms: a parsed left-hand expression, a @rhombus(.) term, and a
 right-hand identifier. The @rhombus(defined_name) is bound in the
 @rhombus(dot, ~space) @tech{space}.

 Two extra @rhombus(option)s are supported: @rhombus(~is_static) and
 @rhombus(~tail). Each of these declares an identifier that is bound to
 information about the context of the @rhombus(.) use. The identifier for
 @rhombus(~is_static) is bound to @rhombus(#true) or @rhombus(#false),
 depending on whether @rhombus(.) was a static or dynamic dot; see
 @rhombus(use_static). The identifier for @rhombus(~tail) is bound to a
 multi-term syntax object representing the tail of the enclosing group
 after the @rhombus(.) and subsequent identifier.

 The result must be either @rhombus(#false), a syntax object, or two
 syntax-object values. A @rhombus(#false) result means that static
 resolution failed, in which case the @rhombus(.) operator will generate
 a fallback lookup that is dynamic and generic---unless the @rhombus(.)
 operator is in static mode, in which case it will report a syntax error.
 A (first) syntax-object result provides an expression form (that normally
 includes the left-hand expression) to replace the @rhombus(.)
 expression. When a second syntax-object result is provided, it is used
 as the remainder of the enclosing group for further processing, and the
 default result is the same tail that would be provided for an identifier
 declared with the @rhombus(~tail) option.

}


@doc(
  ~nonterminal:
    option: dot.macro
  class_clause.macro 'dot_provider: $entry_point'
  class_clause.macro '«dot_provider '$pattern': $option; ...; $body; ...»',
  class_clause.macro '«dot_provider | '$pattern': $option; ...; $body; ...
                                    | ...»'
  interface_clause.macro 'dot_provider: $entry_point'
  interface_clause.macro '«dot_provider '$pattern': $option; ...; $body; ...»',
  interface_clause.macro '«dot_provider | '$pattern': $option; ...; $body; ...
                                        | ...»'
){

 Forms for @rhombus(class) or @rhombus(interface) to change the
 resolution of @rhombus(.) access for an expression that has the class's
 or interface's annotation.

 When a quoted @rhombus(pattern) is specified, then it should match a
 three-term sequence for a left-hand side, the @rhombus(.) operator, and
 a right-hand identifier. The @rhombus(option)s and result @rhombus(body)
 are as for @rhombus(dot.macro).

 When an @rhombus(entry_point) is provided, then the resulting function
 must accept two arguments: a three-term syntax object (like the one that
 would be matched to a @rhombus(pattern)) and a map for options. The
 map's keys are the keywords for @rhombus(option)s.

}
