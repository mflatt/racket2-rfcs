#lang scribble/rhombus/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm":
      open
      except: defn expr
    "macro.rhm")

@(def macro_eval: macro.make_macro_eval())

@title{Declaration Macros}

@doc(
  space.transform decl
){

  Alias for the @rhombus(expr, ~space) @tech{space}.

}

@doc(
  ~nonterminal:
    prefix_macro_patterns: defn.macro
  defn.macro 'decl.macro $prefix_macro_patterns'
){

 Like @rhombus(defn.macro, ~expr) but for defining a macro that can be used
 only in a module or interactive position --- the same places where
 @rhombus(meta) and @rhombus(module) are allowed, for example.

 See also @rhombus(expr.merge).

}

@doc(
  ~nonterminal:
    prefix_macro_patterns: defn.macro
  defn.macro 'decl.nestable_macro $prefix_macro_patterns'
){

 Like @rhombus(defn.macro, ~expr), but for forms that can also be used in
 namespaces that are witin a module or interactive position --- the same
 places where @rhombus(export) is allowed, for example.

 See also @rhombus(expr.merge).

}

@doc(
  syntax_class decl_meta.Group:
    kind: ~group
  syntax_class decl_meta.NestableGroup:
    kind: ~group
){

 @provided_meta()

 Like @rhombus(defn_meta.Group, ~stxclass), but for declarations and
 nestable declarations. The @rhombus(decl_meta.Group, ~stxclass) syntax
 class matches all groups that
 @rhombus(decl_meta.NestableGroup, ~stxclass) matches, plus ones that
 cannot be nested.

}


@doc(
  fun decl_meta.pack_s_exp(tree) :: Syntax
){

@provided_meta()

 Similar to @rhombus(expr_meta.pack_s_exp), but for declarations.


}


@«macro.close_eval»(macro_eval)
