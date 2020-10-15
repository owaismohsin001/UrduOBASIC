from token import nil
from errors import nil
import tables
from position import nil

let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "e"]
let alphabets = [
                "a", "b", "c", "d", "e", "f", "g", "h", "$",
                "i", "j", "k", "l", "m", "n", "o", "p", "_",
                "q", "r", "s", "t", "u", "v", "w", "x", "y",
                "z", "A", "B", "C", "D", "E", "F", "G", "H",
                "I", "J", "K", "L", "M", "N", "O", "P", "Q",
                "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
                ]

var text = ""
var fn = "<module>"
var current_char = ""
var pos* = position.Position(idx: -1, ln: 0, col: -1, fn: fn, ftxt: text)
let init_pos* = position.copy(pos)
let no_error* = errors.noError(pos)

proc reset() =
  text = ""
  fn = "<module>"
  current_char = ""
  pos = position.Position(idx: -1, ln: 0, col: -1, fn: fn, ftxt: text)

proc advance() =
  position.advance(pos, current_char)
  current_char = if pos.idx < len(text): $text[pos.idx]
                else: token.TT_END

proc make_number() : token.Token =
  let pos_start = position.copy(pos)
  var number_str = ""
  var dot_count = 0
  var e_count = 0
  while digits.contains(current_char) or current_char == ".":
    if current_char == "." : dot_count+=1
    if current_char == "e": e_count+=1
    if dot_count == 2: break
    if e_count == 2: break
    if dot_count == 1 and e_count == 1: break
    number_str.add(current_char)
    advance()
  return token.Token(tokType: token.TT_NUMBER, value: number_str, pos_start: pos_start, pos_end: pos)

proc make_identifier() : token.Token =
  var id_str = ""
  let pos_start = position.copy(pos)
  while current_char != token.TT_END and ((current_char in alphabets) or (current_char in digits)):
    id_str &= current_char
    advance()
  let tok_type = if (id_str in token.KEYWORDS): token.TT_KEYWORD
                  else: token.TT_IDENTIFIER
  return token.Token(tokType: tok_type, value: id_str, pos_start: position.copy(pos_start), pos_end: position.copy(pos))

proc make_arrow_or_minus() : token.Token =
  var tok_type = token.TT_MINUS
  let pos_start = position.copy(pos)
  advance()
  if current_char == ">":
    advance()
    tok_type = token.TT_ARROW
  return token.Token(tokType: tok_type, value: "", pos_start: pos_start, pos_end: pos)

proc make_equals() : token.Token =
  var tok_type = token.TT_EQUALS
  let pos_start = position.copy(pos)
  advance()
  if current_char == "=":
    advance()
    tok_type = token.TT_EE
  return token.Token(tokType: tok_type, value: "", pos_start: pos_start, pos_end: pos)

proc make_less_than(): token.Token =
  var tok_type = token.TT_LT
  let pos_start = position.copy(pos)
  advance()
  if current_char == "=":
    advance()
    tok_type = token.TT_LTE
  return token.Token(tokType: tok_type, value: "", pos_start: pos_start, pos_end: pos)

proc make_greater_than(): token.Token =
  var tok_type = token.TT_GT
  let pos_start = position.copy(pos)
  advance()
  if current_char == "=":
    advance()
    tok_type = token.TT_GTE
  return token.Token(tokType: tok_type, value: "", pos_start: pos_start, pos_end: pos)

proc make_not_equals(): (token.Token, errors.Error) =
  let pos_start = position.copy(pos)
  advance()
  if current_char == "=":
    advance()
    return (token.Token(tokType: token.TT_NE, value: "", pos_start: pos_start, pos_end: pos), nil)
  advance()
  return (nil, errors.ExpectredCharacterError(pos_start, pos, "expect kiya tha '=', ! ke bad"))

proc make_string() : token.Token =
  var str = ""
  let pos_start = position.copy(pos)
  var escape_character = false
  advance()
  let escape_characters = {
      "n": '\n',
      "t": '\t'
  }.toTable()
  while current_char != token.TT_END and (current_char != "\"" or escape_character):
    if escape_character:
      str.add(escape_characters[current_char])
      escape_character = false
    else:
      if current_char == "\\":
        escape_character = true
      else:
        str.add(current_char)
    advance()
  advance()
  return token.Token(tokType: token.TT_STRING, value: str, pos_start: pos_start, pos_end: pos)

proc lex() : (seq[token.Token], errors.Error) =
  var tokens: seq[token.Token]
  tokens = @[]
  var error = errors.noError(pos)
  while current_char != token.TT_END:
    if [" ", "\t"].contains(current_char):
      advance()
    elif [";", "\n"].contains(current_char):
      tokens.add(token.Token(tokType: token.TT_NEWLINE, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == "+":
      tokens.add(token.Token(tokType: token.TT_PLUS, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == "-":
      tokens.add(make_arrow_or_minus())
    elif current_char == "*":
      tokens.add(token.Token(tokType: token.TT_MUL, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == "!":
      let (tok, err) = make_not_equals()
      if err != nil:
        return (@[], err)
      tokens.add(tok)
    elif current_char == "/":
      tokens.add(token.Token(tokType: token.TT_DIV, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == "^":
      tokens.add(token.Token(tokType: token.TT_POW, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == "%":
      tokens.add(token.Token(tokType: token.TT_MOD, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == ",":
      tokens.add(token.Token(tokType: token.TT_COMMA, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == ":":
      tokens.add(token.Token(tokType: token.TT_COLON, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == "(":
      tokens.add(token.Token(tokType: token.TT_RPAREN, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == ")":
      tokens.add(token.Token(tokType: token.TT_LPAREN, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == "[":
      tokens.add(token.Token(tokType: token.TT_RSQUARE, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == "]":
      tokens.add(token.Token(tokType: token.TT_LSQUARE, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == "{":
      tokens.add(token.Token(tokType: token.TT_RCURLY, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == "}":
      tokens.add(token.Token(tokType: token.TT_LCURLY, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == ".":
      tokens.add(token.Token(tokType: token.TT_DOT, value: "", pos_start: pos, pos_end: pos))
      advance()
    elif current_char == "=":
      tokens.add(make_equals())
    elif current_char == "\"":
      tokens.add(make_string())
    elif ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].contains(current_char):
      tokens.add(make_number())
    elif current_char == ">":
      tokens.add(make_greater_than())
    elif current_char == "<":
      tokens.add(make_less_than())
    elif alphabets.contains(current_char):
      tokens.add(make_identifier())
    elif alphabets.contains(current_char):
      tokens.add(make_identifier())
    else:
      tokens = @[]
      let pos_start = position.copy(pos)
      let error_char = current_char
      advance()
      let error = errors.IllegalCharacterError(pos_start, position.copy(pos), error_char)
      return (tokens, error)
  tokens.add(token.Token(tokType: token.TT_EOF, value: "", pos_start: pos, pos_end: pos))
  return (tokens, error)

proc input*(filename : string, ftext : string) : (seq[token.Token], errors.Error) =
  text = ftext
  fn = filename
  advance()
  let (tokens, err) = lex()
  if err.name != "NoError":
    return (tokens, err)
  reset()
  return (tokens, err)
