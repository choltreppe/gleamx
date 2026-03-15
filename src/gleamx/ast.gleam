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
  Variable(pos: LineInfo, name: String)
  Block(pos: LineInfo, body: String)
  Call(pos: LineInfo, def: String)
}

pub type Arg {
  BoolArg(pos: LineInfo, name: String)
  LitArg(pos: LineInfo, name: String, value: String)
  ExprArg(pos: LineInfo, name: String, value: String)
}
