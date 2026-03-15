import gleam/list
import gleam/string.{length}
import gleamx/ast.{type Ast, type Chunk}
import gleamx/lineinfo.{type LineInfo}

pub type SourceMap =
  List(SourceMapEntry)

type SourceMapEntry =
  #(Int, LineInfo)

pub fn generate(chunks: List(Chunk)) -> #(String, SourceMap) {
  list.fold(chunks, #("", []), fn(acc, chunk) {
    let #(code, source_map) = acc
    case chunk {
      ast.GleamCode(pos:, code: new_code) -> #(code <> new_code, [
        #(length(code), pos),
        ..source_map
      ])
      ast.GlxCode(ast:) -> {
        let #(code, new_source_map) = generate_from_glx(code, ast)
        #(code, list.append(new_source_map, source_map))
      }
    }
  })
}

fn generate_from_glx(code: String, ast: Ast) -> #(String, SourceMap) {
  let mapping = #(length(code), ast.pos)
  case ast {
    ast.VoidElement(tag:, args:, ..) -> {
      let code = code <> "html." <> tag <> "(["
      let #(code, source_map) = generate_args(code, args)
      #(code <> "])", [mapping, ..source_map])
    }
    ast.ContainerElement(tag:, args:, children:, ..) -> {
      let code = code <> "html." <> tag <> "(["
      let #(code, args_source_map) = generate_args(code, args)
      let code = code <> "],"
      let #(code, children_source_map) = case children {
        [ast.Spread(children: child, ..)] -> generate_from_glx(code, child)
        _ -> {
          let #(code, source_map) =
            list.fold(children, #(code <> "[", [mapping]), fn(acc, child) {
              let #(code, source_map) = acc
              let #(code, new_mappings) = generate_from_glx(code, child)
              #(code <> ",", list.append(new_mappings, source_map))
            })
          #(code <> "]", source_map)
        }
      }
      let code = code <> ")"
      #(code, list.append(children_source_map, args_source_map))
    }

    ast.Spread(children:, ..) -> generate_from_glx(code <> "..", children)

    ast.Variable(name: v, ..) | ast.Call(def: v, ..) -> #(code <> v, [mapping])
    ast.Block(body:, ..) -> #(code <> "{" <> body <> "}", [mapping])
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
