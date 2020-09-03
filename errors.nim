from position import nil

type
  Error* = ref object of RootObj
    pos_start* : position.Position
    pos_end* : position.Position
    name*: string
    details*: string

  RTErrorObj* = ref object of Error
    context* : RootObj


proc IllegalCharacterError*(pos_start : position.Position, pos_end : position.Position, details : string) : Error =
  return Error(pos_start: pos_start, pos_end: pos_end, name: "Lafz Mana Hai", details: details)

proc ExpectredCharacterError*(pos_start : position.Position, pos_end : position.Position, details : string) : Error =
  return Error(pos_start: pos_start, pos_end: pos_end, name: "Lafz expect kiya tha", details: details)

proc InvalidSyntaxError*(pos_start : position.Position, pos_end : position.Position, details : string) : Error =
  return Error(pos_start: pos_start, pos_end: pos_end, name: "Syntax ki Mushkil", details: details)

proc noError*(pos : position.Position) : Error =
  return Error(pos_start: pos, pos_end: pos, name: "NoError", details: "")

proc as_string*(this: Error) : string =
  return this.name & ": " & this.details & "," & "File" & this.pos_start.fn & "in line number" & $(this.pos_start.ln + 1)
