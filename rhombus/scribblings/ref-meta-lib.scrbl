#lang scribble/rhombus/manual
@(import: "common.rhm" open)

@title(~style: #'toc){Meta and Macros Reference}

@docmodule(~use_sources: lib("rhombus/private/core-meta"),
           rhombus/meta)

@docmodule(~lang, ~no_declare, rhombus/and_meta)

Simple pattern-based expression macros can be written using
@rhombus(macro) without importing any additional libraries besides
@rhombusmodname(rhombus), but implementing others forms of macros requires
using the @rhombusmodname(rhombus/meta) module (usually with no prefix).

The @rhombusmodname(rhombus/meta) module provides bindings like
@rhombus(defn.macro), @rhombus(expr.macro), and @rhombus(bind.macro). It
it also re-exports most of @rhombusmodname(rhombus) as @rhombus(meta, ~impo)
for use in compile-time expressions, but it omits bindings from
@rhombusmodname(rhombus) that bridge to meta contexts: @rhombus(meta),
@rhombus(macro), @rhombus(binding, ~class_clause), etc. Explicitly
import @rhombusmodname(rhombus) as @rhombus(meta, ~impo) to access the
omitted bindings.

The @rhombusmodname(rhombus/and_meta) module provides all of the
bindings from both @rhombusmodname(rhombus) and
@rhombusmodname(rhombus/meta). It's intended for use as a language---an
alternative to starting with @rhombusmodname(rhombus) and importing
@rhombusmodname(rhombus/meta).

@local_table_of_contents()

@include_section("ref-meta.scrbl")
@include_section("ref-space.scrbl")
@include_section("ref-namespace-macro.scrbl")
@include_section("ref-defn-macro.scrbl")
@include_section("ref-decl-macro.scrbl")
@include_section("ref-expr-macro.scrbl")
@include_section("ref-assign-macro.scrbl")
@include_section("ref-bind-macro.scrbl")
@include_section("ref-annotation-macro.scrbl")
@include_section("ref-dot-provider.scrbl")
@include_section("ref-repet-macro.scrbl")
@include_section("ref-for-clause-macro.scrbl")
@include_section("ref-sequence-macro.scrbl")
@include_section("ref-class-clause-macro.scrbl")
@include_section("ref-static-info.scrbl")
@include_section("ref-unquote-bind-macro.scrbl")
@include_section("ref-stxobj-meta.scrbl")
