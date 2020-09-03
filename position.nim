type
  Position* = ref object of RootObj
    idx*: int
    ln*: int
    col*: int
    fn*: string
    ftxt*: string

proc advance*(this : Position, current_char : string = "") : Position {.discardable.} =
  this.idx += 1
  this.col += 1
  if (current_char == "\n"):
    this.ln += 1
    this.col = 0
  return this

proc copy*(this : Position) : Position =
  return Position(idx: this.idx, ln: this.ln, col: this.col, fn: this.fn, ftxt: this.ftxt)
