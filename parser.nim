from token import nil
from errors import nil
from position import nil
from nodes import nil
import strutils
import parseResult
import sequtils

# Vars
var tokens: seq[token.Token]
var tok_idx: int
var next_tok_idx: int
var current_tok: token.Token
var next_tok : token.Token

proc update_current_tok() =
  if tok_idx >= 0 and tok_idx < len(tokens):
    current_tok = tokens[tok_idx]
  if next_tok_idx >= 0 and next_tok_idx < len(tokens):
    next_tok = tokens[next_tok_idx]

proc advance() =
  tok_idx += 1
  next_tok_idx += 1
  update_current_tok()

proc reverse(amount : int = 1) : token.Token =
  tok_idx -= amount
  update_current_tok()
  return current_tok

echo tokens.map(proc (x: token.Token) : string = token.toString(x)).join(", ")

# Procedure declarations
proc parse(): ParseResult
proc statements(): ParseResult
proc statement() : ParseResult
proc expression(): ParseResult
proc comp_expression(): ParseResult
proc arith_expression(): ParseResult
proc term(): ParseResult
proc factor(): ParseResult
proc power(): ParseResult
proc call(): ParseResult
proc atom(): ParseResult
proc if_expr_b_or_c(): ParseResult
proc if_expr_b(): ParseResult
proc if_expr_cases(case_keyword : string): ParseResult
proc if_expr() : ParseResult
proc while_expr() : ParseResult
proc for_expr() : ParseResult
proc list_expr() : ParseResult
proc try_expr() : ParseResult
proc func_def() : ParseResult
proc lhs() : ParseResult
proc identifier() : ParseResult
proc accessor(): ParseResult
proc class_expr(): ParseResult
proc bin_op(func_a: proc(): ParseResult, ops: seq[string], func_b: proc(): ParseResult, keyword_ops: seq[(string, string)]) : ParseResult

# implementation
proc parse() : ParseResult =
  let res = statements()
  if ((res.error.name == "NoError") and (current_tok.tokType != token.TT_EOF)):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "expected '+', '-', '*', or '/'"
    ))
  return res

proc bin_op(func_a: proc(): ParseResult, ops: seq[string], func_b: proc(): ParseResult, keyword_ops: seq[(string, string)]) : ParseResult =
  let res = newParseResult()
  var left = res.register(func_a())
  if res.error.name != "NoError": return res
  let pos_start = position.copy(current_tok.pos_start)
  while (ops.contains(current_tok.tokType)) or (keyword_ops.contains((current_tok.tokType, current_tok.value))):
    let op_tok = current_tok
    res.register_advancement()
    advance()
    let right = res.register(func_b())
    if res.error.name != "NoError": return res
    left = nodes.BinOpNode(left: left, op: op_tok, right: right, pos_start: pos_start, pos_end: current_tok.pos_end)
  return res.success(left)

proc statements() : ParseResult =
  let res = newParseResult()
  var statements : seq[nodes.Node]
  statements = @[]
  let pos_start = position.copy(current_tok.pos_start)
  var more_statements = true
  while (current_tok.tokType == token.TT_NEWLINE):
    res.register_advancement()
    advance()
  var statement : nodes.Node = res.register(statement())
  if res.error.name != "NoError": return res
  statements.add(statement)
  while true:
    var newline_count = 0
    while current_tok.tokType == token.TT_NEWLINE:
      res.register_advancement()
      advance()
      newline_count += 1
    if newline_count == 0:
      more_statements = false
    if not more_statements:
      break
    statement = res.try_register(statement())
    if statement of nodes.EmptyNode:
      discard reverse(res.to_reverse_count)
      more_statements = false
      continue
    statements.add(statement)
  let endRes = nodes.ListNode(elements: statements, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end))
  return res.success(endRes)

proc statement() : ParseResult =
  let res = newParseResult()
  let pos_start = position.copy(current_tok.pos_start)
  if token.matches(current_tok, token.TT_KEYWORD, "WAPIS"):
    res.register_advancement()
    advance()
    let expression = res.try_register(expression())
    if expression == nodes.emptyNode:
      discard reverse(res.to_reverse_count)
    return res.success(nodes.ReturnNode(returnValue: expression, pos_start: pos_start, pos_end: position.copy(current_tok.pos_start)))
  if token.matches(current_tok, token.TT_KEYWORD, "SHURU"):
    res.register_advancement()
    advance()
    return res.success(nodes.ContinueNode(pos_start: pos_start, pos_end: position.copy(current_tok.pos_start)))
  if token.matches(current_tok, token.TT_KEYWORD, "TODHO"):
    res.register_advancement()
    advance()
    return res.success(nodes.BreakNode(pos_start: pos_start, pos_end: position.copy(current_tok.pos_start)))
  if token.matches(current_tok, token.TT_KEYWORD, "KAHO"):
    res.register_advancement()
    advance()
    let assertion = res.register(expression())
    if res.error.name != "NoError": return res
    return res.success(nodes.AssertNode(assertion: assertion, pos_start: pos_start, pos_end: position.copy(current_tok.pos_start)))
  let expression = res.register(expression())
  if res.error.name != "NoError":
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expected 'RAKHO', 'AGAR', 'FOR', 'JABKE', 'KAM', Number, naam, '+', '-', '(', '[', 'TODHO', 'SHURU', 'WAPIS', 'KAHO' or 'NAHI'"
    ))
  return res.success(expression)

proc identifier() : ParseResult =
  let res = newParseResult()
  let pos_start = position.copy(current_tok.pos_start)
  if current_tok.tokType != token.TT_IDENTIFIER:
    return res.failure(errors.InvalidSyntaxError(
    current_tok.pos_start, current_tok.pos_end,
    "Expect kiya tha NAAM"
    ))
  let tok = current_tok
  res.register_advancement()
  advance()
  return res.success(nodes.VarAccessNode(identifier: tok, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end)))

proc lhs() : ParseResult =
  return bin_op(identifier, @[token.TT_DIV, token.TT_DOT], atom, @[("", ""), ("", "")])

proc expression() : ParseResult =
  let res = newParseResult()
  let pos_start = position.copy(current_tok.pos_end)
  var node : nodes.Node
  if (token.matches(current_tok, token.TT_KEYWORD, "RAKHO")) or (token.matches(current_tok, token.TT_KEYWORD, "ABSE")):
    let pos_start = position.copy(current_tok.pos_start)
    let assign_type = current_tok
    res.register_advancement()
    advance()
    let identifier = res.register(lhs())
    if current_tok.tokType != token.TT_EQUALS:
      return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha '='"
      ))
    res.register_advancement()
    advance()
    let value = res.register(expression())
    if res.error.name != "NoError": return res
    node = nodes.VarAssignNode(identifier: identifier, assign_type: assign_type, value: value, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end))
    return res.success(node)
  node = res.register(bin_op(comp_expression, @[], comp_expression, @[(token.TT_KEYWORD, "OR"), (token.TT_KEYWORD, "YA")]))
  if res.error.name != "NoError": return res
  if current_tok.tokType == token.TT_RPAREN:
    res.register_advancement()
    advance()
    var arg_nodes : seq[nodes.Node] = @[]
    if current_tok.tokType == token.TT_LPAREN:
      res.register_advancement()
      advance()
    else:
      arg_nodes.add(res.register(expression()))
      if res.error.name != "NoError":
        return res.failure(errors.InvalidSyntaxError(
          current_tok.pos_start, current_tok.pos_end,
          "Expect kiya tha ')', 'RAKHO', 'AGAR', 'FOR', 'JABKE', 'KAM', int, float, naam, '+', '-', '(', '[' ya 'NAHI'"
        ))
      while current_tok.tokType == token.TT_COMMA:
        res.register_advancement()
        advance()
        arg_nodes.add(res.register(expression()))
        if res.error.name != "NoError": return res
      if current_tok.tokType != token.TT_LPAREN:
        return res.failure(errors.InvalidSyntaxError(
          current_tok.pos_start, current_tok.pos_end,
          "Expect kiya tha ',' ya ')'"
        ))
      res.register_advancement()
      advance()
    return res.success(nodes.CallNode(callee: node, args: arg_nodes, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end)))
  return res.success(node)

proc comp_expression() : ParseResult =
  let res = newParseResult()
  let pos_start = position.copy(current_tok.pos_start)
  if token.matches(current_tok, token.TT_KEYWORD, "NAHI"):
    let unary_op = current_tok
    res.register_advancement()
    advance()
    let expression = res.register(comp_expression())
    if res.error.name != "NoError": return res
    return res.success(nodes.UnaryOpNode(unary_op: unary_op, factor: expression, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end)))
  return bin_op(arith_expression, @[token.TT_NE, token.TT_EE, token.TT_GTE, token.TT_GT, token.TT_LTE, token.TT_LT], arith_expression, @[("", ""), ("", "")])

proc arith_expression() : ParseResult =
  return bin_op(term, @[token.TT_MINUS, token.TT_PLUS], term, @[("", ""), ("", "")])

proc term() : ParseResult =
  return bin_op(factor, @[token.TT_MUL, token.TT_DIV], factor, @[("", ""), ("", "")])

proc factor(): ParseResult =
  let res = newParseResult()
  if current_tok.tokType == token.TT_MINUS:
    let pos_start = position.copy(current_tok.pos_start)
    let unary_op = current_tok
    res.register_advancement()
    advance()
    let factor = res.register(factor())
    if res.error.name != "NoError": return res
    return res.success(nodes.UnaryOpNode(unary_op: unary_op, factor: factor, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end)))
  return power()

proc power(): ParseResult =
  return bin_op(call, @[token.TT_POW, token.TT_MOD], factor, @[("", ""), ("", "")])

proc call(): ParseResult =
  let res = newParseResult()
  var accessor = res.register(accessor())
  let pos_start = position.copy(current_tok.pos_start)
  if res.error.name != "NoError": return res
  if current_tok.tokType == token.TT_RPAREN:
    res.register_advancement()
    advance()
    var arg_nodes : seq[nodes.Node] = @[]
    if current_tok.tokType == token.TT_LPAREN:
      res.register_advancement()
      advance()
    else:
      arg_nodes.add(res.register(expression()))
      if res.error.name != "NoError":
        return res.failure(errors.InvalidSyntaxError(
          current_tok.pos_start, current_tok.pos_end,
          "Expect kiya tha ')', 'RAKHO', 'AGAR', 'FOR', 'JABKE', 'KAM', int, float, naam, '+', '-', '(', '[' ya 'NAHI'"
        ))
      while current_tok.tokType == token.TT_COMMA:
        res.register_advancement()
        advance()
        arg_nodes.add(res.register(expression()))
        if res.error.name != "NoError": return res
      if current_tok.tokType != token.TT_LPAREN:
        return res.failure(errors.InvalidSyntaxError(
          current_tok.pos_start, current_tok.pos_end,
          "Expect kiya tha ',' ya ')'"
        ))
      res.register_advancement()
      advance()
    return res.success(nodes.CallNode(callee: accessor, args: arg_nodes, pos_start: pos_start, pos_end: position.copy(current_tok.pos_start)))
  return res.success(accessor)

proc accessor(): ParseResult =
  return bin_op(atom, @[token.TT_DOT], atom, @[("", ""), ("", "")])

proc atom(): ParseResult =
  let res = newParseResult()
  let pos_start = position.copy(current_tok.pos_start)
  if current_tok.tokType == token.TT_NUMBER:
    let num = current_tok
    res.register_advancement()
    advance()
    return res.success(nodes.NumberNode(value: num, pos_start: pos_start, pos_end: position.copy(num.pos_end)))
  elif current_tok.tokType == token.TT_STRING:
    let str = current_tok
    res.register_advancement()
    advance()
    return res.success(nodes.StringNode(value: str.value, pos_start: pos_start, pos_end: position.copy(str.pos_end)))
  elif current_tok.tokType == token.TT_RSQUARE:
    let list_expression = res.register(list_expr())
    if res.error.name != "NoError": return res
    return res.success(list_expression)
  elif token.matches(current_tok, token.TT_KEYWORD, "AGAR"):
    let if_expression = res.register(if_expr())
    if res.error.name != "NoError": return res
    return res.success(if_expression)
  elif token.matches(current_tok, token.TT_KEYWORD, "JABKE"):
    let while_expression = res.register(while_expr())
    if res.error.name != "NoError": return res
    return res.success(while_expression)
  elif token.matches(current_tok, token.TT_KEYWORD, "FOR"):
    let while_expression = res.register(for_expr())
    if res.error.name != "NoError": return res
    return res.success(while_expression)
  elif token.matches(current_tok, token.TT_KEYWORD, "BANAO"):
    let class_expression = res.register(class_expr())
    if res.error.name != "NoError": return res
    return res.success(class_expression)
  elif (current_tok.tokType == token.TT_IDENTIFIER and next_tok.tokType == token.TT_RCURLY) or (current_tok.tokType == token.TT_RCURLY):
    let pos_start = position.copy(current_tok.pos_start)
    var name: string
    if current_tok.tokType == token.TT_RCURLY:
      name = ""
    else:
      name = current_tok.value
      res.register_advancement()
      advance()
    res.register_advancement()
    advance()
    if current_tok.tokType == token.TT_LCURLY:
      res.register_advancement()
      advance()
      return res.success(nodes.ObjectNode(decls: nodes.ListNode(elements: @[], pos_start: pos_start, pos_end: position.copy(current_tok.pos_end)),
          objName: name, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end)
        )
      )
    let decls = res.register(statements())
    if res.error.name != "NoError": return res
    if current_tok.tokType != token.TT_LCURLY:
      return res.failure(errors.InvalidSyntaxError(
        current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha '}'"
      ))
    res.register_advancement()
    advance()
    return res.success(nodes.ObjectNode(decls: decls, objName: name, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end)))
  elif current_tok.tokType == token.TT_IDENTIFIER:
    let id = current_tok
    res.register_advancement()
    advance()
    return res.success(nodes.VarAccessNode(identifier: id, pos_start: pos_start, pos_end: position.copy(id.pos_end)))
  elif token.matches(current_tok, token.TT_KEYWORD, "KOSHISH"):
    let try_expression = res.register(try_expr())
    if res.error.name != "NoError": return res
    return res.success(try_expression)
  elif token.matches(current_tok, token.TT_KEYWORD, "KAM"):
    let function_expression = res.register(func_def())
    if res.error.name != "NoError": return res
    return res.success(function_expression)
  elif current_tok.tokType == token.TT_RPAREN:
    res.register_advancement()
    advance()
    let exp = res.register(expression())
    if res.error.name != "NoError": return res
    if current_tok.tokType != token.TT_LPAREN:
      return res.failure(errors.InvalidSyntaxError(
      pos_start, position.copy(current_tok.pos_end),
      "Expected ')'"
      ))
    res.register_advancement()
    advance()
    return res.success(exp)
  return res.failure(errors.InvalidSyntaxError(
  pos_start, position.copy(current_tok.pos_end),
  "Expected NUMBER"
  ))

proc while_expr() : ParseResult =
  let res = newParseResult()
  var body: nodes.Node
  if not token.matches(current_tok, token.TT_KEYWORD, "JABKE"):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha 'JABKE'"
    ))
  res.register_advancement()
  advance()
  let condition = res.register(expression())
  if res.error.name != "NoError": return res
  if not token.matches(current_tok, token.TT_KEYWORD, "PHIR"):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha 'PHIR'"
    ))
  res.register_advancement()
  advance()
  if current_tok.tokType == token.TT_NEWLINE:
    res.register_advancement()
    advance()
    body = res.register(statements())
    if res.error.name != "NoError": return res
    if not token.matches(current_tok, token.TT_KEYWORD, "KHATAM"):
      return res.failure(errors.InvalidSyntaxError(
        current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha 'KHATAM'"
      ))
    res.register_advancement()
    advance()
    return res.success(nodes.WhileNode(condition: condition, body: body, should_return_null: true))
  body = res.register(expression())
  if res.error.name != "NoError": return res
  return res.success(nodes.WhileNode(condition: condition, body: body, should_return_null: false))

proc class_expr(): ParseResult =
  let res = newParseResult()
  let pos_start = position.copy(current_tok.pos_start)
  if not token.matches(current_tok, token.TT_KEYWORD, "BANAO"):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha 'BANAO'"
    ))
  res.register_advancement()
  advance()
  var var_name : nodes.VarAccessNode
  if current_tok.tokType == token.TT_IDENTIFIER:
    var_name = cast[nodes.VarAccessNode](res.register(identifier()))
    if res.error.name != "NoError": return res
  else:
    var_name = nil
  var inher_name : nodes.Node
  if current_tok.tokType != token.TT_RPAREN:
      return res.failure(errors.InvalidSyntaxError(
        current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha naam ya '('"
      ))
  res.register_advancement()
  advance()
  var arg_name_toks : seq[token.Token] = @[]
  if current_tok.tokType == token.TT_IDENTIFIER:
    arg_name_toks.add(current_tok)
    res.register_advancement()
    advance()
    while current_tok.tokType == token.TT_COMMA:
      res.register_advancement()
      advance()
      if current_tok.tokType != token.TT_IDENTIFIER:
        return res.failure(errors.InvalidSyntaxError(
          current_tok.pos_start, current_tok.pos_end,
          "Expect kiya tha naam"
        ))
      arg_name_toks.add(current_tok)
      res.register_advancement()
      advance()
    if current_tok.tokType != token.TT_LPAREN:
      return res.failure(errors.InvalidSyntaxError(
        current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha naam ya ',' ya ')'"
      ))
  else:
    if current_tok.tokType != token.TT_LPAREN:
      return res.failure(errors.InvalidSyntaxError(
        current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha naam ya ',' ya ')'"
      ))
  res.register_advancement()
  advance()
  if current_tok.tokType == token.TT_COLON:
    res.register_advancement()
    advance()
    inher_name = res.register(expression())
    if res.error.name != "NoError": return res
  else:
    inher_name = nil 
  var body = cast[nodes.ListNode](res.register(statements()))
  if res.error.name != "NoError": return res
  if not token.matches(current_tok, token.TT_KEYWORD, "KHATAM"):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha 'KHATAM'"
    ))
  res.register_advancement()
  advance()
  let accessNode = nodes.Node(nodes.VarAccessNode(identifier: token.Token(tokType: token.TT_IDENTIFIER, value: "$", pos_start: body.pos_start, pos_end: body.pos_start)))
  let var_type = token.Token(tokType: token.TT_KEYWORD, value: "ABSE", pos_start: body.pos_start, pos_end: body.pos_start)
  let obj = nodes.ObjectNode(decls: nodes.ListNode(elements: @[], pos_start: pos_start, pos_end: position.copy(current_tok.pos_end)),
      objName: var_name.identifier.value, pos_start: body.pos_start, pos_end: body.pos_start
    )
  let ret_node = nodes.ReturnNode(returnValue: accessNode)
  let assignment = if inher_name == nil:
    @[cast[nodes.Node](nodes.VarAssignNode(identifier: accessNode, assign_type: var_type, value: obj))]
  else:
    @[cast[nodes.Node](nodes.VarAssignNode(identifier: accessNode, assign_type: var_type, value: inher_name))]
  body.elements.insert(assignment, 0)
  body.elements.add(ret_node)
  return res.success(nodes.FuncDefNode(var_name: var_name, arg_names: arg_name_toks, body: body,
    should_auto_return: false, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end))
  )

proc func_def() : ParseResult =
  let res = newParseResult()
  let pos_start = position.copy(current_tok.pos_start)
  var var_name : nodes.Node
  if not token.matches(current_tok, token.TT_KEYWORD, "KAM"):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha 'KAM'"
    ))
  res.register_advancement()
  advance()
  if current_tok.tokType == token.TT_IDENTIFIER:
    var_name = res.register(lhs())
    if res.error.name != "NoError": return res
  else:
    var_name = nil
  if current_tok.tokType != token.TT_RPAREN:
      return res.failure(errors.InvalidSyntaxError(
        current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha naam ya '('"
      ))
  res.register_advancement()
  advance()
  var arg_name_toks : seq[token.Token] = @[]
  if current_tok.tokType == token.TT_IDENTIFIER:
    arg_name_toks.add(current_tok)
    res.register_advancement()
    advance()
    while current_tok.tokType == token.TT_COMMA:
      res.register_advancement()
      advance()
      if current_tok.tokType != token.TT_IDENTIFIER:
        return res.failure(errors.InvalidSyntaxError(
          current_tok.pos_start, current_tok.pos_end,
          "Expect kiya tha naam"
        ))
      arg_name_toks.add(current_tok)
      res.register_advancement()
      advance()
    if current_tok.tokType != token.TT_LPAREN:
      return res.failure(errors.InvalidSyntaxError(
        current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha naam ya ',' ya ')'"
      ))
  else:
    if current_tok.tokType != token.TT_LPAREN:
      return res.failure(errors.InvalidSyntaxError(
        current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha naam ya ',' ya ')'"
      ))
  res.register_advancement()
  advance()
  var body : nodes.Node
  if current_tok.tokType == token.TT_ARROW:
    res.register_advancement()
    advance()
    body = res.register(expression())
    if res.error.name != "NoError": return res
    return res.success(nodes.FuncDefNode(var_name: var_name, arg_names: arg_name_toks, body: body,
      should_auto_return: true, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end))
    )
  if current_tok.tokType != token.TT_NEWLINE:
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha '->' YA Nai line"
    ))
  res.register_advancement()
  advance()
  body = res.register(statements())
  if res.error.name != "NoError": return res
  if not token.matches(current_tok, token.TT_KEYWORD, "KHATAM"):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha 'KHATAM'"
    ))
  res.register_advancement()
  advance()
  return res.success(nodes.FuncDefNode(var_name: var_name, arg_names: arg_name_toks, body: body,
    should_auto_return: false, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end))
  )

proc for_expr() : ParseResult =
  let res = newParseResult()
  if not token.matches(current_tok, token.TT_KEYWORD, "FOR"):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha 'FOR'"
    ))
  res.register_advancement()
  advance()
  if current_tok.tokType != token.TT_IDENTIFIER:
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha naam"
    ))
  let var_name = current_tok
  res.register_advancement()
  advance()
  if current_tok.tokType != token.TT_EQUALS:
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha '='"
      ))
  res.register_advancement()
  advance()
  let start_value = res.register(expression())
  if res.error.name != "NoError": return res
  if not token.matches(current_tok, token.TT_KEYWORD, "SE"):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha 'SE'"
    ))
  res.register_advancement()
  advance()
  let end_value = res.register(expression())
  if res.error.name != "NoError": return res
  if not token.matches(current_tok, token.TT_KEYWORD, "TAK"):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha 'TAK'"
    ))
  res.register_advancement()
  advance()
  var step_value : nodes.Node = nodes.emptyNode
  if token.matches(current_tok, token.TT_KEYWORD, "BADHAO"):
    res.register_advancement()
    advance()
    step_value = res.register(expression())
    if res.error.name != "NoError": return res
  if not token.matches(current_tok, token.TT_KEYWORD, "PHIR"):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha 'PHIR'"
    ))
  res.register_advancement()
  advance()
  var body : nodes.Node = nodes.emptyNode
  if current_tok.tokType == token.TT_NEWLINE:
    res.register_advancement()
    advance()
    body = res.register(statements())
    if res.error.name != "NoError": return res
    if not token.matches(current_tok, token.TT_KEYWORD, "KHATAM"):
      return res.failure(errors.InvalidSyntaxError(
        current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha 'KHATAM'"
      ))
    res.register_advancement()
    advance()
    return res.success(nodes.ForNode(var_name: var_name, start_value: start_value, end_value: end_value, step_value: step_value, body: body, should_return_null: true))
  body = res.register(expression())
  if res.error.name != "NoError": return res
  return res.success(nodes.ForNode(var_name: var_name, start_value: start_value, end_value: end_value, step_value: step_value, body: body, should_return_null: false))

proc if_expr_cases(case_keyword : string) : ParseResult =
  let res = newParseResult()
  var cases : seq[(nodes.Node, nodes.Node, bool)] = @[]
  var else_case : (nodes.Node, bool) = (nodes.emptyNode, false)
  if not token.matches(current_tok, token.TT_KEYWORD, case_keyword):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha '" & case_keyword & "'"
    ))
  res.register_advancement()
  advance()
  let condition = res.register(expression())
  if res.error.name != "NoError": return res
  if not token.matches(current_tok, token.TT_KEYWORD, "PHIR"):
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha 'PHIR'"
    ))
  res.register_advancement()
  advance()
  if current_tok.tokType == token.TT_NEWLINE:
    res.register_advancement()
    advance()
    let statements = res.register(statements())
    if res.error.name != "NoError": return res
    cases.add((condition, statements, true))

    if token.matches(current_tok, token.TT_KEYWORD, "KHATAM"):
      res.register_advancement()
      advance()
    else:
      let all_cases = res.register_if_cases(if_expr_b_or_c())
      if res.error.name != "NoError": return res
      let (new_cases, new_else_case) = all_cases
      cases = cases.concat(new_cases)
      else_case = new_else_case
  else:
      let expression = res.register(statement())
      if res.error.name != "NoError": return res
      cases.add((condition, expression, false))
      let all_cases = res.register_if_cases(if_expr_b_or_c())
      if res.error.name != "NoError": return res
      let (new_cases, new_else_case) = all_cases
      cases = cases.concat(new_cases)
      else_case = new_else_case
  return res.success_if_cases((cases, else_case))

proc if_expr_b() : ParseResult =
  return if_expr_cases("WARNAAGAR")

proc if_expr_c() : ParseResult =
  let res = newParseResult()
  var else_case : (nodes.Node, bool) = (nodes.emptyNode, false)
  if token.matches(current_tok, token.TT_KEYWORD, "WARNA"):
    res.register_advancement()
    advance()
    if current_tok.tokType == token.TT_NEWLINE:
      res.register_advancement()
      advance()
      let statements = res.register(statements())
      if res.error.name != "NoError": return res
      else_case = (statements, true)
      if token.matches(current_tok, token.TT_KEYWORD, "KHATAM"):
        res.register_advancement()
        advance()
      else:
        return res.failure(errors.InvalidSyntaxError(
          current_tok.pos_start, current_tok.pos_end,
          "Expect kiya tha 'KHATAM'"
          ))
    else:
      let expression = res.register(statement())
      if res.error.name != "NoError": return res
      else_case = (expression, false)
  return res.success_else_case(else_case)

proc if_expr_b_or_c(): ParseResult =
  let res = newParseResult()
  var cases: seq[(nodes.Node, nodes.Node, bool)] = @[]
  var else_case : (nodes.Node, bool) = (nodes.emptyNode, false)
  if token.matches(current_tok, token.TT_KEYWORD, "WARNAAGAR"):
    let all_cases = res.register_if_cases(if_expr_b())
    if res.error.name != "NoError": return res
    (cases, else_case) = all_cases
  else:
    else_case = res.register_else_case(if_expr_c())
    if res.error.name != "NoError": return res
  return res.success_if_cases((cases, else_case))

proc if_expr() : ParseResult =
  let res = newParseResult()
  let pos_start = position.copy(current_tok.pos_start)
  let all_cases = res.register_if_cases(if_expr_cases("AGAR"))
  if res.error.name != "NoError": return res
  let (cases, else_case) = all_cases
  return res.success(nodes.IfNode(cases: cases, else_case: else_case, pos_start: pos_start, pos_end: position.copy(current_tok.pos_end)))

proc list_expr() : ParseResult =
  let res = newParseResult()
  var element_nodes : seq[nodes.Node] = @[]
  let pos_start = position.copy(current_tok.pos_start)
  if current_tok.tokType != token.TT_RSQUARE:
    return res.failure(errors.InvalidSyntaxError(
      current_tok.pos_start, current_tok.pos_end,
      "Expect kiya tha '['"
    ))
  res.register_advancement()
  advance()
  if current_tok.tokType == token.TT_LSQUARE:
    res.register_advancement()
    advance()
  else:
    element_nodes.add(res.register(expression()))
    if res.error.name != "NoError":
      return res.failure(errors.InvalidSyntaxError(
        current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha ']', 'RAKHO', 'AGAR', 'FOR', 'JABKE', 'KAM', int, float, naam, '+', '-', '(' ya 'NAHI'"
      ))
    while current_tok.tokType == token.TT_COMMA:
      res.register_advancement()
      advance()
      element_nodes.add(res.register(expression()))
      if res.error.name != "NoError": return res
    if current_tok.tokType != token.TT_LSQUARE:
      return res.failure(errors.InvalidSyntaxError(
        current_tok.pos_start, current_tok.pos_end,
        "Expect kiya tha ',' ya ']'"
      ))
    res.register_advancement()
    advance()
  return res.success(nodes.ListNode(
    elements: element_nodes,
    pos_start: pos_start,
    pos_end: position.copy(current_tok.pos_end)
  ))

proc try_expr() : ParseResult =
  let res = newParseResult()
  let pos_start = position.copy(current_tok.pos_start)
  if not token.matches(current_tok, token.TT_KEYWORD, "KOSHISH"):
    return res.failure(errors.InvalidSyntaxError(
      pos_start, current_tok.pos_end,
      "Expected NUMBER, 'KOSHISH'"
    ))
  res.register_advancement()
  advance()
  if current_tok.tokType == token.TT_NEWLINE:
    let try_block = res.register(statements())
    if res.error.name != "NoError": return res
    if not token.matches(current_tok, token.TT_KEYWORD, "MUSHKIL"):
      return res.failure(errors.InvalidSyntaxError(
        pos_start, current_tok.pos_end,
          "Expected 'MUSHKIL'"
      ))
    res.register_advancement()
    advance()
    let except_block = res.register(statements())
    if res.error.name != "NoError": return res
    if not token.matches(current_tok, token.TT_KEYWORD, "KHATAM"):
      return res.failure(errors.InvalidSyntaxError(
        pos_start, current_tok.pos_end,
          "Expected 'KHATAM'"
        ))
    res.register_advancement()
    advance()
    return res.success(nodes.TryNode(try_block: try_block, except_block: except_block, may_return: false, pos_start: pos_start, pos_end: current_tok.pos_end))
  let try_block = res.register(statement())
  if res.error.name != "NoError": return res
  if not token.matches(current_tok, token.TT_KEYWORD, "MUSHKIL"):
    return res.failure(errors.InvalidSyntaxError(
      pos_start, current_tok.pos_end,
        "Expected 'MUSHKIL'"
      ))
  res.register_advancement()
  advance()
  let except_block = res.register(statement())
  if res.error.name != "NoError": return res
  return res.success(nodes.TryNode(try_block: try_block, except_block: except_block, may_return: true, pos_start: pos_start, pos_end: current_tok.pos_end))

proc input*(toks: seq[token.Token]): (nodes.Node, errors.Error) =
  tokens = toks
  tok_idx = -1
  next_tok_idx = 0
  advance()
  let parsed = parse()
  return (parsed.node, parsed.error)
