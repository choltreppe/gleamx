import argv
import fswalk
import gleam/io
import gleam/string
import gleam/yielder
import gleamx/codegen.{generate}
import gleamx/parser.{parse}
import simplifile.{read, write}

pub fn main() -> Nil {
  case argv.load().arguments {
    [] -> compile_all()
    ["compile", path] -> compile(path)
    _ -> panic as "invalid command"
  }
}

fn compile_all() -> Nil {
  fswalk.builder()
  |> fswalk.with_path("src")
  |> fswalk.walk
  |> yielder.map(fn(res) {
    let assert Ok(entry) = res as "failed to walk"
    entry
  })
  |> yielder.filter(fn(entry) {
    string.ends_with(entry.filename, ".gleamx") && !entry.stat.is_directory
  })
  |> yielder.each(fn(entry) { compile(entry.filename) })
}

fn compile(path: String) -> Nil {
  assert string.ends_with(path, ".gleamx")
  let assert Ok(code) = read(path)
  case parse(code) {
    Error(error) -> io.println(parser.error_to_string(error))
    Ok(chunks) ->
      case generate(chunks) {
        Error(error) -> io.println(parser.error_to_string(error))
        Ok(#(code, _source_map)) -> {
          let out_path = string.drop_end(path, 1)
          let _ = write(out_path, code)
          Nil
        }
      }
  }
}
