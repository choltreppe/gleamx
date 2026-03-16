import gleamx/lineinfo.{type LineInfo}

pub type Chunk {
  GleamCode(pos: LineInfo, code: String)
  GlxCode(ast: Ast)
}

// offsets are relative to end-pos of glx block (so always negative)

pub type Ast {
  VoidElement(pos: LineInfo, tag: String, args: List(Arg))
  ContainerElement(
    pos: LineInfo,
    tag: String,
    args: List(Arg),
    children: List(Ast),
  )
  Spread(pos: LineInfo, children: Ast)
  CodeBlock(pos: LineInfo, gleam_code: String)
}

pub type Arg {
  BoolArg(pos: LineInfo, name: String)
  LitArg(pos: LineInfo, name: String, value: String)
  ExprArg(pos: LineInfo, name: String, value: String)
}

pub const void_elements = [
  "area",
  "base",
  "br",
  "col",
  "embed",
  "hr",
  "img",
  "input",
  "link",
  "meta",
  "param",
  "source",
  "track",
  "wbr",
]

pub const textual_elements = ["option", "script", "style", "textarea", "title"]

pub type SyntaxError {
  SyntaxError(pos: LineInfo, msg: String)
}
