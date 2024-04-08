#lang scribble/rhombus/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open)

@title{Enumerations}

@doc(
  defn.macro 'enum $id_name:
                $enum_clause
                ...'
  grammar enum_clause:
    $id ...
    ~is_a: $annot; ...
    ~is_a $annot
){

 Defines @rhombus(id_name) as a @tech{predicate annotation} and as a
 namespace, where the namespace exports each @rhombus(id) as the symbol
 @rhombus(#'id) and as a binding form that matches the symbol
 @rhombus(#'id). The annotation is satisfied by each symbol
 @rhombus(#'id) and by values satisfying any of the @rhombus(annot)s
 specified with @rhombus(~is_a).

@examples(
  ~defn:
    enum Mouse:
      itchy
      mickey minnie
      jerry
  ~repl:
    Mouse.itchy
    #'itchy is_a Mouse
    #'scratchy is_a Mouse
    match #'jerry
    | Mouse.itchy: "scratchy"
    | Mouse.jerry: "tom"
  ~defn:
    enum Cat:
      ~is_a String
      scratchy
      tom
  ~repl:
    Cat.tom is_a Cat
    "Felix" is_a Cat
)

}
