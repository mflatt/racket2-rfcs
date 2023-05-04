#lang scribble/rhombus/manual
@(import: "common.rhm" open)

@title{Strings}

A @deftech{string} is a sequence of Unicode @tech{characters}. A string
works with map-referencing @brackets to access a character via
@rhombus(#%ref). A string also works with the @rhombus(++) operator to
append strings, but a @rhombus(+&) can be used to append strings with
the static guaratee that the result is a string. A string can be used as
@tech{sequence}, in which case it supplies its bytes in order.

Although Racket supports mutable strings, the @rhombus(String, ~annot)
annotation recognizes only immutable strings, and Rhombus operations
generate immutable strings. Some operations allow mutable strings as
input, and @rhombus(StringView, ~annot) recognizes both mutable and
immutable strings.

@dispatch_table(
  "string"
  @rhombus(String)
  [str.length(), String.length(str)]
  [str.substring(arg, ...), String.substring(str, arg, ...)]
  [str.utf8_bytes(arg, ...), String.utf8_bytes(str, arg, ...)]
  [str.latin1_bytes(arg, ...), String.latin1_bytes(str, arg, ...)]
  [str.locale_bytes(arg, ...), String.locale_bytes(str, arg, ...)]
  [str.to_int(), String.to_int(str)]
  [str.to_number(), String.to_number(str)]
  [str.upcase(arg), String.upcase(str)]
  [str.downcase(arg), String.downcase(str)]
  [str.foldcase(arg), String.foldcase(str)]
  [str.titlecase(arg), String.titlecase(str)]
  [str.normalize_nfd(), String.normalize_nfd(str)]
  [str.normalize_nfkd(), String.normalize_nfkd(str)]
  [str.normalize_nfc(), String.normalize_nfc(str)]
  [str.normalize_nfkc(), String.normalize_nfkc(str)]
)

@doc(
  annot.macro 'String'
  annot.macro 'StringView'
  annot.macro 'StringView.asString'
){

 Matches strings. The @rhombus(StringView, ~annot) annotation allows mutable
 Racket strings as well as immutable Rhombus strings.
 The @rhombus(StringView.asString, ~annot) @tech{converter annotation}
 allows the same strings as @rhombus(StringView, ~annot), but converts
 a mutable Racket string to an immutable Rhombus string.

}

@doc(
  fun to_string(v) :: String
){

 Coerces @rhombus(v)  to a string.

 The string for of a value corresponds to the way that @rhombus(display)
 would print it, which means that strings, symbols, identifiers, and
 keywords convert as their character content.

@examples(
  to_string(10)
  to_string('hello')
  to_string([1, 2, 3])
)

}


@doc(
  operator (v1 +& v2) :: String
){

 Coerces @rhombus(v1) and @rhombus(v2) to a string, then appends the strings.

 The value is coerced to a string in the same way as by
 @rhombus(to_string).

@examples(
  "hello" +& "world"
  "it goes to " +& 11
  "the list " +& [1, 2, 3] +& " has " +& 3 +& " elements"
)

}


@doc(
  fun String.length(str :: StringView) :: NonnegInt
){

 Returns the number of characters in @rhombus(str).

@examples(
  String.length("hello")
  "hello".length()
)

}


@doc(
  fun String.substring(str :: StringView,
                       start :: NonnegInt,
                       end :: NonnegInt = String.length(str)) :: String
){

 Returns the substring of @rhombus(str) from @rhombus(start) (inclusive)
 to @rhombus(end) (exclusive).

@examples(
  String.substring("hello", 2, 4)
  String.substring("hello", 2)
)

}


@doc(
  fun String.utf8_bytes(str :: StringView,
                        err_byte :: Optional[Byte] = #false,
                        start :: NonnegInt = 0,
                        end :: NonnegInt = String.length(str)) :: Bytes
  fun String.latin1_bytes(str :: StringView,
                          err_byte :: Optional[Byte] = #false,
                          start :: NonnegInt = 0,
                          end :: NonnegInt = String.length(str)) :: Bytes
  fun String.locale_bytes(str :: StringView,
                          err_byte :: Optional[Byte] = #false,
                          start :: NonnegInt = 0,
                          end :: NonnegInt = String.length(str)) :: Bytes
){

 Converts a string to a byte string, encoding by UTF-8, Latin-1, or the
 current locale's encoding. The @rhombus(err_byte) argument provides a
 byte to use in place of an encoding error, where @rhombus(#false) means
 that an exception is raised. (No encoding error is possible with
 @rhombus(String.utf8_bytes), but @rhombus(err_byte) is accepted for
 consistency.)

@examples(
  "hello".utf8_bytes()
)

}




@doc(
  fun String.to_int(str :: StringView) :: Optional[Int]
){

 Parses @rhombus(str) as an integer, returning @rhombus(#false) if the
 string does not parse as an integer, otherwise returning the integer
 value.

@examples(
  String.to_int("-42")
  String.to_int("42.0")
  String.to_int("fourty-two")
  "100".to_int()
)

}


@doc(
  fun String.to_number(str :: StringView) :: Optional[Number]
){

 Parses @rhombus(str) as a number, returning @rhombus(#false) if the
 string does not parse as a number, otherwise returning the number
 value.

@examples(
  String.to_number("-42")
  String.to_number("42.0")
  String.to_number("fourty-two")
  "3/4".to_number()
)

}


@doc(
  fun String.upcase(str :: StringView) :: String
  fun String.downcase(str :: StringView) :: String
  fun String.foldcase(str :: StringView) :: String
  fun String.titlecase(str :: StringView) :: String
){

 Case-conversion functions.

}

@doc(
  fun String.normalize_nfd(str :: StringView) :: String
  fun String.normalize_nfkd(str :: StringView) :: String
  fun String.normalize_nfc(str :: StringView) :: String
  fun String.normalize_nfkc(str :: StringView) :: String
){

 Unicode normalization functions.

}

@doc(
  fun String.grapheme_span(str :: StringView,
                           start :: NonnegInt = 0,
                           end :: NonnegInt = str.length()) :: NonnegInt
){

 Returns the number of @tech{characters} (i.e., code points) in the
 string that form a Unicode grapheme cluster starting at @rhombus(start),
 assuming that @rhombus(start) is the start of a grapheme cluster and
 extending no further than the character before @rhombus(end). The result
 is @rhombus(0) if @rhombus(start) equals @rhombus(end).

 The @rhombus(start) and @rhombus(end) arguments must be valid indices as
 for @rhombus(String.substring).

}

@doc(
  fun String.grapheme_count(str :: StringView,
                            start :: NonnegInt = 0,
                            end :: NonnegInt = str.length()) :: NonnegInt
){

 Returns the number of grapheme clusters in
 @rhombus(String.substring(str, start, end)).

 The @rhombus(start) and @rhombus(end) arguments must be valid indices as
 for @rhombus(String.substring).

}
