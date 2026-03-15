import gleam/list
import gleam/result.{try}
import gleam/string.{crop, drop_start, first, length, slice}
import gleamx/ast.{type Arg, type Ast, type Chunk}
import gleamx/lineinfo.{type CodeMeta, type LineInfo, analyze_code, line_info}

pub type SyntaxError {
  SyntaxError(pos: LineInfo, msg: String)
}

type Parsed(t) {
  Parsed(code: String, value: t)
}

const whitespace_chars = [" ", "\t", "\n", "\r"]

pub fn parse(code: String) -> Result(List(Chunk), SyntaxError) {
  parse_loop(code, analyze_code(code))
}

fn parse_loop(code: String, meta: CodeMeta) -> Result(List(Chunk), SyntaxError) {
  let pos = line_info(code, meta)
  let rest = crop(from: code, before: "<?")
  case length(rest) == length(code) {
    True -> Ok([ast.GleamCode(pos:, code:)])
    False -> {
      let gleam_code = slice(code, 0, length(code) - length(rest))
      use Parsed(code:, value: glx_ast) <- try(
        rest |> drop_start(2) |> parse_element(meta),
      )
      use rest <- try(parse_loop(code, meta))
      Ok([
        ast.GleamCode(pos:, code: gleam_code),
        ast.GlxCode(ast: glx_ast),
        ..rest
      ])
    }
  }
}

fn parse_element(
  code: String,
  meta: CodeMeta,
) -> Result(Parsed(Ast), SyntaxError) {
  let code = skip_spaces(code)
  case code {
    "<" <> code -> {
      let code = skip_spaces(code)
      let pos = line_info(code, meta)
      let Parsed(code:, value: tag) = parse_until(code, [" ", "/", ">"])
      use Parsed(code:, value: args) <- try(parse_args(code, meta))
      let code = skip_spaces(code)
      case code {
        "/>" <> code ->
          Ok(Parsed(code:, value: ast.VoidElement(pos:, tag:, args:)))
        ">" <> code -> {
          parse_children(code, tag, meta)
          |> map_parse_result(fn(children) {
            ast.ContainerElement(
              pos: line_info(code, meta),
              tag:,
              args:,
              children:,
            )
          })
        }
        _ -> panic
      }
    }

    ".." <> code ->
      parse_element(code, meta)
      |> map_parse_result(fn(children) {
        ast.Spread(pos: line_info(code, meta), children:)
      })

    "{" <> code ->
      parse_block(code, meta, "{", "}")
      |> map_parse_result(fn(body) {
        ast.Block(pos: line_info(code, meta), body:)
      })

    _ -> {
      let Parsed(code:, value: name) =
        parse_until(code, ["(", ..whitespace_chars])
      case code {
        "(" <> code -> {
          parse_block(code, meta, "(", ")")
          |> map_parse_result(fn(params) {
            ast.Call(
              pos: line_info(code, meta),
              def: name <> "(" <> params <> ")",
            )
          })
        }
        _ ->
          Ok(Parsed(
            code:,
            value: ast.Variable(pos: line_info(code, meta), name:),
          ))
      }
    }
  }
}

fn parse_children(
  code: String,
  parent_tag: String,
  meta: CodeMeta,
) -> Result(Parsed(List(Ast)), SyntaxError) {
  let code = skip_spaces(code)
  case code {
    "</" <> code -> {
      let code = skip_spaces(code)
      let Parsed(code:, value: tag) = parse_until(code, [">"])
      case tag == parent_tag {
        False ->
          Error(syntax_error(code, meta, "closing tag doesn't match opened tag"))
        True -> Ok(Parsed(drop_start(code, 1), []))
      }
    }
    _ -> {
      use Parsed(code:, value: element) <- try(parse_element(code, meta))
      use Parsed(code:, value: rest) <- try(parse_children(
        code,
        parent_tag,
        meta,
      ))
      Ok(Parsed(code:, value: [element, ..rest]))
    }
  }
}

fn parse_args(
  code: String,
  meta: CodeMeta,
) -> Result(Parsed(List(Arg)), SyntaxError) {
  let code = skip_spaces(code)
  case first(code) {
    Ok(">") | Ok("/") -> Ok(Parsed(code:, value: []))
    _ -> {
      let Parsed(code:, value: name) = parse_until(code, ["=", " ", "/", ">"])
      let code = skip_spaces(code)
      case code {
        "=" <> code -> {
          let code = skip_spaces(code)
          case code {
            "\"" <> code -> {
              let Parsed(code:, value:) = parse_until(code, ["\""])
              parse_args(code, meta)
              |> map_parse_result(fn(args) {
                [ast.LitArg(pos: line_info(code, meta), name:, value:), ..args]
              })
            }
            "{" <> code -> {
              use Parsed(code:, value:) <- try(parse_block(code, meta, "{", "}"))
              parse_args(code, meta)
              |> map_parse_result(fn(args) {
                [ast.ExprArg(pos: line_info(code, meta), name:, value:), ..args]
              })
            }
            _ -> Error(syntax_error(code, meta, "invalid argument value"))
          }
        }
        _ -> parse_args(code, meta)
      }
    }
  }
}

fn parse_block(
  code: String,
  meta: CodeMeta,
  open: String,
  close: String,
) -> Result(Parsed(String), SyntaxError) {
  use new_code <- try(parse_block_scan(code, meta, open, close, 0))
  Ok(Parsed(
    code: new_code,
    value: slice(code, 0, length(code) - length(new_code) - 1),
    // -1 to not include closing '}'
  ))
}

fn parse_block_scan(
  code: String,
  meta: CodeMeta,
  open: String,
  close: String,
  depth: Int,
) -> Result(String, SyntaxError) {
  let rest = drop_start(code, 1)
  case first(code) {
    Error(_) ->
      Error(syntax_error(rest, meta, "unexpected EOF before closing the block"))
    Ok(x) if x == open -> parse_block_scan(rest, meta, open, close, depth + 1)
    Ok(x) if x == close && depth > 0 ->
      parse_block_scan(rest, meta, open, close, depth - 1)
    Ok(x) if x == close -> Ok(rest)
    _ -> parse_block_scan(rest, meta, open, close, depth)
  }
}

fn parse_until(code: String, syms: List(String)) -> Parsed(String) {
  let new_code = parse_until_scan(code, syms)
  Parsed(code: new_code, value: slice(code, 0, length(code) - length(new_code)))
}

fn parse_until_scan(code: String, syms: List(String)) -> String {
  case first(code) {
    Ok(sym) ->
      case list.contains(syms, sym) {
        True -> code
        False -> parse_until_scan(code |> drop_start(1), syms)
      }
    _ -> code
  }
}

fn skip_spaces(code: String) -> String {
  case first(code) {
    Ok(sym) ->
      case list.contains(whitespace_chars, sym) {
        True -> skip_spaces(code |> drop_start(1))
        False -> code
      }
    _ -> code
  }
}

fn syntax_error(code: String, meta: CodeMeta, msg: String) -> SyntaxError {
  SyntaxError(pos: line_info(code, meta), msg: msg)
}

pub fn error_to_string(error: SyntaxError) -> String {
  error.msg
  // todo: with line info etc
}

fn map_parse_result(
  res: Result(Parsed(a), SyntaxError),
  f: fn(a) -> b,
) -> Result(Parsed(b), SyntaxError) {
  case res {
    Ok(Parsed(code:, value:)) -> Ok(Parsed(code:, value: f(value)))
    Error(e) -> Error(e)
  }
}
