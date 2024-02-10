#lang scribble/rhombus/manual

@(import:
    meta_label:
      rhombus open
      pict open
      draw)

@title(~tag: "pict"){Picts}

@doc(
  annot.macro 'Pict'
  annot.macro 'StaticPict'
){

 An annotation representing a @tech{pict} value or a pict value that is
 specifically a @tech{static pict}.

}

@doc(
  def nothing :: NothingPict
  annot.macro 'NothingPict'
){

 The @rhombus(nothing) pict is a special @tech{static pict} that acts as
 if it is not supplied at all. The @rhombus(NothingPict, ~annot) annotation
 is satisfied by only @rhombus(nothing).

}

@doc(
  property (pict :: Pict).width :: Real
  property (pict :: Pict).height :: Real
  property (pict :: Pict).descent :: Real
  property (pict :: Pict).ascent :: Real
){

 Properties for a @tech{pict}'s geometry.

}

@doc(
  property (pict :: Pict).duration :: Int
  method (pict :: Pict).epoch_extent(i :: Int) :: Real
){

 Properties for a @tech{pict}'s animation.

}

@doc(
  method (pict :: Pict).snapshot() :: StaticPict
  method (pict :: Pict).snapshot(epoch :: Int, n :: Real.in(0, 1)) :: StaticPict
){

 Converts an @tech{animated pict} to a @tech{static pict}. The 0-argument
 variant is a shorthand for providing @rhombus(0) and @rhombus(0).

}

@doc(
  method (pict :: Pict).launder() :: Pict
){

 Returns a @tech{pict} that is the same as @rhombus(pict), but with a
 fresh identity and hiding the identity of any cmoponent inside
 @rhombus(pict).

}

@doc(
  method (pict :: Pict).ghost(do_ghost = #true) :: Pict
){

 Returns a @tech{pict} that is the same as @rhombus(pict), including the
 same @tech{bounding box} and @tech{time box}, but whose drawing is empty
 if @rhombus(do_ghost) is true. If @rhombus(do_ghost) is @rhombus(#false),
 then @rhombus(pict) itself is returned.

 The @rhombus(do_ghost) argument is intended to help avoid @rhombus(if)
 wrappers, enabling @rhombus(pict.ghost(@rhombus(test, ~var))) instead of
 @rhombus(if @rhombus(test, ~var) | pict.ghost() | pict), where the
 former works even without having to bind an intermediate variable if
 @rhombus(pict) is replaced with a more complex expression.

}

@doc(
  method (pict :: Pict).refocus(subpict :: Pict) :: Pict
){

 Returns a @tech{pict} that is the same as @rhombus(pict), but with a
 shifted @tech{bounding box} to match @rhombus(subpict) within
 @rhombus(pict).

}

@doc(
  method (pict :: Pict).pad(
    around :: Real = 0,
    ~horiz: horiz :: Real = around,
    ~vert: vert :: Real = around,
    ~left: left :: Real = horiz,
    ~top: top :: Real = vert,
    ~right: right :: Real = horiz,
    ~bottom: bottom :: Real = vert
  ) :: Pict
  method (pict :: Pict).translate(dx :: Real, dy :: Real) :: Pict
  method (pict :: Pict).lift(amt :: Real) :: Pict
  method (pict :: Pict).drop(amt :: Real) :: Pict
){

 Returns a @tech{pict} that is the same as @rhombus(pict), but with its
 @tech{bounding box} adjusted.

}

@doc(
  method (pict :: Pict).time_pad(
    ~all: all :: Int = 0,
    ~before: before :: Int = all,
    ~after: after :: Int = all
  ) :: Pict
){

 Returns a @tech{pict} that is the same as @rhombus(pict), but with its
 @tech{time box} adjusted.

}

@doc(
  method (pict :: Pict).sustain(n :: Int = 1) :: Pict
){

 Similar to @rhombus(Pict.time_pad) with @rhombus(~after), but
 @tech{sustains} instead of merely padding.

}

@doc(
  method (pict :: Pict).nonsustaining() :: Pict
){

 Returns a @tech{pict} that is the same as @rhombus(pict), but where a
 @tech{sustain} operation is treated the same as padding via
 @rhombus(Pict.time_pad).

}

@doc(
  method (pict :: Pict).scale(n :: Real) :: Pict
  method (pict :: Pict).scale(horiz :: Real, vert :: Real) :: Pict
){

 Returns a @tech{pict} that is like @rhombus(pict), but its drawing and
 bounding box is scaled.

}

@doc(
  method (pict :: Pict).rotate(radians :: Real) :: Pict
){

 Returns a @tech{pict} that is like @rhombus(pict), but its drawing is
 rotated, and its bounding box is extended as needed to enclose the
 rotated bounding box.

}

@doc(
  method (pict :: Pict).shear(x_factor :: Real, y_factor :: Real) :: Pict
){

 Returns a @tech{pict} that is like @rhombus(pict), but its drawing is
 sheared. The bounding box is inflated to contain the result. The
 result pict's ascent and descent are the same as @rhombus(pict)'s.

}

@doc(
  method (pict :: Pict).alpha(n :: Real.in(0, 1)) :: Pict
){

 Returns a @tech{pict} that is like @rhombus(pict), but whose drawing is
 changed by reducing the global alpha adjustment.

}

@doc(
  method (pict :: Pict).hflip() :: Pict
  method (pict :: Pict).vflip() :: Pict
){

 Flips a @tech{pict} horizontally or vertically.

}

@doc(
  method (pict :: Pict).clip() :: Pict
){

 Returns a @tech{pict} that is like @rhombus(pict), but whose drawing is
 confined to its bounding box.

}

@doc(
  method (pict :: Pict).freeze(~scale: scale :: Real = 2.0) :: Pict
){

 Returns a @tech{pict} that is like @rhombus(pict), but whose drawing is
 rendered at the time of the @rhombus(Pict.freeze) call to a bitmap, and
 then the new pict draws by drawing the bitmap. The @rhombus(scale)
 argument determines the scale factor of the bitmap (i.e., the number of
 pixels per drawing unit).

}

@doc(
  method (pict :: Pict).time_clip(
    ~keep: keep :: maybe(matching(#'before || #'after)) = #false,
    ~nonsustaining: nonsustaining = keep != #'after
  ) :: Pict
){

 Returns a @tech{pict} that is like @rhombus(pict), but whose drawing is
 confined to its time box in the sense that it is represented by
 @rhombus(nothing) outside of its time box. If @rhombus(keep) is
 @rhombus(#'before) or @rhombus(#'after), then the pict is not clipped in
 that time direction. The resulting pict is nonsustaining (in the sense
 of @rhombus(Pict.nonsustaining)) if @rhombus(nonsustaining) is true.

}

@doc(
  method (pict :: Pict).colorize(c :: (Color || String)) :: Pict
  method (pict :: Pict).line_width(w :: NonnegReal) :: Pict
){

 Returns a @tech{pict} that is like @rhombus(pict), but wherever it uses
 @rhombus(#'inherit) for a color or line width, the given color or line
 width is used, and the resulting pict no longer uses @rhombus(#'inherit)
 or colors or line widths.

}

@doc(
  method (pict :: Pict).epoch_set_extent(i :: Int,
                                         extent :: NonnegReal) :: Pict
){

 Returns a @tech{pict} that is like @rhombus(pict), but with the
 @tech{extent} of one of its @tech{epochs} adjusted.

}
