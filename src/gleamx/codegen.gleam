import gleam/list
import gleam/result.{try}
import gleam/string.{length}
import gleamx/ast.{type Ast, type Chunk, type SyntaxError, SyntaxError}
import gleamx/lineinfo.{type LineInfo}

pub type SourceMap =
  List(SourceMapEntry)

type SourceMapEntry =
  #(Int, LineInfo)

pub fn generate(
  chunks: List(Chunk),
) -> Result(#(String, SourceMap), SyntaxError) {
  list.fold(chunks, Ok(#("", [])), fn(acc, chunk) {
    use #(code, source_map) <- try(acc)
    case chunk {
      ast.GleamCode(pos:, code: new_code) ->
        Ok(#(code <> new_code, [#(length(code), pos), ..source_map]))
      ast.GlxCode(ast:) -> {
        use #(code, new_source_map) <- try(generate_from_glx(code, ast))
        Ok(#(code, list.append(new_source_map, source_map)))
      }
    }
  })
}

fn generate_from_glx(
  code: String,
  ast: Ast,
) -> Result(#(String, SourceMap), SyntaxError) {
  let mapping = #(length(code), ast.pos)
  case ast {
    ast.VoidElement(tag:, args:, ..) -> {
      let code = code <> "html." <> tag <> "(["
      let #(code, source_map) = generate_args(code, args)
      Ok(#(code <> "])", [mapping, ..source_map]))
    }
    ast.ContainerElement(tag:, args:, children:, ..) -> {
      let code = code <> "html." <> tag <> "(["
      let #(code, args_source_map) = generate_args(code, args)
      let code = code <> "],"
      use #(code, children_source_map) <- try(case children {
        [ast.Spread(children: child, ..)] -> generate_from_glx(code, child)
        _ ->
          case list.contains(ast.textual_elements, tag) {
            True ->
              case children {
                [ast.CodeBlock(..) as child] -> generate_from_glx(code, child)
                _ ->
                  Error(SyntaxError(
                    pos: ast.pos,
                    msg: tag
                      <> " elements should only contain exactly one text child",
                  ))
              }
            False -> {
              use #(code, source_map) <- try(
                list.fold(
                  children,
                  Ok(#(code <> "[", [mapping])),
                  fn(acc, child) {
                    use #(code, source_map) <- try(acc)
                    use #(code, new_mappings) <- try(generate_from_glx(
                      code,
                      child,
                    ))
                    Ok(#(code <> ",", list.append(new_mappings, source_map)))
                  },
                ),
              )
              Ok(#(code <> "]", source_map))
            }
          }
      })
      let code = code <> ")"
      Ok(#(code, list.append(children_source_map, args_source_map)))
    }

    ast.Spread(children:, ..) -> generate_from_glx(code <> "..", children)

    ast.CodeBlock(gleam_code:, ..) -> Ok(#(code <> gleam_code, [mapping]))
  }
}

fn generate_args(code: String, args: List(ast.Arg)) -> #(String, SourceMap) {
  case args {
    [arg, ..args] -> {
      let mapping = #(length(code), arg.pos)
      let code = code <> "attribute." <> arg.name <> "("
      let code = case arg {
        ast.BoolArg(..) -> code <> "True"
        ast.LitArg(value:, ..) -> code <> "\"" <> value <> "\""
        ast.ExprArg(value:, ..) -> code <> value
      }
      let #(code, source_map) = generate_args(code <> "),", args)
      #(code, [mapping, ..source_map])
    }
    [] -> #(code, [])
  }
}
