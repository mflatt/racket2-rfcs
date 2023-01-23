#lang scribble/rhombus/manual
@(import:
    "common.rhm" open
    "macro.rhm")

@(def macro_eval: macro.make_macro_eval())

@title{Definition Macros}

@doc(
  space.transform defn
){

  Alias for the @rhombus(expr, ~space) @tech{space}.

}

@doc(
  defn.macro '«defn.macro '$defined_name $pattern ...':
                 $option; ...
                 $body
                 ...»'

  grammar defined_name:
    $identifier
    ($identifier_path)
  grammar option:
    ~op_stx: $identifier
){

 Defines @rhombus(identifier) or @rhombus(identifier_path) as a macro
 that can be used in a definition context, where the compile-time
 @rhombus(body) block returns the expansion result. The macro pattern is
 matched to an entire group in a definition context.

 The expansion result must be a parenthesized block, and the groups of
 the block are inlined in place of the definition-macro use.

 The @rhombus(option)s in the macro body must be distinct; since there
 is only one option currently, either the @rhombus(~op_stx) option is
 present or not. The @rhombus(~op_stx) option, if present, binds an
 identifier for a use of the macro (which cannot be matched directly in
 the @rhombus(pattern), since that position is used for the name
 that @rhombus(defn.macro) binds).

 See @secref("namespaces") for information about
 @rhombus(identifier_path).

@examples(
  ~eval: macro_eval
  defn.macro 'enum:
                $(id :: Group)
                ...':
    def [n, ...]: List.iota([id, ...].length())
    'def $id: $n
     ...'
  enum:
    a
    b
    c
  b
)

}

@doc(
  defn.macro '«defn.sequence_macro '$defined_name $pattern ...
                                    $pattern
                                    ...':
                 $option; ...
                 $body
                 ...»'
  grammar defined_name:
    $identifier
    $operator
    ($identifier_path)    
    ($operator_path)
  grammar option:
    ~op_stx: $identifier
){

 Similar to @rhombus(defn.macro), but defines a macro for a definition
 context that is matched against all of the remiaining groups in the
 context, so the pattern is a multi-group pattern.

 The macro result is two values: a sequence of groups to
 splice in place of the sequence-macro use, and a sequence of
 groups that represent the tail of the definition context that was not consumed.

 See @secref("namespaces") for information about
 @rhombus(identifier_path) and @rhombus(operator_path).

@examples(
  ~eval: macro_eval
  defn.sequence_macro 'reverse_defns
                       $defn1
                       $defn2
                       $tail
                       ...':
    values('$defn2; $defn1', '$tail; ...')
  :
    reverse_defns
    def seq_x: seq_y+1
    def seq_y: 10
    seq_x
)
}

@«macro.close_eval»(macro_eval)
