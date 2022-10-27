#lang scribble/rhombus/manual
@(import: "common.rhm" open)

@title{Classes}

@doc(
  ~literal: :: extends,
  defn.macro 'class $identifier_path($field, ...)',
  defn.macro 'class $identifier_path($field, ...):
                $class_clause
                ...',

  grammar identifier_path:
    $identifier
    $identifier_path . $identifier,

  grammar field:
    $identifier
    $identifier :: $annotation,
  
  class_clause.macro 'extends $identifier_path',
  class_clause.macro 'final',
  class_clause.macro 'nonfinal',
  class_clause.macro 'constructor ($make_identifier): $callable',
  class_clause.macro 'authentic',
){

 Binds @rhombus(identifier_path) as a class name, which serves several roles:

@itemlist(

 @item{a constructor function, which takes as many arguments as the
   supplied @rhombus(field)s and returns an instance of the class;},

 @item{an annotation, which is satisfied by any instance of the class;},

 @item{a pattern constructor, which takes as many patterns as the
   supplied @rhombus(field)s and matches an instance of the class where the
   fields match the corresponding patterns;},

 @item{a dot povider to access accessor functions @rhombus(identifier_path.field);},

 @item{an annotation constructor @rhombus(identifier_path.of), which takes as
   many annotation arguments as supplied @rhombus(field)s.}

)

 A @deftech{class clause} represented by @rhombus(class_clause) can be
 one of the predefined class clause forms, or a macro that ultimately
 expands to a predeifned form.

 When a @rhombus(class_clause) is an @rhombus(extends, ~class_clause)
 form, the new class is created as a subclass of the extended class. The
 extended class must not be @tech{final}. At most one
 @rhombus(class_clause) can have @rhombus(extends, ~class_clause).

 When a @rhombus(class_clause) is @rhombus(final, ~class_clause), then
 the new class is @deftech{final}, which means that it cannot have
 subclasses. When a @rhombus(class_clause) is
 @rhombus(nonfinal, ~class_clause), then the new class is not final. A
 class is final by default, unless it has a superclass, in which case it
 is not final by default. At most one @rhombus(class_clause) can have
 @rhombus(final, ~class_clause) or @rhombus(nonfinal, ~class_clause).

 When a @rhombus(class_clause) is a @rhombus(constructor, ~class_clause)
 form, then a use of new class's @rhombus(identifier_path) as a
 constructor function invokes the @rhombus(callable) (typically
 @rhombus(fun, ~callable)) in the block after @rhombus(constructor, ~class_clause).
 That function must return an instance of the new class, typically by
 calling @rhombus(make_identifier):

@itemlist(

 @item{If the new class does not have a superclass, then
  @rhombus(make_identifier) is bound to a function that accepts as many
  arguments as declared @rhombus(field)s, and it returns an instance of
  the class. Note that this instance might be an instance of a subclass if
  the new class is not @tech{final}.},

 @item{If the new class has a superclass, then @rhombus(make_identifier)
  is bound to a function that accepts the same arguments as the superclass
  constructor. Instead of returning an instance of the class, it returns a
  function that accepts as many arguments as declared @rhombus(field)s in
  the new subclass, and the result of that function is an instance of the
  new class. Again, the result instance might be an instance of a subclass
  if the new class is not @tech{final}.}

)
 
 When a @rhombus(class_clause) is @rhombus(authentic, ~class_clause),
 then the new class cannot be chaperoned or impersonated. At most one
 @rhombus(class_clause) can have @rhombus(authentic, ~class_clause).
 
 Each @rhombus(field)'s @rhombus(identifier) name must distinct from
 each other @rhombus(field)'s @rhombus(identifier). If an
 @rhombus(extends) clause is present, then each @rhombus(field)'s
 @rhombus(identifier) name must also be distinct from any field name in
 the superclass.

 See @secref("static-info-rules") for information about static
 information associated with classes.

 See @secref("namespaces") for information on @rhombus(identifier_path).

@examples(
  class Posn(x, y),
  Posn(1, 2),
  Posn.x,
  Posn.x(Posn(1, 2)),
  Posn(1, 2).x,
  ~error: class Posn3(z):
            extends Posn,
  class Posn2D(x, y):
    nonfinal,
  class Posn3D(z):
    extends Posn2D,
  Posn3D(1, 2, 3),
  class Rectangle(w, h):
    nonfinal
    constructor (make):
      fun (~width: w, ~height: h):
        make(w, h),
  class Square():
    extends Rectangle
    constructor (make):
      fun (~side: s):
        make(~width: s, ~height: s)(),
  Square(~side: 10)
)

}
