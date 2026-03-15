import gleam/string

pub type LineInfo {
  LineInfo(index: Int, line: Int, column: Int)
}

pub type CodeMeta {
  CodeMeta(total_length: Int, line_ends: List(Int))
}

pub fn analyze_code(code: String) -> CodeMeta {
  let total_length = string.length(code)
  CodeMeta(total_length:, line_ends: [0, ..find_ends(code, total_length)])
}

fn find_ends(code: String, total_length: Int) -> List(Int) {
  let rest = string.drop_start(code, 1)
  case string.first(code) {
    Ok("\n") -> [
      total_length - string.length(code),
      ..find_ends(rest, total_length)
    ]
    Ok(_) -> find_ends(rest, total_length)
    Error(_) -> [total_length - string.length(code)]
  }
}

pub fn line_info(code: String, meta: CodeMeta) -> LineInfo {
  line_info_loop(meta.total_length - string.length(code), 0, meta.line_ends)
}

fn line_info_loop(index: Int, line: Int, ends: List(Int)) -> LineInfo {
  case ends {
    [] -> panic as "index not in file"
    [end, ..ends] if index > end -> line_info_loop(index, line + 1, ends)
    [end, ..] -> LineInfo(index:, line:, column: end - index)
  }
}
