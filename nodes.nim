import sequtils
import strutils
from position import nil
from token import nil
from lexer import init_pos

type
  Node* = ref object of RootObj
    pos_start*: position.Position
    pos_end*: position.Position

  NumberNode* = ref object of Node
    value*: token.Token

  StringNode* = ref object of Node
    value*: string

  ProgramNode* = ref object of Node
    statements*: seq[Node]

  ListNode* = ref object of Node
    elements*: seq[Node]

  IncludeNode* = ref object of Node
    includes*: string

  UnaryOpNode* = ref object of Node
    unary_op*: token.Token
    factor*: Node

  BinOpNode* = ref object of Node
    left*: Node
    op*: token.Token
    right*: Node

  VarAssignNode* = ref object of Node
    identifier*: nodes.Node
    assign_type*: token.Token
    value*: Node

  VarAccessNode* = ref object of Node
    identifier*: token.Token

  IfNode* = ref object of Node
    cases*: seq[(nodes.Node, nodes.Node, bool)]
    else_case*: (Node, bool)

  WhileNode* = ref object of Node
    condition*: Node
    body*: Node
    should_return_null* : bool

  ForNode* = ref object of Node
    var_name*: token.Token
    start_value*: Node
    end_value* : Node
    step_value* : Node
    body* : Node
    should_return_null* : bool

  FuncDefNode* = ref object of Node
    var_name*: nodes.Node
    arg_names*: seq[token.Token]
    body* : Node
    should_auto_return* : bool

  ObjectNode* = ref object of Node
    decls*: Node
    objName*: string

  CallNode* = ref object of Node
    callee*: Node
    args*: seq[Node]

  TryNode* = ref object of Node
    try_block*: Node
    except_block*: Node
    may_return* : bool

  AssertNode* = ref object of Node
    assertion*: Node

  BreakNode* = ref object of Node

  ContinueNode* = ref object of Node

  ReturnNode* = ref object of Node
    returnValue*: Node

  EmptyNode* = ref object of Node

method toString*(this: Node): string {.base, locks: "unknown".} =
  quit "to override!"

method toString*(this: EmptyNode): string {.locks: "unknown".} =
  return "Empty"

method toString*(this: IncludeNode): string {.locks: "unknown".} =
  return "include " & this.includes

method toString*(this: NumberNode): string {.locks: "unknown".} =
  return this.value.value

method toString*(this: BinOpNode): string {.locks: "unknown".} =
  return "(" & toString(this.left) & ", " & token.toString(this.op) & ", " & toString(this.right) & ")"

method toString*(this: FuncDefNode): string {.locks: "unknown".} =
  let var_name = if isNil(this.var_name): toString(this.var_name)
                  else: "anonymous"
  return "fun " & var_name & "(" & this.arg_names.map(proc(x: token.Token) : string = x.value).join(", ") & ")" & "{" & toString(this.body) & "}"

method toString(this: CallNode): string {.locks: "unknown".} =
  return this.callee.toString() & "(" & this.args.map(proc(x: Node) : string = x.toString()).join(", ") & " )"

method toString*(this: IfNode): string {.locks: "unknown".} =
  return "It's a mess"

method toString(this: WhileNode): string {.locks: "unknown".} =
  return "while ()" & this.condition.toString() & ")" & "{ " & this.body.toString() & " }"

method toString*(this: ListNode): string {.locks: "unknown".} =
  return this.elements.map(proc (x: Node) : string = x.toString).join

method toString*(this: UnaryOpNode): string {.locks: "unknown".} =
  return "(" & token.toString(this.unary_op) & toString(this.factor) & ")"

method toString*(this: VarAssignNode): string {.locks: "unknown".} =
  return "(" & token.toString(this.assign_type) & " " & toString(this.identifier) & " = " & toString(this.value) & ")"

proc empty*(pos_start : position.Position, pos_end: position.Position): EmptyNode =
  return EmptyNode(pos_start: pos_start, pos_end : pos_end)

let emptyNode* = empty(init_pos, init_pos)
