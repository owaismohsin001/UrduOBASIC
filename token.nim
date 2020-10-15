from position import Position

let TT_NUMBER* = "NUMBER"
let TT_PLUS* = "PLUS"
let TT_MINUS* = "MINUS"
let TT_MUL* = "MUL"
let TT_DIV* = "DIV"
let TT_EQUALS* = "EQUALS"
let TT_RPAREN* = "RPAREN"
let TT_LPAREN* = "LPAREN"
let TT_RSQUARE* = "RSQUARE"
let TT_LSQUARE* = "LSQUARE"
let TT_RCURLY* = "RCURLY"
let TT_LCURLY* = "LCURLY"
let TT_DOT* = "DOT"
let TT_IDENTIFIER* = "IDENTIFIER"
let TT_KEYWORD* = "KEYWORD"
let TT_EE* = "EE"
let TT_LT* = "TT_LT"
let TT_LTE* = "TT_LTE"
let TT_GT* = "TT_GT"
let TT_GTE* = "TT_GTE"
let TT_POW* = "POW"
let TT_MOD* = "MOD"
let TT_COMMA* = "COMMA"
let TT_NEWLINE* = "NEWLINE"
let TT_ARROW* = "ARROW"
let TT_COLON* = "COLON"
let TT_STRING* = "STRING"
let TT_NE* = "NE"
let TT_EOF* = "EOF"
let TT_END* = "END"

let KEYWORDS* = [
    "RAKHO",
    "OR",
    "YA",
    "NAHI",
    "AGAR",
    "PHIR",
    "WARNAAGAR",
    "WARNA",
    "FOR",
    "SE",
    "TAK",
    "BADHAO",
    "JABKE",
    "KAM",
    "KHATAM",
    "WAPIS",
    "SHURU",
    "TODHO",
    "KAHO",
    "ABSE",
    "KOSHISH",
    "MUSHKIL",
    "BANAO"
]

type
  Token* = ref object of RootObj
    tokType*: string
    value*: string
    pos_start*: Position
    pos_end*: Position

proc matches*(this : Token, name : string, value : string) : bool =
  return ((this.tokType == name) and (this.value == value))

proc toString*(this : Token) : string =
  if this.value == "":
    return this.tokType
  else:
    return "[" & this.tokType & ":" & this.value & "]"
