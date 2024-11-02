#lang rhombus/scribble/manual
@(import:
    "common.rhm" open
    "nonterminal.rhm" open)

@title(~tag: "path"){Paths}

A @deftech{path} value represents a filesystem path for the host
operating system. See also @secref("cross-path").

@dispatch_table(
  "path"
  Path
  path.bytes()
  path.string()
  path.add(part, ...)
  path.split()
  path.name()
  path.parent()
  path.directory_only(...)
  path.to_directory_path(...)
  path.to_absolute_path(...)
  path.suffix(...)
  path.replace_suffix(...)
  path.add_suffix(...)
  path.cleanse(...)
  path.simplify(...)
  path.normal_case(...)
  path.as_relative_to(...)
)

Paths are @tech{comparable}, which means that generic operations like
@rhombus(<) and @rhombus(>) work on paths.

@doc(
  annot.macro 'Path'
  annot.macro 'PathString'
  annot.macro 'PathString.to_path'
  annot.macro 'PathString.to_absolute_path'
  annot.macro 'PathString.to_absolute_path(
                 ~relative_to: base :: PathString.to_path && Path.Absolute
               )'
  annot.macro 'Path.Absolute'
  annot.macro 'Path.Relative'
  annot.macro 'Path.DriveRelative'
  annot.macro 'Path.Directory'
  annot.macro 'Path.Element'
  enum Path.Dot:
    same
    up
){

 Matches a path value.  The @rhombus(PathString, ~annot) annotation allows
 @rhombus(ReadableString, ~annot) as well as @rhombus(Path, ~annot) values.
 The @rhombus(PathString.to_path, ~annot)
 @tech(~doc: guide_doc){converter annotation} allows
 @rhombus(PathString, ~annot) values, but converts
 @rhombus(ReadableString, ~annot) values to @rhombus(Path) values.  Similarly
 @rhombus(PathString.to_absolute_path, ~annot) is a converter annotation that
 converts a @rhombus(PathString, ~annot) into an absolute path relative to
 @rhombus(Path.current_directory()) or to the specified @rhombus(base)
 directory.

 The @rhombus(Path.Absolute, ~annot) annotation only matches
 @rhombus(Path, ~annot)s that begin with a root directory of the filesystem
 or drive.  The @rhombus(Path.Relative, ~annot) annotation only matches
 @rhombus(Path, ~annot)s that are relative to some base directory.
 The @rhombus(Path.DriveRelative, ~annot) annotation only matches Windows
 @rhombus(Path, ~annot)s that are relative to a drive.

 The @rhombus(Path.Directory, ~annot) annotation only matches
 @rhombus(Path, ~annot)s that syntactically refer to a directory; see
 @rhombus(filesystem.directory_exists) for checking whether a path refers
 to a directory on the filesystem.

 The @rhombus(Path.Element, ~annot) annotation matches a path that
 represents a single path element---that is, a path for which
 @rhombus(Path.split) returns a list containing one element.

 A @rhombus(Path.Dot) symbol refers to an abstract directory-navigation
 path element. For both path conventions currently supported, the symbol
 @rhombus(#'same) as a @rhombus(Path.Dot) is equivalent to @rhombus("."),
 and the symbol @rhombus(#'same) as a @rhombus(Path.Dot) is equivalent to
 @rhombus("..").

}


@doc(
  fun Path(path :: Bytes || PathString || Path.Dot) :: Path
){

 Constructs a path given a byte string, string, existing path, or
 directory-navigation symbol. When a path is provided as @rhombus(path),
 then the result is @rhombus(path).

@examples(
  def p = Path("/home/rhombus/shape.txt")
  p
  Path(p)
  p.string()
)

}

@doc(
  bind.macro 'Path($bind)'
){

 Matches a path where the byte-string form of the path matches
 @rhombus(bind).

@examples(
  def Path(bstr) = Path("/home/rhombus/shape.txt")
  bstr
)

}

@doc(
  Parameter.def Path.current_directory :: Path
){

 A @tech{context parameter} for the current directory. This directory
 need not actually exist on the filesystem.

}


@doc(
  fun Path.bytes(path :: Path) :: Bytes
){

 Converts a path to a byte-string form, which does not lose any
 information about the path.

@examples(
  def p = Path("/home/rhombus/shape.txt")
  Path.bytes(p)
  p.bytes()
)

}


@doc(
  fun Path.string(path :: Path) :: String
){

 Converts a path to a human-readable form, but the conversion may lose
 information if the path cannot be expressed using a string (e.g., due to
 a byte-string form that is not a UTF-8 encoding).

@examples(
  def p = Path(#"/home/rhombus/shape.txt")
  Path.string(p)
  p.string()
)

}


@doc(
  fun Path.add(path :: PathString || Path.dot,
               part :: PathString || Path.dot,
               ...) :: Path
  operator ((base :: PathString) +/ (part :: PathString || Path.Dot))
    :: Path
){

  Creates a path given a base path and any number of sub-path
  extensions. If @rhombus(path) is an absolute path,
  the result is an absolute path, otherwise the result is a relative path.

  The @rhombus(path) and each @rhombus(part) must be either a relative
  path, the symbol @rhombus(#'up) (indicating the relative parent
  directory), or the symbol @rhombus(#'same) (indicating the
  relative current directory).  For Windows paths, if @rhombus(path) is a
  drive specification (with or without a trailing slash) the first
  @rhombus(part) can be a drive-relative path. For all platforms,
  the last @rhombus(part) can be a filename.

  Each @rhombus(part) and @rhombus(path) can optionally end in a directory
  separator. If the last @rhombus(part) ends in a separator, it is
  included in the resulting path.

  The @rhombus(Path.add) procedure builds a path @italic{without}
  checking the validity of the path or accessing the filesystem.

@examples(
  def p = Path("/home/rhombus")
  Path.add(p, "shape.txt")
  p.add("shape.txt")
  p +/ "shape.txt"
)

}


@doc(
  fun Path.split(path :: PathString)
    :: List.of(Path.Element || Path.Dot)
){

 Returns a list of path elements that constitute @rhombus(path).
 Directory-navigation elements are detected and represented as
 @rhombus(Path.Dot) elements.

 The @rhombus(Path.split) function computes its result in time
 proportional to the length of @rhombus(path).

@examples(
  def p = Path("/home/rhombus/shape.txt")
  Path.split(p)
  p.split()
)

}

@doc(
  fun Path.name(path :: PathString) :: Path.Element || Path.Dot
  fun Path.parent(path :: PathString) :: (Path.Directory
                                            || matching(#'relative)
                                            || False)
  fun Path.directory_only(path :: PathString) :: Path.Directory
  fun Path.to_directory_path(path :: PathString) :: Path.Directory
){

 The @rhombus(Path.name) and @rhombus(Path.parent) functions produce the
 last element or @rhombus(path) and the path before its last element,
 respectively.

 The @rhombus(Path.directory_only) function returns @rhombus(path)
 without its final path element in the case that @rhombus(path) is not
 syntactically a directory; if @rhombus(path) has only a single,
 non-directory path element, #f is returned. If @rhombus(path) is
 syntactically a directory, then @rhombus(path) is returned unchanged
 (but as a path, if it was a string).

 The @rhombus(Path.to_directory_path) function converts @rhombus(path)
 to one that syntactically represents a directory path if it does not
 already, typically by adding a path separator to the end.

@examples(
  def p = Path("/home/rhombus/shape.txt")
  Path.name(p)
  Path.parent(p)
  Path.directory_only(p)
  Path.directory_only(Path.parent(p))
  Path.to_directory_path(p)
)

}

@doc(
  fun Path.to_absolute_path(
    path :: PathString,
    ~relative_to: base :: PathString.to_path && Path.Absolute
                    = Path.current_directory()
  ) :: Path
){

 Returns @rhombus(path) as an absolute path. If @rhombus(path) is a @rhombus(Path) and already an
 absolute path, it is returned as the result. Otherwise, @rhombus(path) is
 resolved with respect to the absolute path @rhombus(base). If @rhombus(base) is
 not an absolute path, the @rhombus(Exn.Fail.Annot, ~class) exception is
 thrown.

}


@doc(
  fun Path.suffix(path :: PathString) :: maybe(Bytes)
  fun Path.replace_suffix(
    path :: PathString,
    suffix :: Bytes || ReadableString
  ) :: Path
  fun Path.add_suffix(
    path :: PathString,
    suffix :: Bytes || ReadableString,
    ~sep: sep :: Bytes || ReadableString = "_"
  ) :: Path                                           
){

 Extracts or adjusts the suffix of a path, which is the part of
 @rhombus(Path.name(path).bytes()) that starts with with last
 @rhombus(Byte#".") and runs to the end of the byte string. If the path
 name has no @rhombus(Byte#"."), then the path has no suffix, and
 @rhombus(Path.suffix) returns @rhombus(#false).

 The @rhombus(Path.replace_suffix) function removes the suffix from a
 path, if any, and then adds @rhombus(suffix), which can be @rhombus("")
 or @rhombus(#"") to just remove a suffix from @rhombus(path) or
 otherwise normally starts with @rhombus(Char".") or @rhombus(Byte#".").

 The @rhombus(Path.add_suffix) function first changes a
 @rhombus(Byte#".") in the path that starts its current prefix with
 @rhombus(sep), and then it adds the given @rhombus(suffix).

@examples(
  def p = Path("/home/rhombus/shape.txt")
  p.suffix()
  p.replace_suffix(".rhm")
  p.add_suffix(".rhm")
)

}

@doc(
  fun Path.cleanse(path :: PathString) :: Path
  fun Path.simplify(path :: PathString) :: Path
  fun Path.normal_case(path :: PathString) :: Path
){

 The @rhombus(Path.cleanse) function removes redundant directory
 separators, normalizes the separator character for Windows paths, and
 performs some other normalization steps for unusual Windows paths.

 The @rhombus(Path.simplify) function performs the same cleansing, and
 then removes @rhombus(#'same) path elements and syntactically resolves
 @rhombus(#'up) elements where preceding elements can be removed. This
 simplification is purely syntactic and does not consult the filesystem;
 see also @rhombus(filesystem.simplify_path).

 The @rhombus(Path.normal_case) function has no effect on platforms that
 use Unix path conventions, and it case-folds a path's string form on
 Windows.

@examples(
  Path.cleanse("a/..//b")
  Path.simplify("a/..//b")
)

}


@doc(
  fun Path.as_relative_to(
    path :: PathString,
    rel_to_path :: PathString,
    ~more_than_root: more_than_root = #false,
    ~more_than_same: more_than_same = #true,
    ~normal_case: normal_case = #true
  ) :: Path
){

 Returns a @rhombus(path) that is syntactically equivalent to
 @rhombus(path), but made relative to @rhombus(rel_to_path). Note that
 constructing a relative path may involve using @rhombus(#'up) path
 elements. On Windows, it is possible for no relative path to exist from
 @rhombus(rel_to_path) to @rhombus(path) if the paths start with
 different drives. Typically, @rhombus(path) and @rhombus(rel_to_path)
 should be first converted to absolute paths;
 @rhombus(Path.as_relative_to) does not perform that conversion, so it
 cannot change a relative @rhombus(path) given an absolute
 @rhombus(rel_to_path).

 If @rhombus(more_than_root) is @rhombus(#true), then if @rhombus(path)
 and @rhombus(rel_to_path) has only a root path element in common, then
 @rhombus(path) is returned unchanged (except converted to a
 @rhombus(Path) object if it is a string).

 If @rhombus(more_than_same) is @rhombus(#true), then if @rhombus(path)
 and @rhombus(rel_to_path) are syntacticaly equivalent, then
 @rhombus(path) is returned unchanged.

 If @rhombus(normal) is @rhombus(#true), then on Windows, path elements
 are normalized for comparsion. Otherwise, path elements are considered
 equivalent only when they have the same case.

@examples(
  def p = Path("/home/rhombus/shape.txt")
  p.as_relative_to("/home")
  p.as_relative_to("/home/racket")
)

}


@// ------------------------------------------------------------

@include_section("runtime-path.scrbl")
