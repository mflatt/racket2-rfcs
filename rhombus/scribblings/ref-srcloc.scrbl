#lang scribble/rhombus/manual
@(import: "common.rhm" open)

@title{Source Locations}

@dispatch_table(
  "source location"
  @rhombus(Srcloc)
  [srcloc.source, Srcloc.source(srcloc)]
  [srcloc.line, Srcloc.line(srcloc)]
  [srcloc.column, Srcloc.column(srcloc)]
  [srcloc.position, Srcloc.position(srcloc)]
  [srcloc.span, Srcloc.span(srcloc)]
)

@doc(
  annot.macro 'Srcloc'
){

 Matches a source location value.
}

@doc(
  fun Srcloc(source,
             line :: maybe(PosInt),
             column :: maybe(NonnegInt),
             position :: maybe(PosInt),
             span :: maybe(NonnegInt))
    :: Srcloc
){

 Constructs a source location.

}

@doc(
  bind.macro 'Srcloc($source_binding,
                     $line_binding,
                     $column_binding,
                     $position_binding,
                     $span_binding)'
){

 Matches a source location where the components match the corresponding binding forms.

}

@doc(
  fun Srcloc.source(srcloc :: Srcloc)
  fun Srcloc.line(srcloc :: Srcloc) :: maybe(PosInt)
  fun Srcloc.column(srcloc :: Srcloc) :: maybe(NonnegInt)
  fun Srcloc.position(srcloc :: Srcloc) :: maybe(PosInt)
  fun Srcloc.span(srcloc :: Srcloc) :: maybe(NonnegInt)
){

 Extracts a component of a source location.

}
