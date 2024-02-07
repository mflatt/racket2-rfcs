#lang scribble/rhombus/manual

@(import:
    meta_label:
      rhombus open
      pict open
      draw)

@title(~tag: "find"){Pict Finders}

@doc(
  annot.macro 'Find'
){

 Satisfied by a @deftech{finder}, which is applied to a pict to obtain
 two numbers representing an x-offset and y-offset.

}

@doc(
  fun Find(
    pict :: Pict,
    ~horiz: horiz :: HorizAlignment = #'center,
    ~vert: vert :: VertAlignment = #'center,
    ~dx: dx :: Real = 0,
    ~dy: dy :: Real = 0
  ) :: Find
){

 Creates a @tech{finder} that locates the coresponding position of
 @rhombus(pict) within another @tech{pict}.

}

@doc(
  fun Find.abs(~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
){

 Creates a @tech{finder} that always returns @rhombus(dx) and
 @rhombus(dy) without needing to locate any particular component
 @tech{pict}.

}


@doc(
  method (finder :: Find).in(pict :: Pict) :: values(Real, Real)
){

 Applies @rhombus(finder) to @rhombus(pict). An exception is thrown is a
 needed component pict cannot be found in @rhombus(pict).

 If @rhombus(pict) is an animated picture, then the search corresponds
 to finding within @rhombus(Pict.snapshot(pict)).

}


@doc(
  fun Find.center(pict :: Pict,
                  ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.left(pict :: Pict,
                ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.right(pict :: Pict,
                 ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.top(pict :: Pict,
               ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.topline(pict :: Pict,
                   ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.baseline(pict :: Pict,
                    ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.bottom(pict :: Pict,
                  ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.left_top(pict :: Pict,
                    ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.left_topline(pict :: Pict,
                        ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.left_center(pict :: Pict,
                       ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.left_baseline(pict :: Pict,
                         ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.left_bottom(pict :: Pict,
                       ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.center_top(pict :: Pict,
                      ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.center_topline(pict :: Pict,
                          ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.center_center(pict :: Pict,
                         ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.center_baseline(pict :: Pict,
                           ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.center_bottom(pict :: Pict,
                         ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.right_top(pict :: Pict,
                     ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.right_topline(pict :: Pict,
                         ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.right_center(pict :: Pict,
                        ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.right_baseline(pict :: Pict,
                          ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.right_bottom(pict :: Pict,
                        ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.top_left(pict :: Pict,
                    ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.top_center(pict :: Pict,
                      ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.top_right(pict :: Pict,
                     ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.topline_left(pict :: Pict,
                        ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.topline_center(pict :: Pict,
                          ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.center_left(pict :: Pict,
                       ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.center_right(pict :: Pict,
                        ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.baseline_left(pict :: Pict,
                         ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.baseline_center(pict :: Pict,
                           ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.baseline_right(pict :: Pict,
                          ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.bottom(pict :: Pict,
                  ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.bottom_left(pict :: Pict,
                       ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.bottom_center(pict :: Pict,
                         ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
  fun Find.bottom_right(pict :: Pict,
                        ~dx: dx :: Real = 0, -dy: dy :: Real = 0) :: Find
){

 Shorthands for @rhombus(Find) at all combinations of @rhombus(~horiz)
 and @rhombus(~vert) arguments in all orders.

}
