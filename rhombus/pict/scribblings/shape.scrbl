#lang scribble/rhombus/manual

@(import:
    "timeline.rhm".pict_eval
    meta_label:
      rhombus open
      pict open
      draw)

@title(~tag: "shape"){Pict Constructors}

@doc(
  fun blank(
    size :: Real = 0,
    ~width: width :: Real = size,
    ~height: height :: Real = size,
    ~ascent: ascent :: Real = height,
    ~descent: descent :: Real = 0
  ) :: StaticPict
){

 Creates a blank @tech{static pict} with the specified bounding box.

@(block:
    let width = "shadow arg"
    @examples(
      ~eval: pict_eval
      blank(10).width
    ))

}

@doc(
  fun rectangle(
    ~around: around :: maybe(Pict) = #false,
    ~width: width :: Real || Pict = around || 32,
    ~height: height :: Real || Pict = around || width,
    ~line: line :: maybe(Color || String || matching(#'inherit)) = #'inherit,
    ~fill: fill :: maybe(Color || String || matching(#'inherit)) = #false,
    ~line_width: line_width :: Real || matching(#'inherit) = #'inherit,
    ~rounded: rounded :: maybe(Real || matching(#'default)) = #false,
    ~order: order :: OverlayOrder = #'back,
    ~refocus: refocus_on :: maybe(Pict || matching(#'around)) = #'around,
    ~epoch: epoch_align :: EpochAlignment = #'center,
    ~duration: duration_align :: DurationAlignment = #'sustain
  ) :: Pict
){

 Creates a @tech{pict} to draw a rectangle. The rectangle's
 @rhombus(width) and @rhombus(height) can be supplied as numbers, or they
 can be supplied as a @tech{pict}, in which case the given picts' width
 and height are used, respectively. If an @rhombus(around) pict is
 provided, then it both supplies default @rhombus(width) and
 @rhombus(height) values an is @rhombus(overlay)ed on top of the rectangle
 image,

 The rectangle has an outline if @rhombus(line) is not @rhombus(#false),
 and it is filled in if @rhombus(fill) is not @rhombus(#false). If the
 rectangle has an outline, @rhombus(line_width) is used for the outline. A
 @rhombus(line), @rhombus(fill), or @rhombus(line_width) can be
 @rhombus(#'inherit) to indicate that a context-supplied color and line
 width should be used. See also @rhombus(Pict.colorize) and
 @rhombus(Pict.colorize) @rhombus(Pict.line_width).

 If @rhombus(rounded) is a non-negative number, it is used as the radius
 of an arc to use for the rectangle's corners. If @rhombus(rounded) is a
 negative number, it is negated and multipled by the rectangle's width
 and height to get a radius (in each direction) for the rounded corner.

 When the @rhombus(refocus_on) argument is a pict, then
 @rhombus(Pict.refocus) is used on the resulting pict with
 @rhombus(refocus_on) as the second argument. If @rhombus(refocus) is
 @rhombus(#'around) and @rhombus(around) is not @rhombus(#false), then the
 pict is refocused on @rhombus(around), and then padded if necessary to
 make the width and height match @rhombus(width) and @rhombus(height).

 The @rhombus(epoch_align) and @rhombus(duration_align) arguments are
 used only when @rhombus(around) is supplied, and they are passed on to
 @rhombus(overlay) to combine a static rectangle pict with
 @rhombus(around). The @rhombus(order) argument is similarly passed along to
 @rhombus(overlay). If @rhombus(around) is @rhombus(#false), the
 resulting pict is always a @tech{static pict}.

@examples(
  ~eval: pict_eval
  rectangle()
  rectangle(~fill: "lightblue", ~line: #false)
  rectangle(~line: "blue", ~rounded: #'default)
  rectangle(~around: text("Hello"), ~fill: "lightgreen")
)

}


@doc(
  fun square(
    ~around: around :: maybe(Pict) = #false,
    ~size: size :: Real || Pict = around || 32,
    ~line: line :: maybe(Color || String || matching(#'inherit)) = #'inherit,
    ~fill: fill :: maybe(Color || String || matching(#'inherit)) = #false,
    ~line_width: line_width :: Real || matching(#'inherit) = #'inherit,
    ~order: order :: OverlayOrder = #'back,
    ~refocus: refocus_on :: maybe(Pict || matching(#'around)) = #'around,
    ~epoch: epoch_align :: EpochAlignment = #'center,
    ~duration: duration_align :: DurationAlignment = #'sustain
  ) :: Pict
){

 A shorthand for @rhombus(rectangle) where the width and height are
 specified as @rhombus(size) or, if @rhombus(size) is a pict, as the
 maximum of the pict's width and height.

@examples(
  ~eval: pict_eval
  square(~around: text("Hello"), ~fill: "lightgreen")
)

}

@doc(
  fun ellipse(
    ~around: around :: maybe(Pict) = #false,
    ~width: width :: Real || Pict = around || 32,
    ~height: height :: Real || Pict = around || width,
    ~arc: arc :: maybe(matching(#'cw || #'ccw)) = #false,
    ~start: start :: Real = 0,
    ~end: end :: Real = 2 * math.pi,
    ~line: line :: maybe(Color || String || matching(#'inherit)) = #'inherit,
    ~fill: fill :: maybe(Color || String || matching(#'inherit)) = #false,
    ~line_width: line_width :: Real || matching(#'inherit) = #'inherit,
    ~rounded: rounded :: maybe(Real || matching(#'default)) = #false,
    ~order: order :: OverlayOrder = #'back,
    ~refocus: refocus_on :: maybe(Pict || matching(#'around)) = #'around,
    ~epoch: epoch_align :: EpochAlignment = #'center,
    ~duration: duration_align :: DurationAlignment = #'sustain
  ) :: Pict
){

 Like @rhombus(rectangle), but for an ellipse or arc/wedge. The pict
 draws an arc or widge if @rhombus(arc) is @rhombus(#'cw) (clockwise) or
 @rhombus(#'ccw) (counterclockwise).

@examples(
  ~eval: pict_eval
  ellipse(~around: text("Hello"), ~fill: "lightgreen")
)

}

@doc(
  fun circle(
    ~around: around :: maybe(Pict) = #false,
    ~size: size :: Real || Pict = around || 32,
    ~arc: arc :: maybe(matching(#'cw || #'ccw)) = #false,
    ~start: start :: Real = 0,
    ~end: end :: Real = 2 * math.pi,
    ~line: line :: maybe(Color || String || matching(#'inherit)) = #'inherit,
    ~fill: fill :: maybe(Color || String || matching(#'inherit)) = #false,
    ~line_width: line_width :: Real || matching(#'inherit) = #'inherit,
    ~rounded: rounded :: maybe(Real || matching(#'default)) = #false,
    ~order: order :: OverlayOrder = #'back,
    ~refocus: refocus_on :: maybe(Pict || matching(#'around)) = #'around,
    ~epoch: epoch_align :: EpochAlignment = #'center,
    ~duration: duration_align :: DurationAlignment = #'sustain
  ) :: Pict
){

 Like @rhombus(square), but a shorthand for @rhombus(ellipse).

@examples(
  ~eval: pict_eval
  circle(~around: text("Hello"), ~fill: "lightgreen")
)

}

@doc(
  fun polygon(
    [pt :: draw.PointLike.to_point, ...],
    ~line: line :: maybe(Color || String || matching(#'inherit)) = #'inherit,
    ~fill: fill :: maybe(Color || String || matching(#'inherit)) = #false,
    ~line_width: line_width :: Real || matching(#'inherit) = #'inherit
  ) :: Pict
){

 Creates a @tech{pict} that draws a polygon. The maximum x and y values
 among the @rhombus(pt)s determine the resulting pict's bounding box.

@examples(
  ~eval: pict_eval
  polygon([[0, 0], [50, 0], [50, 50]], ~fill: "lightgreen")
)

}

@doc(
  fun line(
    ~dx: dx :: Real = 0,
    ~dy: dy :: Real = 0,
    ~line: color :: Color || String || matching(#'inherit) = #'inherit,
    ~line_width: width :: Real || matching(#'inherit) = #'inherit
  ) :: Pict
){

 Creates a @tech{pict} that draws a line from the top-left of the pict.
 The @rhombus(dx) and @rhombus(dy) arguments determine both the shape of
 the line and the width and height of the pict.

@examples(
  ~eval: pict_eval
  line(~dx: 10, ~line_width: 3)
  line(~dy: 10, ~line: "blue", ~line_width: 3)
  line(~dx: 10, ~dy: 10)
)

}

@doc(
  fun text(content :: String,
           ~font: font :: draw.Font = draw.Font()) :: Pict
){

 Creates a @tech{pict} that draws text using @rhombus(font)

@examples(
  ~eval: pict_eval
  text("Hello")
  text("Hi!", ~font: draw.Font(~kind: #'roman, ~size: 20, ~style: #'italic))
)

}

@doc(
  fun bitmap(path :: Path || String) :: Pict
){

 Creates a @tech{pict} that draws a bitmap as loaded from @rhombus(path).

}

@doc(
  fun dc(draw :: Function.of_arity(3),
         ~width: width :: Real,
         ~height: height :: Real,
         ~ascent: ascent :: Real = height,
         ~descent: descent :: Real = 0) :: Pict
){

 Creates a @tech{pict} with an arbitrary drawing context. The
 @rhombus(draw) function receives a s @rhombus(draw.DC), an x-offset, and
 a y-offset.

@examples(
  ~eval: pict_eval
  dc(fun (dc :: draw.DC, dx, dy):
       dc.line([dx, dy+10], [dx+20, dy+10])
       dc.line([dx+10, dy], [dx+10, dy+20])
       dc.ellipse([[dx, dy], [21, 21]]),
     ~width: 20,
     ~height: 20)
)

}


@doc(
  fun animate(
    proc :: Function.of_arity(1),
    ~extent: extent :: NonnegReal = 0.5,
    ~bend: bend = bend.fast_middle,
    ~sustain_edge: sustain_edge :: matching(#'before || #'after) = #'before
  ) :: Pict
){

 Creates an @tech{animated pict}. The @rhombus(proc) should accept a
 @rhombus(Real.in(), ~annot) and produce a @rhombus(StaticPict, ~annot).

}

@doc(
  fun Pict.from_handle(handle) :: Pict
){

 Converts a static pict value compatible with the Racket
 @racketmodname(pict) library into a @rhombus(Pict, ~annot) value.

}
