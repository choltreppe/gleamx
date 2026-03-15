import argv
import gleam/io
import gleam/string
import gleamx/codegen.{generate}
import gleamx/parser.{parse}
import simplifile.{read, write}

pub fn main() -> Nil {
  case argv.load().arguments {
    ["compile", path] -> compile(path)
    _ -> panic
  }
}

pub fn compile(path: String) -> Nil {
  assert string.ends_with(path, ".gleamx")
  let assert Ok(code) = read(path)
  case parse(code) {
    Error(error) -> io.println(parser.error_to_string(error))
    Ok(chunks) -> {
      let #(code, _source_map) = generate(chunks)
      let out_path = string.drop_end(path, 1)
      let _ = write(out_path, code)
      Nil
    }
  }
}
