#lang scribble/rhombus/manual
@(import:
    "common.rhm" open
    "macro.rhm")

@(def macro_eval: macro.make_macro_eval())

@(def dollar: @rhombus($))

@title{Syntax Pattern Binding Macros}

@doc(
  defn.macro 'syntax_pattern_binding.macro $rule_pattern:
                $option; ...
                $body
                ...'
  defn.macro 'syntax_pattern_binding.macro
              | $rule_pattern:
                  $option; ...
                  $body
                  ...
              | ...'
){

 Like @rhombus(expr.macro), but for binding an operator that works
 within a @rhombus($, ~bind) escape for a syntax pattern.

@examples(
  ~eval: macro_eval
  syntax_pattern_binding.macro 'dots':
    '«'$('...')'»'
  match Syntax.make_group(['...', '...', '...'])
  | '$dots ...': "all dots"
)

}

@«macro.close_eval»(macro_eval)
