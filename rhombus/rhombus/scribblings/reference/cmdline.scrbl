#lang rhombus/scribble/manual
@(import:
    "common.rhm" open:
      except: def
    "nonterminal.rhm" open
    meta_label:
      rhombus/cmdline)

@(def dots = @rhombus(..., ~bind))

@title{Command Line Parsing}

@docmodule(rhombus/cmdline)

@(~version_at_least "8.14.0.4")

@doc(
  expr.macro 'cmdline.parser:
                $option
                ...
                $content_expr
                ...'

  expr.macro 'cmdline.parse:
                $option
                ...
                $content_expr
                ...'

  grammar option:
    ~init: $body; ...
    ~no_builtin
){

 The @rhombus(cmdline.parser) form produces a @rhombus(Parser), where
 the @rhombus(content_expr) expressions produce flag and argument
 handlers, especially using @rhombus(cmdline.flag) and
 @rhombus(cmdline.args). The @rhombus(cmdline.parse) form has the same
 syntax to create the same @rhombus(comdline.Parser), but it immediately
 calls the @rhombus(comdline.Parse.parse) method on the resulting
 @rhombus(comdline.Parser) object.

 The @rhombus(Parse.parse) method returns a @tech{map} with the parse
 results. If @rhombus(~init) is provided as an @rhombus(option) form, the
 result of the @rhombus(body) sequence produces a map to serve as the
 parser's initial state.

 Unless @rhombus(~no_builtin) is provided as an @rhombus(option), then
 @litchar{--help}/@litchar{-h} and @litchar{--} flag support is
 implicitly added to the @rhombus(content_expr)s.

 The result of @rhombus(content_expr) must be either

@itemlist(

 @item{a @rhombus(cmdline.Flag) object, usually as produced by
  @rhombus(cmdline.flag);}

 @item{a @rhombus(cmdline.Multi), @rhombus(cmdline.OnceEach), or
  @rhombus(cmdline.OnceAny) set of flags, usually as produced by
  @rhombus(cmdline.multi), @rhombus(cmdline.once_any), or
  @rhombus(cmdline.once_each);}

 @item{a @rhombus(cmdline.Handler) object for arguments after all flags,
  usually produced by @rhombus(cmdline.args);}

 @item{a @rhombus(cmdline.Text) object, usually produced by
  @rhombus(cmdline.help); or}

 @item{or a list of otherwise valid @rhombus(content_expr) results,
  including nested lists.}

)

}

@doc(
  expr.macro 'cmdline.flag flag_string $arg ... $maybe_ellipsis'

  expr.macro 'cmdline.flag flag_string $arg ... $maybe_ellipsis:
                $option
                ...
                $body
                ...'
  grammar arg:
    $identifier
    ($identifier #,(@rhombus(::, ~bind)) $cmdline_annot)
    ($identifier #,(@rhombus(as, ~impo)) $identifier)
    ($identifier #,(@rhombus(as, ~impo)) $identifier #,(@rhombus(::, ~bind)) $cmdline_annot)

  grammar option:
    ~alias $flag_string ...
    ~alias: $flag_string ...; ...
    ~help: $expr
    ~help: $body; ...
    ~key: $expr
    ~key: $body; ...
    ~accum $id
    ~accum: $id
    ~init $expr
    ~init: $body; ...  
    ~multi
    ~final

  grammar maybe_ellipsis:
    #,(dots)
    #,(epsilon)

){

 Creates a @rhombus(cmdline.Flag) object to describe the handling of a
 command-line flag for @rhombus(cmdline.parse) and related forms. The
 only required component is a @rhombus(flag_string) that must be a
 literal string starting with either @litchar{-} or @litchar{+}, and that
 either continues with the same @litchar{-} or @litchar{+} character
 followed by one or more characters (for a long-form flag), or that has a
 single character after the leading @litchar{-} or @litchar{+} (for a
 short-form flag).

 Arguments to the flag are described by subsequent @rhombus(arg)s. If
 @rhombus(maybe_ellipsis) after the @rhombus(arg)s is @dots, then the
 last @rhombus(arg) can be repeated any number of times, and its binding
 is a repetition. When an @rhombus(arg) @rhombus(as, ~impo), then the
 identifier before @rhombus(as, ~impo) is used as the argument name in
 help text, while the identifier after @rhombus(as, ~impo) is bound to
 the argument value for use in a @rhombus(body) sequence at the end of
 the @rhombus(cmdline.flag) body. If @rhombus(cmdline_annot) is included,
 it must identifier a @tech{command-line flag annotation} such as
 @rhombus(cmdline.Int, ~at #{rhombus/flag_annot}) or
 @rhombus(cmdline.Path, ~at #{rhombus/flag_annot}).

 After @rhombus(option)s, an optional @rhombus(body) sequence can be
 provided. If this @rhombus(body) sequence is non-empty, then it is
 responsible for returning a @tech{map} that is a parser's new state,
 where the resulting map normally should be derived from the current one
 as received through an @rhombus(~accum) declaration. If the
 @rhombus(body) sequence is empty, then a body is created automatically:

@itemlist(

 @item{The body will update the current parser-state map with a new
  value for @rhombus(key, ~var), where @rhombus(key, ~var) is the value
  produced by an @rhombus(expr) or @rhombus(body) sequence if a
  @rhombus(~key) option if provided. If @rhombus(~key) is not provided,
  then @rhombus(key, ~var) is a symbol derived from
  the initial @rhombus(flag_string) by dropping a the leading @litchar{-}
  or @litchar{+} for a short-form flag or the first two characters of a
  long-form flag.}

 @item{If the flag's @rhombus(arg ... maybe_ellipsis) allows multiple
  arguments, then received arguments are combined in a list to add to the
  parser-state map for @rhombus(key, ~var). If a single argument is allowed, the
  received argument will be added directly to the parser-state map. If no
  arguments are allowed, then @rhombus(#true) will be added to the map.}

 @item{If the @rhombus(~multi) option is specified or if the
  @rhombus(cmdline.flag) form appears syntactically with a
  @rhombus(cmdline.multi) form, then @rhombus(key, ~var) is updated in the
  parser state map by adding to the end of an existsing list value in the
  map, starting with the empty list if @rhombus(key, ~var) is not in the
  map. Otherwise, any existing value of @rhombus(key, ~var) is replaced
  with a new value.}

)

 The @rhombus(~alias) option can provide additional
 @rhombus(flag_string)s that serve as an alias for the flag. Typically,
 the main flag is short-form and an alias is long-form or vice versa.

 The @rhombus(~help) option provides text to show with the flag in help
 output. The string produced by the @rhombus(expr) or @rhombus(body)
 sequence in @rhombus(~help) can contain newline characters, and space is
 added to the start of lines as needed.

 The @rhombus(~key) option specifies a key used for a default flag
 body, if one is created. The key is not used if the
 @rhombus(cmdline.flag) form has a non-empty @rhombus(body) sequence.

 The @rhombus(~accum) option binds an identifier to the parser's current
 state map for use by a non-empty @rhombus(body) sequence. The identifier
 is not used by the default body sequence, if one is generated.

 The @rhombus(~init) option provides an @rhombus(expr) or @rhombus(body)
 sequence that must produce a @tech{map}. The keys and values of the map
 are added to the parser's initial state map. Keys must be distinct
 across all flag handlers for a parser.

 The @rhombus(~multi) option causes a parser using the flag to allow
 multiple instances of the flag in a command line. If @rhombus(~multi) is
 not present, but the the @rhombus(cmdline.flag) form is syntactically
 within a @rhombus(cmdline.multi) form, then @rhombus(~multi) mode is
 automatically enabled. Otherwise, the flag can appear at most once
 within a command line. A flag without @rhombus(~multi) can be used in
 @rhombus(cmdline.multi) to allow it multiple times, but the default flag
 body sequence (if generated) depends only on whether the
 @rhombus(~multi) option is present or a syntactically enclosing
 @rhombus(cmdline.multi) form is present.

 The @rhombus(~final) option causes all arguments that appears after he
 flag to be treated as non-flag arguments. This is the behavior of the
 builtin @litchar{--} flag, and it is rarely needed for other flags.

}


@doc(
  expr.macro 'cmdline.multi:
                $content_expr
                ...'
  expr.macro 'cmdline.once_each:
                $content_expr
                ...'
  expr.macro 'cmdline.once_any:
                $content_expr
                ...'
){


 Combines a set of flags and constrains the way that the flags can
 appear in a command line. Flags grouped with @rhombus(cmdline.multi) can
 be used any number of times. Flags grouped with @rhombus(cmdline.once_each) can
 be used a single time each. Flags grouped with @rhombus(cmdline.once_any) can
 be used a single time and only when no other flag in the same set is used.

 The result of a @rhombus(content_expr) can be a @rhombus(cmdline.Flag),
 as usually produced by @rhombus(cmdline.flag), a set of flags that
 already have the new set's property, or a list of otherwise acceptable
 @rhombus(content_expr) results (including nested lists).

}

@doc(
  ~nonterminal:
    arg: cmdline.flag
    maybe_ellipsis: cmdline.flag

  expr.macro 'cmdline.args $arg ... $maybe_ellipsis'

  expr.macro 'cmdline.args $arg ... $maybe_ellipsis:
                $option
                ...
                $body
                ...'
  grammar option:
    ~accum $id
    ~accum: $id
    ~init $expr
    ~init: $body; ...
){

 Like @rhombus(cmdline.flag), but creates a @rhombus(cmdline.Handler)
 object to describe the handling of arguments after command-line flags
 for @rhombus(cmdline.parse) and related forms.

 The set of @rhombus(option)s for @rhombus(cmdline.args) is more limited
 than @rhombus(cmdline.flags), since it does not include flag string or
 flag-specific help text.

 The @rhombus(body) sequence implements argument parsing the same way as
 for @rhombus(cmdline.flag). If the @rhombus(body) sequence is empty, the
 default implementation always maps @rhombus(#'args) to a list of
 arguments, even if that list is always empty or always contains only one
 item.

}


@doc(
  ~nonterminal:
    arg: cmdline.flag
    maybe_ellipsis: cmdline.flag

  expr.macro 'cmdline.help:
                $option
                ...
                $body
                ...'

  grammar option:
    ~end
){

 Creates a @rhombus(cmdline.Text) object to provide help text for
 @rhombus(cmdline.parse) and related forms. The @rhombus(body) sequence
 must produce a string. The string can contain newline characters to
 create multiline help text.

 Helps text can be intermingled with flags in a form like
 @rhombus(cmdline.parse), and the text will be rendered in the same
 relative order as the flag and help-text implementations.

 If @rhombus(~end) is provided as an @rhombus(option) and the help text
 is after all flags and other help text, then it is placed after the
 builtin flags when those flags are not disabled (e.g., using
 @rhombus(~no_builtin) in @rhombus(cmdline.parse)). Without
 @rhombus(~end), trailing help text is rendered after all other text and
 flags, but before the help text for builtin options.

}

