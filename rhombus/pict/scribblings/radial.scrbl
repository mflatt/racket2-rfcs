#lang scribble/rhombus/manual

@(import:
    meta_label:
      rhombus open
      pict open:
        except:
          circle
          polygon
      pict/radial open)

@title(~tag: "radial"){Pict Radial Shapes}

@docmodule(pict/radial)

@doc(
  fun radial_pict(
    ~points: n :: PosInt = 6,
    ~width: width :: Real = 64,
    ~height: height :: Real = width,
    ~rotate: rotate :: Real = 0,
    ~angle_at: angle_at :: Function.of_arity(2) = evenly_spaced,
    ~inner_radius: inner :: Real = 0.5,
    ~outer_radius: outer :: Real = 1,
    ~inner_pause: inner_pause :: Real = 0,
    ~outer_pause: outer_pause :: Real = 0,
    ~flat_inner_edge: flat_inner_edge = #false,
    ~flat_outer_edge: flat_outer_edge = #false,
    ~outer_pull: outer_pull :: Real = 0,
    ~inner_pull: inner_pull :: Real = 0,
    ~line: line :: MaybeColor = #false,
    ~fill: fill :: MaybeColor = #'inherit,
    ~line_width: line_width :: LineWidth = #'inherit,
    ~bound: bound :: BoundingBoxMode = #'unit
  ) :: Pict
){

 A general function for creating shapes like stars, flowers, polygons
 and gears---shapes that have a radial symmetry involving ``points'' that
 extend to an outer radius from a smaller base radius. Functions like
 @rhombus(star), @rhombus(flower), and @rhombus(polygon) have the same
 arguments as @rhombus(radial), but with defaults that produce the shapes
 suggested by the names.

 Various arguments have expected ranges, but none of the ranges are
 enforced, and interesting images can be created by using values outside
 the normal ranges:

@centered(
  @tabular(~sep: @hspace(1),
           [[@rhombus(inner), @elem{@rhombus(0) to @rhombus(outer)}],
            [@rhombus(inner_pause), @elem{@rhombus(0) to @rhombus(1)}],
            [@rhombus(outer_pause), @elem{@rhombus(0) to @rhombus(1)}],
            [@rhombus(inner_pull), @elem{@rhombus(0) to @rhombus(1)}],
            [@rhombus(outer_pull), @elem{@rhombus(0) to @rhombus(1)}]])
)

 The result of @rhombus(radial) is squashed to ellipse form if
 @rhombus(height) is not the same as @rhombus(width). The
 @rhombus(rotate) argument determines an amount of rotation (in radians
 counter-clockwise) applied to the imagine before it is squashed. The
 bounding box for the resulting pict corresponds to a square around the
 original circle, and it is not affected by @rhombus(rotate). (It is
 affected by @rhombus(bound), however, as described further below.)

 Points radiating from the inner to outer radius are evenly spaced by
 default, but @rhombus(angle_at) is called for each point's index to get
 a location for each point, and it can choose a different spacing (e.g.,
 with some ``jitter'' from even spacing in the case of @rhombus(cloud)).

 The points extend from a base of radius @rhombus(inner) to an edge at
 radius @rhombus(outer). By default, the connection from a point at the
 inner radius to a point at outer radius uses up half the radial space
 allocated to the point. If @rhombus(inner_pause) is creater than
 @rhombus(0), it represents a fraction of half the space between points
 that stays at the inner radius before extending out. Similarly,
 @rhombus(outer_pause) is a fraction allocated to staying at the out
 radius. When staying at the inner or outer radius,
 @rhombus(flat_inner_edge) and @rhombus(flat_outer_edge) determine
 whether the start and end points are connected by a straight line or an
 arc at the radius.

 When the @rhombus(inner_pull) and @rhombus(outer_pull) arguments are
 @rhombus(0), then the inner and outer points are straight corners.
 Otherwise, they determine an amount of curvature. Each of
 @rhombus(outer_pull) and @rhombus(inner_pull) represent an amount of
 curvature touward a rounder ``petal.''

 The @rhombus(line), @rhombus(line_width), and @rhombus(fill) arguments
 are the same as for functions like @rhombus(rectangle).

 The @rhombus(bound) argument can be @rhombus(#'unit), @rhombus(#'unit),
 @rhombus(#'shrink), or @rhombus(#'stretch). The default,
 @rhombus(#'unit), gives the resulting pict a bounding box that
 corresponds to the outer radius of the image. If @rhombus(bound) is
 @rhombus(#'shrink), then the bounding box is instead one that encloses
 the inner and outer points of the figure, and so the resulting pict may
 have bounds smaller than @rhombus(width) and @rhombus(height). The
 @rhombus(#'stretch) mode is similar to @rhombus(#'shrink), but the pict
 is scaled and stretched to ensure that its bounding box has dimentions
 @rhombus(width) and @rhombus(height).

}

@doc(
  fun star(~points: n :: PosInt = 5, ....) :: Pict
  fun flash(~bumps: n :: PosInt = 10, ....) :: Pict
  fun sun(~rays: n :: PosInt = 10, ....) :: Pict
  fun flower(~petals: n :: PosInt = 6, ....) :: Pict
  fun cloud(~bumps: n :: PosInt = 6, ....) :: Pict
  fun polygon(~sides: n :: PosInt = 10, ....) :: Pict
  fun circle(~sides: n :: PosInt = 10, ....) :: Pict
  fun gear(~arms: n :: PosInt = 10, ....,
           ~hole: hole :: Real = 0.3) :: Pict
){

 The same as @rhombus(radial_pict), but with defaults for arguments so that
 the result looks like a flower, cloud, etc., and sometimes with an
 different keyword like @rhombus(~petals) instead of @rhombus(~points).

 The @rhombus(gear) function has an extra @rhombus(hole) argument, which
 specifies a relative side for a hole in the middle of the gear.

}

@doc(
  annot.macro 'Radial'
  fun radial(
    ~points: n :: PosInt = 6,
    ~width: width :: Real = 64,
    ~height: height :: Real = width,
    ~rotate: rotate :: Real = 0,
    ~angle_at: angle_at :: Function.of_arity(2) = evenly_spaced,
    ~inner_radius: inner :: Real = 0.5,
    ~outer_radius: outer :: Real = 1,
    ~inner_pause: inner_pause :: Real = 0,
    ~outer_pause: outer_pause :: Real = 0,
    ~flat_inner_edge: flat_inner_edge = #false,
    ~flat_outer_edge: flat_outer_edge = #false,
    ~outer_pull: outer_pull :: Real = 0,
    ~inner_pull: inner_pull :: Real = 0,
  ) :: Radial
){

 Similar to @rhombus(radial_pict), but instead of a pict, produces a
 @rhombus(Radial, ~annot). A single @rhombus(Radial) can be converted to a pict
 with @rhombus(Radial.pict), but multiple radials can be combined using
 @rhombus(radials_pict).

 For example, @rhombus(gear) uses @rhombus(radials_pict) to combine gear
 arms with a hole when a non-zero hold is requested.

}

@doc(
  fun star_radial(~points: n :: PosInt = 5, ....) :: Radial
  fun flash_radial(~bumps: n :: PosInt = 10, ....) :: Radial
  fun sun_radial(~rays: n :: PosInt = 10, ....) :: Radial
  fun flower_radial(~petals: n :: PosInt = 6, ....) :: Radial
  fun cloud_radial(~bumps: n :: PosInt = 6, ....) :: Radial
  fun polygon_radial(~sides: n :: PosInt = 10, ....) :: Radial
  fun circle_radial(~sides: n :: PosInt = 10, ....) :: Radial
  fun gear_radial(~arms: n :: PosInt = 10, ....) :: Radial
){

 The same as @rhombus(radial), but with defaults for arguments so that
 the result looks like a flower, cloud, etc., and sometimes with an
 different keyword like @rhombus(~petals) instead of @rhombus(~points).

}

@doc(
  method (radial :: Radial).pict(
    ~line: line :: MaybeColor = #false,
    ~fill: fill :: MaybeColor = #'inherit,
    ~line_width: line_width :: LineWidth = #'inherit,
    ~bound: bound :: BoundingBoxMode = #'unit
  ) :: Pict
  method (radial :: Radial).path() :: Path
){

 Converts a @rhombus(Radial, ~annot) to a pict or DC path.

}

@doc(
  fun radials_pict(
    radial :: Radial, ...,
    ~line: line :: MaybeColor = #false,
    ~fill: fill :: MaybeColor = #'inherit,
    ~line_width: line_width :: LineWidth = #'inherit,
    ~bound: bound :: BoundingBoxMode = #'unit
  ) :: Pict
){

 Combines multiple @rhombus(Radial, ~annot)s to a pict. Nested radials
 creates holes in the same way as @rhombus(#'odd_even) polygon rendering.

}

@doc(
  fun evenly_spaced(i :: Int, out_of_n :: Int) :: Real
  fun jitter_spaced(jitter :: Real) :: Function.of_arity(2)
){

 Functions useful for @rhombus(~angle_at) arguments to
 @rhombus(radial_pict).

 The function returned by @rhombus(jitter_spaced) takes the angle that
 it would otherwise return an adjust it based on a @rhombus(math.sin) of
 the angle times @rhombus(jitter). The default @rhombus(~angle_at)
 argument for @rhombus(cloud) is @rhombus(jitter_spaced(0.3)).

}


@doc(
  annot.macro 'BoundingBoxMode'
){

 Satisfied by a bounding-box mode: @rhombus(#'unit), @rhombus(#'unit),
 @rhombus(#'shrink), or @rhombus(#'stretch).

}
