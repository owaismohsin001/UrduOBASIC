from errors import nil
from nodes import nil
from lexer import init_pos, no_error

type
  ParseResult* = ref object of RootObj
    error*: errors.Error
    node*: nodes.Node
    advance_count*: int
    to_reverse_count*: int
    last_registered_advance_count*: int
    internal_else_case*: (nodes.Node, bool)
    if_cases*: (seq[(nodes.Node, nodes.Node, bool)], (nodes.Node, bool))

proc register_advancement*(this: ParseResult) =
  this.advance_count += 1

proc register*(this: ParseResult, res: ParseResult) : nodes.Node =
  this.last_registered_advance_count = res.advance_count
  this.advance_count += res.advance_count
  if res.error.name != "NoError":  this.error = res.error
  return res.node

proc register_else_case*(this: ParseResult, res: ParseResult) : (nodes.Node, bool) =
  this.last_registered_advance_count = res.advance_count
  this.advance_count += res.advance_count
  if res.error.name != "NoError":  this.error = res.error
  return res.internal_else_case

proc register_if_cases*(this: ParseResult, res: ParseResult) : (seq[(nodes.Node, nodes.Node, bool)], (nodes.Node, bool)) =
  this.last_registered_advance_count = res.advance_count
  this.advance_count += res.advance_count
  if res.error.name != "NoError":  this.error = res.error
  return res.if_cases

proc try_register*(this: ParseResult, res : ParseResult) : nodes.Node =
  if (res.error.name != "NoError"):
    this.to_reverse_count = res.advance_count
    return nodes.emptyNode
  else:
    return this.register(res)

proc success*(this: ParseResult, node: nodes.Node) : ParseResult =
  this.node = node
  return this

proc success_else_case*(this: ParseResult, else_case: (nodes.Node, bool)) : ParseResult =
  this.internal_else_case = else_case
  return this

proc success_if_cases*(this: ParseResult, if_cases: (seq[(nodes.Node, nodes.Node, bool)], (nodes.Node, bool))) : ParseResult =
  this.if_cases = if_cases
  return this

proc failure*(this: ParseResult, error: errors.Error) : ParseResult =
  if (this.error.name == "NoError") or (this.advance_count == 0):
    this.error = error
  return this

proc newParseResult*(): ParseResult =
  ParseResult(error: no_error, node: nodes.emptyNode, advance_count: 0, to_reverse_count: 0, last_registered_advance_count: 0,
    internal_else_case: (nodes.emptyNode, false), if_cases:(@[], (nodes.emptyNode, false))
  )
