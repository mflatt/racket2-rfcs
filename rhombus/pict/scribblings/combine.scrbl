#lang scribble/rhombus/manual

@(import:
    meta_label:
      rhombus open
      pict open
      draw)

@title(~tag: "combine"){Pict Combiners}

@doc(
  fun beside(
    ~sep: sep :: Real = 0,
    ~vert: vert_align :: VertAlignment = #'center,
    ~duration: duration_align :: DurationAlignment = #'sustain,
    ~epoch: epoch_align :: EpochAlignment = #'center,
    pict :: Pict, ...
  ) :: Pict
){

 Creates a pict that combines the given @rhombus(pict)s horizontally.

 The picts are first made concurrent via @rhombus(concurrent), passing
 along @rhombus(duration_align) and @rhombus(epoch_align).

 If no @rhombus(pict)s are provided, the result is @rhombus(nothing).

}

@doc(
  fun stack(
    ~sep: sep :: Real = 0,
    ~horiz: horiz_alig :: HorizAlignment = #'center,
    ~duration: duration_align :: DurationAlignment = #'sustain,
    ~epoch: epoch_align :: EpochAlignment = #'center,
    pict :: Pict, ...
  ) :: Pict
){

 Creates a pict that combines the given @rhombus(pict)s vertically.

 The picts are first made concurrent via @rhombus(concurrent), passing
 along @rhombus(duration_align) and @rhombus(epoch_align).

 If no @rhombus(pict)s are provided, the result is @rhombus(nothing).

}

@doc(
  fun overlay(
    ~horiz: horiz_align :: HorizAlignment = #'center,
    ~vert: vert_align :: VertAlignment = #'center,
    ~duration: duration_align :: DurationAlignment = #'sustain,
    ~epoch: epoch_align :: EpochAlignment = #'center,
    pict :: Pict, ...
  ) :: Pict
){

 Creates a pict that combines the given @rhombus(pict)s.

 The picts are first made concurrent via @rhombus(concurrent), passing
 along @rhombus(duration_align) and @rhombus(epoch_align).

 If no @rhombus(pict)s are provided, the result is @rhombus(nothing).

}

@doc(
  fun pin(
    pict :: Pict,
    ~on: on_pict :: Pict,
    ~at: finder :: Find,
    ~order: order :: matching(#'front || #'back) = #'front,
    ~duration: duration_align :: DurationAlignment = #'sustain,
    ~epoch: epoch_align :: EpochAlignment = #'center
  ) :: Pict
){

 Returns a @tech{pict} that draws @rhombus(pict) in front of or behind
 @rhombus(on_pict) at the location in @rhombus(on_pict) determined by
 @rhombus(finder).

 The picts are first made concurrent via @rhombus(concurrent), passing
 along @rhombus(duration_align) and @rhombus(epoch_align).

}

@doc(
  fun connect(
    on_pict :: Pict,
    from :: Find,
    to :: Find,
    ~style: style :: matching(#'line || #'arrow || #'arrows) = #'line,
    ~line: color :: Color || String || matching(#'inherit) = #'inherit,
    ~line_width: width :: Real || matching(#'inherit) = #'inherit,
    ~order: order :: matching(#'front || #'back) = #'front,
    ~arrow_size: arrow_size :: Real = 16,
    ~arrow_solid: solid = #true,
    ~arrow_hidden: hidden = #false,
    ~start_angle: start_angle :: maybe(Real) = #false,
    ~start_pull: start_pull :: maybe(Real) = #false,
    ~end_angle: end_angle :: maybe(Real) = #false,
    ~end_pull: end_pull :: maybe(Real) = #false,
    ~label: label :: maybe(Pict) = #false,
    ~label_dx: label_dx :: Real = 0,
    ~label_dy: label_dy :: Real = 0,
    ~duration: duration_align :: DurationAlignment = #'sustain,
    ~epoch: epoch_align :: EpochAlignment = #'center
  ) :: Pict
){

 Returns a @tech{pict} like @rhombus(on_pict), but with a line added to
 connect @rhombus(from) to @rhombus(to).

}

@doc(
  fun table(
    rows :: List.of(List),
    ~horiz: horiz :: HorizAlignment || List.of(HorizAlignment) = #'left,
    ~vert: vert :: VertAlignment || List.of(VertAlignment) = #'topline,
    ~hsep: hsep :: Real || List.of(Real) = 32,
    ~vsep: vsep :: Real || List.of(Real) = 1,
    ~pad: pad :: matching((_ :: Real)
                            || [_ :: Real, _ :: Real]
                            || [_ :: Real, _ :: Real, _ :: Real, _ :: Real])
            = 0,
    ~line: line_c :: maybe(String || Color || matching(#'inherit)) = #false,
    ~line_width: line_width :: Real || matching(#'inherit) = #'inherit,
    ~hline: hline :: maybe(String || Color || matching(#'inherit)) = line_c,
    ~hline_width: hline_width :: Real || matching(#'inherit) = line_width,
    ~vline: vline :: maybe(String || Color || matching(#'inherit)) = line_c,
    ~vline_width: vline_width :: Real || matching(#'inherit) = line_width
  ) :: Pict
){

 Creates a table @tech{pict}.

}


@doc(
  fun switch(
    ~splice: splice :: maybe(matching(#'before || #'after)) = #false,
    ~join: join :: SequentialJoin = if splice | #'splice | #'step,
    pict :: Pict, ...
  ) :: Pict
){

 Creates a pict that has the total duration of the given
 @rhombus(pict)s, where the resulting pict switches from one pict at the
 end of its time box to the next. The result pict's rendering before its
 timebox is the same as the first @rhombus(pict), and its rendering after
 is the same as the last @rhombus(pict).

 If no @rhombus(pict)s are provided, the result is @rhombus(nothing).

}

@doc(
  fun concurrent(
    ~duration: duration_align :: DurationAlignment = #'pad,
    ~epoch: epoch_align :: EpochAlignment = #'center,
    pict :: Pict, ...
  ) :: List.of(Pict)
){

 Returns a list of @tech{picts} like the given @rhombus(pict)s, except that time
 boxes and epochs of each are extended to match, including the same
 extent for each epoch in the time box.

 If @rhombus(duration_align) is @rhombus(#'pad), the time boxes are
 extended as needed in the ``after'' direction using @rhombus(Pict.pad).
 If @rhombus(duration_align) is @rhombus(#'sustain), then
 @rhombus(Pict.sustain) is used. Note that the default for
 @rhombus(duration_align) is @rhombus(#'pad), but when
 @rhombus(concurrent) is called by functions like @rhombus(beside), the
 defult is @rhombus(#'sustain).

 The @rhombus(epoch_align) argument determines how animations are
 positioned within an extent when extents are made larger to synchronize
 with concurrent, non-@rhombus(0) extents.

 Any @rhombus(nothing) among the @rhombus(pict)s is preserved in the
 output list, but it does not otherwise particiapte in making the other
 @rhombus(pict)s concurrent.

}


@doc(
  fun sequential(
    ~join: mode :: SequentialJoin = #'step,
    ~duration: duration_align :: DurationAlignment = #'pad,
    ~concurrent: to_concurrent = #true,
    pict :: Pict, ...
  ) :: List.of(AnimPict)
){

 Returns a list of @tech{picts} like the given @rhombus(pict)s, except
 the time box of each is padded in the ``before'' direction to
 sequentialize the picts.

 If @rhombus(to_concurrent) is true, then after the picts are
 sequentialized, they are passed to @rhombus(#'concurrent). The
 @rhombus(duration_align) argument is passed along in that case.

 Any @rhombus(nothing) among the @rhombus(pict)s is preserved in the
 output list, but it does not otherwise particiapte in making the other
 @rhombus(pict)s sequential.

}

@doc(
  fun animate_map(
    picts :~ List.of(Pict),
    ~combine: combine :: Function.of_arity(1),
    ~duration: duration_align :: DurationAlignment = #'sustain,
    ~epoch: epoch_align :: EpochAlignment = #'center,
    ~non_sustain_combine: non_sustain_combine :: Function.of_arity(1) = combine
  ) :: Pict
){

 Constructs a @tech{pict} by lifting an operation on @tech{static picts}
 to one on @tech{animated picts}. The @rhombus(combine) function is
 called as needed on a list of static picts corresponding to the input
 @rhombus(pict)s, and it should return a static pict.

 The picts are first made concurrent via @rhombus(concurrent), passing
 along @rhombus(duration_align) and @rhombus(epoch_align).

}

@doc(
  fun beside.top(~sep: sep :: Real = 0, pict :: Pict, ...) :: Pict
  fun beside.topline(~sep: sep :: Real = 0, pict :: Pict, ...) :: Pict
  fun beside.center(~sep: sep :: Real = 0, pict :: Pict, ...) :: Pict
  fun beside.baseline(~sep: sep :: Real = 0, pict :: Pict, ...) :: Pict
  fun beside.bottom(~sep: sep :: Real = 0, pict :: Pict, ...) :: Pict
){

 Shorthands for @rhombus(beside)  with a @rhombus(~vert) argument.

}

@doc(
  fun stack.center(~sep: sep :: Real = 0, pict :: Pict, ...) :: Pict
  fun stack.left(~sep: sep :: Real = 0, pict :: Pict, ...) :: Pict
  fun stack.right(~sep: sep :: Real = 0, pict :: Pict, ...) :: Pict
){

 Shorthands for @rhombus(stack)  with a @rhombus(~horiz) argument.

}

@doc(
  fun overlay.center(pict :: Pict, ...) :: Pict
  fun overlay.left(pict :: Pict, ...) :: Pict
  fun overlay.right(pict :: Pict, ...) :: Pict
  fun overlay.top(pict :: Pict, ...) :: Pict
  fun overlay.topline(pict :: Pict, ...) :: Pict
  fun overlay.baseline(pict :: Pict, ...) :: Pict
  fun overlay.bottom(pict :: Pict, ...) :: Pict
  fun overlay.left_top(pict :: Pict, ...) :: Pict
  fun overlay.left_topline(pict :: Pict, ...) :: Pict
  fun overlay.left_center(pict :: Pict, ...) :: Pict
  fun overlay.left_baseline(pict :: Pict, ...) :: Pict
  fun overlay.left_bottom(pict :: Pict, ...) :: Pict
  fun overlay.center_top(pict :: Pict, ...) :: Pict
  fun overlay.center_topline(pict :: Pict, ...) :: Pict
  fun overlay.center_center(pict :: Pict, ...) :: Pict
  fun overlay.center_baseline(pict :: Pict, ...) :: Pict
  fun overlay.center_bottom(pict :: Pict, ...) :: Pict
  fun overlay.right_top(pict :: Pict, ...) :: Pict
  fun overlay.right_topline(pict :: Pict, ...) :: Pict
  fun overlay.right_center(pict :: Pict, ...) :: Pict
  fun overlay.right_baseline(pict :: Pict, ...) :: Pict
  fun overlay.right_bottom(pict :: Pict, ...) :: Pict
  fun overlay.top_left(pict :: Pict, ...) :: Pict
  fun overlay.top_center(pict :: Pict, ...) :: Pict
  fun overlay.top_right(pict :: Pict, ...) :: Pict
  fun overlay.topline_left(pict :: Pict, ...) :: Pict
  fun overlay.topline_center(pict :: Pict, ...) :: Pict
  fun overlay.center_left(pict :: Pict, ...) :: Pict
  fun overlay.center_right(pict :: Pict, ...) :: Pict
  fun overlay.baseline_left(pict :: Pict, ...) :: Pict
  fun overlay.baseline_center(pict :: Pict, ...) :: Pict
  fun overlay.baseline_right(pict :: Pict, ...) :: Pict
  fun overlay.bottom(pict :: Pict, ...) :: Pict
  fun overlay.bottom_left(pict :: Pict, ...) :: Pict
  fun overlay.bottom_center(pict :: Pict, ...) :: Pict
  fun overlay.bottom_right(pict :: Pict, ...) :: Pict
){

 Shorthands for @rhombus(overlay) at all combinations of @rhombus(~horiz)
 and @rhombus(~vert) arguments in all orders.

}

@doc(
  annot.macro 'HorizAlignment'
){

 Recognizes an option for horizontal alignment, which is either
 @rhombus(#'left), @rhombus(#'center), or @rhombus(#'right).

}

@doc(
  annot.macro 'VertAlignment'
){

 Recognizes an option for vertical alignment, which is either
 @rhombus(#'top), @rhombus(#'topline), @rhombus(#'center),
 @rhombus(#'baseline), or @rhombus(#'bottom).

}

@doc(
  annot.macro 'DurationAlignment'
){

 Recognizes an option for duration alignment, which is either
 @rhombus(#'sustain) or @rhombus(#'pad).

}

@doc(
  annot.macro 'EpochAlignment'
){

 Recognizes an option for epoch alignment, which is either
 @rhombus(#'early), @rhombus(#'center), @rhombus(#'stretch), or
 @rhombus(#'late).

}

@doc(
  annot.macro 'SequentialJoin'
){

 Recognizes an option for seqntialu joining, which is either
 @rhombus(#'step) or @rhombus(#'splice).

}
