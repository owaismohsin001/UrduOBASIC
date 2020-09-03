import tables
import sequtils
from position import nil
from lexer import init_pos
from lexer import nil
from parser import nil
from errors import nil
from nodes import nil
from token import nil
from math import  nil
import strutils
import osproc

# Context
type
  SymbolTable* = ref object of RootObj
    parent* : SymbolTable
    symbol_table* : TableRef[string, Value]
    consts* : seq[string]

  Context* = ref object of RootObj
    display_name* : string
    symbol_table* : SymbolTable
    parent* : Context
    parent_entry_pos* : position.Position

  ValueType* = enum
    Number
    String
    Lis
    Obj
    Function
    BuiltIn
    None

  Value* = ref object of RootObj
    case Type*: ValueType
      of Number:
        numValue*: float
        is_bool*: bool
        is_null*: bool
      of String: strValue*: string
      of Lis: lisValue*: ref seq[Value]
      of Obj:
        objName: string
        objValue: TableRef[string, Value]
      of Function:
        name: string
        body: nodes.Node
        arg_names: seq[string]
        scope: Context
        should_auto_return: bool
        built_in: bool
      of BuiltIn:
        builtin_name: string
        args: seq[string]
        fun: proc(exec_ctx: Context): Value
      of None: noneValue*: int
    pos_start*: position.Position
    pos_end*: position.Position
    context*: Context

# Runtime Error
type
  RuntimeError* = ref object of errors.Error
    context: Context

proc noRTError() : RunTimeError =
  return RuntimeError(name: "NoError", pos_start: init_pos, pos_end: init_pos, context: Context(), details: "")

proc newRTError(pos_start : position.Position, pos_end : position.Position, context : Context, details : string) : RunTimeError =
  return RuntimeError(name: "RTError", pos_start: pos_start, pos_end: pos_end, context: context, details: details)

# Special Value Methods
proc set_pos*(this: Value, pos_start : position.Position, pos_end : position.Position) : Value =
  this.pos_start = pos_start
  this.pos_end = pos_end
  return this

proc set_context*(this: Value, context : Context) : Value =
  this.context = context
  return this

# Forward Declarations
proc get_comparison_eq(this: Value, other: Value) : (Value, RuntimeError)
proc toString*(this: Value): string
proc `$`*(this: Value): string

# Special Value Initializations
let emptyValue* = Value(Type:None, noneValue: 0, pos_start: init_pos, pos_end: init_pos)
let emptyError* = noRTError()
let trueValue = Value(Type: Number, numValue: 1f, is_bool: true, is_null: false)
let falseValue = Value(Type: Number, numValue: 0f, is_bool: true, is_null: false)
let nullValue = Value(Type: Number, numValue: 0f, is_bool: false, is_null: true)

proc generate_traceback(this: RuntimeError) : string =
  var rs = ""
  var pos = this.pos_start
  var ctx = this.context
  while (ctx != nil):
    rs = "File: " & pos.fn & ", line: " & $(pos.ln+1) & " " & ctx.display_name & " main\n" & result
    pos = ctx.parent_entry_pos
    ctx = ctx.parent
  return "Error Traceback, (Most recent call last):\n" & result

proc as_string(this: RuntimeError) : string =
  var rs = this.generate_traceback()
  rs &= this.name & ":" & " " & this.details
  return rs

# SymbolTable Methods
proc setValue*(this: SymbolTable, name: string, value: Value) : (Value, bool) {.discardable.} =
  if name in this.consts:
    return (value, true)
  this.symbol_table[$name] = value
  return (value, false)

proc constSetValue*(this: SymbolTable, name: string, value: Value) : (Value, bool) =
  if name in this.consts:
    return (value, true)
  this.symbol_table[$name] = value
  this.consts.add(name)
  return (value, false)

proc getValue*(this: SymbolTable, name: string) : Value =
  var output: Value = emptyValue
  if name in this.symbol_table:
    output = this.symbol_table[name]
  elif this.parent != nil:
    output = this.parent.getValue(name)
  return output

proc newSymbolTable*(parent: SymbolTable) : SymbolTable =
  return SymbolTable(symbol_table: TableRef[string, Value](), consts: @[], parent: parent)


# Context Methods

proc copy*(this: Context) : Context =
  return Context(display_name: this.display_name, symbol_table: this.symbol_table, parent: this.parent, parent_entry_pos: this.parent_entry_pos)

type
  RTResult* = ref object of RootObj
    value*: Value
    error*: RuntimeError
    func_return_value*: Value
    loop_should_continue*: bool
    loop_should_break*: bool

# Value Methods

proc illegalOperation*(this: Value, other: Value) : RuntimeError =
  return newRTError(
    this.pos_start, this.pos_end,
    this.context,
    "Illegal Operation Error"
  )

proc add*(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type == Number and other.Type == Number:
    return (Value(Type: Number, numValue: this.numValue + other.numValue, is_bool: false, is_null: false).set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
  elif this.Type == String:
    if other.Type == Lis:
      return other.add(this)
    elif other.Type == String:
      return (Value(Type: String, strValue: this.strValue & other.strValue).set_context(this.context), emptyError)
  elif this.Type == Lis:
    var new_lis : ref seq[Value] = new seq[Value]
    new_lis[] = new_lis[].concat(this.lisValue[])
    new_lis[].add(other)
    return (Value(Type: Lis, lisValue: new_lis).set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
  return (emptyValue, this.illegalOperation(other))

proc subtract*(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type == Number and other.Type == Number:
    return (Value(Type: Number, numValue: this.numValue - other.numValue, is_bool: false, is_null: false).set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
  elif this.Type == Lis and other.Type == Number:
    let index = if other.numValue < 0f: len(this.lisValue[]) + other.numValue.toInt()
                else: other.numValue.toInt()
    var new_lis : ref seq[Value] = new seq[Value]
    new_lis[] = new_lis[].concat(this.lisValue[])
    if index < len(this.lisValue[]) and index >= 0:
      new_lis[].delete(index)
      return (Value(Type: Lis, lisValue: new_lis).set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
    else:
      return (emptyValue, newRTError(this.pos_start, this.pos_end, this.context, "Ye index nahi nikal sake kyu ke ye list me mila hi nahi"))
  return (emptyValue, this.illegalOperation(other))

proc multiply*(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type == Number and other.Type == Number:
    return (Value(Type: Number, numValue: this.numValue * other.numValue, is_bool: false, is_null: false).set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
  elif this.Type == String and other.Type == Number:
    return (Value(Type: String, strValue: this.strValue.repeat(int(other.numValue))).set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
  elif this.Type == String and other.Type == Number:
    let to_return = $this.strValue[int(other.numValue)]
    return (Value(Type: String, strValue: to_return).set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
  elif this.Type == Lis and other.Type == Lis:
    var new_lis : ref seq[Value] = new seq[Value]
    new_lis[] = new_lis[].concat(this.lisValue[])
    new_lis[] = new_lis[].concat(other.lisValue[])
    return (Value(Type: Lis, lisValue: new_lis).set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
  return (emptyValue, this.illegalOperation(other))

proc divide*(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type == Number and other.Type == Number:
    if other.numValue == 0f:
      return (emptyValue, newRTError(
        this.pos_start, this.pos_end,
        this.context,
        "Division by zero"
      ))
    return (Value(Type: Number, numValue: this.numValue / other.numValue, is_bool: false, is_null: false).set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
  elif this.Type == Lis and other.Type == Number:
    let index = if other.numValue < 0f: len(this.lisValue[]) + other.numValue.toInt()
                else: other.numValue.toInt()
    if index < len(this.lisValue[]) and index >= 0:
      return (this.lisValue[index], emptyError)
    else:
      return (emptyValue, newRTError(this.pos_start, this.pos_end, this.context, "Ye number ki cheez list me mila hi nahi"))
  elif this.Type == Obj and other.Type == String:
    if not this.objValue.contains(other.strValue):
      return (emptyValue, newRTError(
        this.pos_start, other.pos_start,
        this.context,
        $this & " mein '" & other.strValue & "' nam ki koi cheez nahi mili"
      ))
    return (this.objValue[other.strValue].set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
  elif this.Type == String and other.Type == Number:
    let index = if other.numValue < 0f: len(this.lisValue[]) + other.numValue.toInt()
                else: other.numValue.toInt()
    if index < len(this.lisValue[]) and index >= 0:
      return (Value(Type: String, strValue: $this.strValue[index]).set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
    else:
      return (emptyValue, newRTError(this.pos_start, this.pos_end, this.context, "Ye number ki cheez string me mili hi nahi"))
  return (emptyValue, this.illegalOperation(other))

proc power*(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type == Number and other.Type == Number:
    return (Value(Type: Number, numValue: math.pow(this.numValue, other.numValue), is_bool: false, is_null: false).set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
  return (emptyValue, this.illegalOperation(other))

proc modulus*(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type == Number and other.Type == Number:
    return (Value(Type: Number, numValue: math.floorMod(this.numValue, other.numValue), is_bool: false, is_null: false)
    .set_pos(this.pos_start, other.pos_end).set_context(this.context), emptyError)
  return (emptyValue, this.illegalOperation(other))

proc truth_of_list(this: Value, other: Value) : bool =
  var truth = 0
  if len(other.lisValue[]) != len(this.lisValue[]): return false
  if not (other.Type == Lis): return false
  for index, element in this.lisValue[]:
    if (0 <= index) and (index < len(other.lisValue[])):
      let call = this.lisValue[index].get_comparison_eq(other.lisValue[index])[0]
      if call.Type != None:
        if call.numValue == 1f:
            truth += 1
        else:
            break
      else:
          break
  return (truth == len(this.lisValue[])) and (truth == len(this.lisValue[]))

proc get_comparison_eq(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type != other.Type:
    return (falseValue, emptyError)
  elif this.Type == Number and other.Type == Number:
    return ((if this.numValue == other.numValue: trueValue
    else: falseValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)
  elif this.Type == Lis and other.Type == Lis:
    return ((if this.truth_of_list(other): trueValue
    else: falseValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)
  elif this.Type == String and other.Type == String:
    return ((if this.strValue == other.strValue: trueValue
    else: falseValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)
  else:
    return (falseValue, emptyError)

proc get_comparison_ne(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type == other.Type:
    return (falseValue, emptyError)
  elif this.Type == Number and other.Type == Number:
    return ((if this.numValue == other.numValue: falseValue
    else: trueValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)
  elif this.Type == Lis and other.Type == Lis:
    return ((if this.truth_of_list(other): falseValue
    else: trueValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)
  elif this.Type == String and other.Type == String:
    return ((if this.strValue == other.strValue: falseValue
    else: trueValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)
  else:
    return (trueValue, emptyError)

proc get_comparison_lt(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type != other.Type:
    return (falseValue, emptyError)
  elif this.Type == Number:
    return ((if this.numValue < other.numValue: trueValue
    else: falseValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)
  else:
    return (falseValue, emptyError)

proc get_comparison_gt(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type != other.Type:
    return (falseValue, emptyError)
  elif this.Type == Number:
    return ((if this.numValue > other.numValue: trueValue
    else: falseValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)
  else:
    return (falseValue, emptyError)

proc get_comparison_lte(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type != other.Type:
    return (falseValue, emptyError)
  elif this.Type == Number:
    return ((if this.numValue <= other.numValue: trueValue
    else: falseValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)
  else:
    return (falseValue, emptyError)

proc get_comparison_gte(this: Value, other: Value) : (Value, RuntimeError) =
  if this.Type != other.Type:
    return (falseValue, emptyError)
  elif this.Type == Number:
    return ((if this.numValue >= other.numValue: trueValue
    else: falseValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)
  else:
    return (falseValue, emptyError)

proc is_true(this: Value) : bool =
  if this.Type == Number:
    return this.numValue != 0f
  elif this.Type == String:
    return len(this.strValue) > 0
  elif this.Type == Lis:
    return len(this.lisValue[]) > 0
  return false

proc ored_by(this: Value, other: Value) : (Value, RuntimeError) =
  return ((if this.is_true() or other.is_true(): trueValue
  else: falseValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)

proc anded_by(this: Value, other: Value) : (Value, RuntimeError) =
  return ((if this.is_true() and other.is_true(): trueValue
  else: falseValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)

proc notted(this: Value) : (Value, RuntimeError) =
  return ((if this.is_true(): falseValue
  else: trueValue).set_pos(this.pos_start, this.pos_end).set_context(this.context), emptyError)

proc newRTResult() : RTResult
proc register(this: RTResult, res : RTResult) : Value
proc success(this: RTResult, value : Value) : RTResult
proc failure(this: RTResult, error : RuntimeError) : RTResult
proc should_return(this: RTResult) : bool

method visit(node: nodes.Node, context: Context) : RTResult {.base, locks: "unknown".}

proc generate_new_context(this: Value) : Context =
  let new_context = Context(display_name: this.name, parent: this.scope, parent_entry_pos: this.pos_start)
  new_context.symbol_table = newSymbolTable(new_context.parent.symbol_table)
  return new_context

proc check_args(this: Value, name: string, arg_names: seq[string], args: seq[Value]) : RTResult =
  let res = newRTResult()
  if len(args)>len(arg_names):
    return res.failure(newRTError(
      this.pos_start, this.pos_end,
      this.context,
      $(len(args) - len(arg_names)) & " too many args passed into '" & name & "'"
    ))
  elif len(args)<len(arg_names):
    return res.failure(newRTError(
      this.pos_start, this.pos_end,
      this.context,
      $(len(args) - len(arg_names)) & " too many args passed into '" & name & "'"
    ))
  return res.success(nullValue)

proc populate_args(this: Value, arg_names: seq[string], args: seq[Value], exec_ctx: Context) =
  for i, _ in args:
    let arg_name = arg_names[i]
    let arg_value = args[i]
    discard arg_value.set_context(exec_ctx)
    exec_ctx.symbol_table.setValue(arg_name, arg_value)

proc check_and_populate_args(this: Value, name: string, arg_names: seq[string], args: seq[Value], exec_ctx: Context) : RTResult =
  let res = newRTResult()
  discard res.register(this.check_args(name, arg_names, args))
  if res.should_return(): return res
  this.populate_args(arg_names, args, exec_ctx)
  return res.success(nullValue)

proc execute(this: Value, args: seq[Value]) : RTResult =
  let res = newRTResult()
  var ret_value : Value
  if this.Type == BuiltIn:
    let exec_ctx = Context(display_name: this.builtin_name, symbol_table: nil, parent: this.context, parent_entry_pos: this.pos_start)
    exec_ctx.symbol_table = newSymbolTable(nil)
    discard res.register(this.check_and_populate_args(this.builtin_name, this.args, args, exec_ctx))
    if res.should_return(): return res
    try:
      return res.success(this.fun(exec_ctx))
    except OSError as e:
      return res.failure(newRTError(
        this.pos_start, this.pos_end,
        exec_ctx,
        e.msg
      ))
  elif this.Type == Function:
    let exec_ctx = this.generate_new_context()
    discard res.register(this.check_and_populate_args(this.name, this.arg_names, args, exec_ctx))
    if res.should_return(): return res
    let value = res.register(visit(this.body, exec_ctx))
    if res.should_return() and res.func_return_value == emptyValue: return res
    if this.should_auto_return:
      ret_value = value
    elif res.func_return_value != emptyValue:
      ret_value = res.func_return_value
    else:
      ret_value = nullValue
  else:
    return res.failure(this.illegalOperation(this))
  return res.success(ret_value)

proc updateIndex(this: Value, index: Value, value_to_assign: Value) : RTResult =
  let res = newRTResult()
  if this.Type == Lis:
    if index.Type != Number:
      return res.failure(newRTError(
        index.pos_start, index.pos_end,
        this.context,
        "Index sirf number ho sakta hai"
      ))
    let arr_index = if index.numValue < 0f: len(this.lisValue[]) + index.numValue.toInt()
                else: index.numValue.toInt()
    if arr_index < len(this.lisValue[]) and arr_index >= 0:
      this.lisValue[arr_index] = value_to_assign
      return res.success(this)
    return res.failure(newRTError(
      index.pos_start, index.pos_end,
      this.context,
      "Ye index list mein nahi hai"
    ))
  elif this.Type == Obj:
    if index.Type != String:
      return res.failure(newRTError(
        index.pos_start, index.pos_end,
        this.context,
        "Index sirf string ho sakti hai"
      ))
    let obj_index = index.strValue
    this.objValue[obj_index] = value_to_assign
    return res.success(this)
  return res.failure(newRTError(
    index.pos_start, index.pos_end,
    this.context,
    "Sirf List ka index badal sakte hain"
  ))

proc copy*(this: Value) : Value =
  if this.Type == Number:
    return Value(Type: Number, numValue: this.numValue, is_bool: this.is_bool, is_null: this.is_null).set_pos(this.pos_start, this.pos_end).set_context(this.context)
  elif this.Type == Lis:
    return Value(Type: Lis, lisValue: this.lisValue).set_pos(this.pos_start, this.pos_end).set_context(this.context)
  elif this.Type == String:
    return Value(Type: String, strValue: this.strValue).set_pos(this.pos_start, this.pos_end).set_context(this.context)
  elif this.Type == Obj:
    return Value(Type: Obj, objName: this.objName, objValue: this.objValue).set_pos(this.pos_start, this.pos_end).set_context(this.context)
  elif this.Type == Function:
    return Value(Type: Function, name: this.name, body: this.body, arg_names: this.arg_names, scope: this.scope,
                                should_auto_return: this.should_auto_return, built_in: this.built_in
                             ).set_pos(this.pos_start, this.pos_end).set_context(this.context)
  elif this.Type == BuiltIn:
    return Value(Type: BuiltIn, builtin_name: this.builtin_name, args: this.args, fun: this.fun)
  echo "No copy method defined"
  return Value().set_pos(this.pos_start, this.pos_end)

proc toString*(this: Value): string =
  if this.Type == Number:
    if this.is_bool:
      return (if this.is_true(): "sahi"
      else: "galat")
    elif this.is_null:
      return "khali"
    return $this.numValue
  elif this.Type == Lis:
    let sequence = this.lisValue[].map(proc (x: Value): string = x.toString())
    return "[" & sequence.join(", ") & "]"
  elif this.Type == String:
    return this.strValue
  elif this.Type == Obj:
    return if this.objName == "": "<Cheezen>"
           else: "<" & this.objName & ">"
  elif this.Type == Function:
    return this.name & "(" & this.arg_names.join(", ") & ")"
  return "Value"

proc `$`*(this: Value) : string = this.toString()

# Runtime Result Methods
proc newRTResult() : RTResult =
  return RTResult(value: emptyValue, error: emptyError, func_return_value: emptyValue, loop_should_continue: false, loop_should_break: false)

proc reset(this: RTResult) =
  this.value = emptyValue
  this.error = emptyError
  this.func_return_value = emptyValue
  this.loop_should_continue = false
  this.loop_should_break = false

proc register(this: RTResult, res : RTResult) : Value =
  if res.error.name != "NoError": this.error = res.error
  this.loop_should_continue = res.loop_should_continue
  this.func_return_value = res.func_return_value
  this.loop_should_break = res.loop_should_break
  return res.value

proc success(this: RTResult, value : Value) : RTResult =
  this.reset()
  this.value = value
  return this

proc success_return(this: RTResult, value : Value) : RTResult =
  this.reset()
  this.func_return_value = value
  return this

proc success_break(this: RTResult) : RTResult =
  this.reset()
  this.loop_should_break = true
  return this

proc success_continue(this: RTResult) : RTResult =
  this.reset()
  this.loop_should_continue = true
  return this

proc failure(this: RTResult, error : RuntimeError) : RTResult =
  this.reset()
  this.error = error
  return this

proc should_return(this: RTResult) : bool =
  return (
      this.error.name != "NoError" or
      this.func_return_value.Type != None or
      this.loop_should_continue != false or
      this.loop_should_break != false
  )

proc update(context: Context, accessor: nodes.Node, value_to_assign: var Value): RTResult =
  let res = newRTResult()
  if accessor of nodes.VarAccessNode:
    return res.success(value_to_assign)

  let binOpNode = cast[nodes.BinOpNode](accessor)

  let lhs = res.register(visit(binOpNode.left, context))
  if res.should_return(): return res

  if accessor of nodes.BinOpNode:
    proc procforsakeofit() : Value =
      return res.register(visit(nodes.StringNode(value: cast[nodes.VarAccessNode](binOpNode.right).identifier.value, pos_start: binOpNode.pos_start, pos_end: binOpNode.right.pos_end), context))
    let index = if binOpNode.op.tokType == token.TT_DOT: procforsakeofit()
                else: res.register(visit(cast[nodes.BinOpNode](accessor).right, context))
    if res.should_return(): return res
    value_to_assign = res.register(lhs.updateIndex(index, value_to_assign))
    if res.should_return(): return res
  return update(context, cast[nodes.BinOpNode](accessor).left, value_to_assign)

# Visitor

method visit(node: nodes.Node, context: Context) : RTResult {.base, locks: "unknown".} =
  quit "You aren't supposed to be here!"

method visit(node: nodes.NumberNode, context: Context) : RTResult {.locks: "unknown".} =
  return newRTResult().success(Value(Type:Number, numValue: parseFloat(node.value.value), is_bool: false, is_null: false).set_pos(node.pos_start, node.pos_end).set_context(context))

method visit(node: nodes.StringNode, context: Context) : RTResult {.locks: "unknown".} =
  return newRTResult().success(Value(Type:String, strValue: node.value).set_pos(node.pos_start, node.pos_end).set_context(context))

method visit(node: nodes.ListNode, context: Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  var elements : ref seq[Value] = new seq[Value]
  for element in node.elements:
    elements[].add(res.register(visit(element, context)))
    if res.should_return(): return res
  return res.success(Value(Type: Lis, lisValue: elements).set_pos(node.pos_start, node.pos_end).set_context(context))

method visit(node: nodes.ObjectNode, context: Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  let new_context = Context(display_name: node.objName, parent: context, parent_entry_pos: node.pos_start)
  new_context.symbol_table = newSymbolTable(new_context.parent.symbol_table)
  let obj = res.register(visit(node.decls, new_context))
  if res.should_return(): return res
  let objEnv = obj.context.symbol_table.symbol_table
  let name = node.objName
  return res.success(Value(Type: Obj, objValue: objEnv, objName: name).set_pos(node.pos_start, node.pos_end).set_context(context))

method visit(node: nodes.UnaryOpNode, context: Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  let factor = res.register(visit(node.factor, context))
  if res.should_return(): return res
  var rs: Value
  var error : RuntimeError
  if node.unary_op.tokType == token.TT_PLUS:
      let other = Value(Type: Number, numValue: 1f, is_bool: false, is_null: false).set_pos(node.pos_start, node.pos_end)
      (rs, error) = factor.multiply(other)
  elif node.unary_op.tokType == token.TT_MINUS:
      let other = Value(Type: Number, numValue: -1f, is_bool: false, is_null: false).set_pos(node.pos_start, node.pos_end)
      (rs, error) = factor.multiply(other)
  elif token.matches(node.unary_op, token.TT_KEYWORD, "NAHI"):
      (rs, error) = factor.notted()
  else:
    rs = emptyValue
    error = illegalOperation(factor, nil)
  if error.name != "NoError": return res.failure(error)
  return res.success(rs.set_pos(node.pos_start, node.pos_end).set_context(context))


method visit(node: nodes.BinOpNode, context: Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  let left = res.register(visit(node.left, context))
  if res.should_return(): return res
  var rs: Value
  var error : RuntimeError
  if node.op.tokType == token.TT_PLUS:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.add(right)
  elif node.op.tokType == token.TT_MINUS:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.subtract(right)
  elif node.op.tokType == token.TT_MUL:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.multiply(right)
  elif node.op.tokType == token.TT_DIV:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.divide(right)
  elif node.op.tokType == token.TT_DOT:
    let right = res.register(visit(nodes.StringNode(value: cast[nodes.VarAccessNode](node.right).identifier.value, pos_start: left.pos_start, pos_end: node.right.pos_end), context))
    if res.should_return(): return res
    (rs, error) = left.divide(right)
  elif node.op.tokType == token.TT_POW:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.power(right)
  elif node.op.tokType == token.TT_MOD:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.modulus(right)
  elif node.op.tokType == token.TT_GT:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.get_comparison_gt(right)
  elif node.op.tokType == token.TT_GTE:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.get_comparison_gte(right)
  elif node.op.tokType == token.TT_LT:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.get_comparison_lt(right)
  elif node.op.tokType == token.TT_LTE:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.get_comparison_lte(right)
  elif (node.op.tokType == token.TT_KEYWORD) and (node.op.value == "OR"):
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.anded_by(right)
  elif (node.op.tokType == token.TT_KEYWORD) and (node.op.value == "YA"):
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.ored_by(right)
  elif node.op.tokType == token.TT_EE:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.get_comparison_eq(right)
  elif node.op.tokType == token.TT_NE:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    (rs, error) = left.get_comparison_ne(right)
  else:
    let right = res.register(visit(node.right, context))
    if res.should_return(): return res
    rs = emptyValue
    error = illegalOperation(left, right)
  if error.name != "NoError": return res.failure(error)
  return res.success(rs.set_pos(node.pos_start, node.pos_end).set_context(context))


method visit(node: nodes.VarAssignNode, context: Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  var var_name : string
  let var_value = res.register(visit(node.value, context))
  if res.should_return(): return res
  if node.identifier of nodes.VarAccessNode:
    var_name = cast[nodes.VarAccessNode](node.identifier).identifier.value
  else:
    var rhs = var_value
    discard res.register(update(context, node.identifier, rhs))
    if res.should_return(): return res
    return res.success(var_value)
  let var_type = node.assign_type.value
  var ret_value: Value
  var is_const: bool
  if var_type == "ABSE":
      (ret_value, is_const) = context.symbol_table.constSetValue(var_name, var_value)
  else:
      (ret_value, is_const) = context.symbol_table.setValue(var_name, var_value)
  if is_const:
    return res.failure(newRTError(
      node.pos_start, node.pos_end,
      context,
      "Mustakil value change nahi kar sakte"
    ))
  return res.success(var_value)

method visit(node: nodes.VarAccessNode, context: Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  let identifier = node.identifier.value
  let value = context.symbol_table.getValue(identifier)
  if value.Type == None:
    return res.failure(newRTError(
      node.pos_start, node.pos_end,
      context,
      "'" & identifier & "'" & " defined nahi hai,"
    ))
  let copied_value = value.copy().set_pos(node.pos_start, node.pos_end).set_context(context)
  return res.success(copied_value)

method visit(node: nodes.WhileNode, context: Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  var elements : ref seq[Value] = new seq[Value]
  while true:
    let condition = res.register(visit(node.condition, context))
    if res.should_return(): return res
    if not condition.is_true(): break
    let value = res.register(visit(node.body, context))
    if res.should_return() and res.loop_should_continue == false and res.loop_should_break == false: return res
    if res.loop_should_continue: continue
    if res.loop_should_break: break
    elements[].add(value)
  return res.success(if node.should_return_null: nullValue.set_pos(node.pos_start, node.pos_end).set_context(context)
                    else: Value(Type: Lis, lisValue: elements).set_pos(node.pos_start, node.pos_end).set_context(context))

method visit(node: nodes.IfNode, context: Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  for (condition, expression, should_return_null) in node.cases:
    let condition_value = res.register(visit(condition, context))
    if res.should_return(): return res
    if condition_value.is_true():
      let expression_value = res.register(visit(expression, context))
      if res.should_return(): return res
      return res.success(if should_return_null: nullValue.set_pos(node.pos_start, node.pos_end).set_context(context)
                          else: expression_value)
  if node.else_case != (nodes.emptyNode, false):
    let (expression, should_return_null) = node.else_case
    let else_value = res.register(visit(expression, context))
    if res.should_return(): return res
    return res.success(if should_return_null: nullValue.set_pos(node.pos_start, node.pos_end).set_context(context)
                        else: else_value)
  return res.success(nullValue.set_pos(node.pos_start, node.pos_end).set_context(context))

method visit(node : nodes.ForNode, context : Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  let elements : ref seq[Value] = new seq[Value]
  let start_value = res.register(visit(node.start_value, context))
  if res.should_return(): return res
  let end_value = res.register(visit(node.end_value, context))
  if res.should_return(): return res
  var step_value : Value
  if not (node.step_value of nodes.EmptyNode):
    step_value = res.register(visit(node.step_value, context))
    if res.should_return(): return res
  else:
    step_value = Value(Type: Number, numValue: 1, is_bool: false, is_null: false)
  if end_value.Type != Number:
    return res.failure(newRTError(
      node.pos_start, node.pos_end,
      context,
      "TAK ki value sirf number ho sakti hai"
    ))
  var i = start_value.numValue
  var condition : proc() : bool
  if step_value.numValue >= 0:
    condition = proc() : bool = i < end_value.numValue
  else:
    condition = proc() : bool = i > end_value.numValue
  while condition():
      discard context.symbol_table.setValue(node.var_name.value, Value(Type: Number, numValue: i, is_bool: false, is_null: false))
      i += step_value.numValue
      let value = res.register(visit(node.body, context))
      if res.should_return() and res.loop_should_continue == false and res.loop_should_break == false: return res
      if res.loop_should_continue:
          continue
      if res.loop_should_break:
          break
      if not node.should_return_null:
        elements[].add(value)
  return res.success(if (node.should_return_null): nullValue
  else: Value(Type: Lis, lisValue: elements).set_context(context).set_pos(node.pos_start, node.pos_end))

method visit(node : nodes.FuncDefNode, context : Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  var func_name : string
  if isNil(node.var_name):
    func_name = "<anonymous>"
  elif node.var_name of nodes.VarAccessNode:
    func_name = cast[nodes.VarAccessNode](node.var_name).identifier.value
  else:
    func_name = "<anonymous>"
  let body = node.body
  let arg_names = node.arg_names.map(proc(x: token.Token) : string = x.value)
  let func_value = Value(Type: Function, name: func_name, body: body, arg_names: arg_names, scope: context.copy(),
                              should_auto_return: node.should_auto_return, built_in: false
                           ).set_context(context).set_pos(node.pos_start, node.pos_end)
  if (not isNil(node.var_name)) and node.var_name of nodes.VarAccessNode:
    discard context.symbol_table.setValue(func_name, func_value)
  else:
    var rhs = func_value
    discard res.register(update(context, node.var_name, rhs))
    if res.should_return(): return res
    return res.success(func_value)
  return res.success(func_value)


method visit(node : nodes.CallNode, context : Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  var args : seq[Value] = @[]
  var value_to_call = res.register(visit(node.callee, context))
  if res.should_return(): return res
  value_to_call = value_to_call.copy().set_pos(node.pos_start, node.pos_end)
  for arg in node.args:
    args.add(res.register(visit(arg, context)).set_pos(node.pos_start, node.pos_end).set_context(context))
    if res.should_return(): return res
  var return_value = res.register(value_to_call.execute(args))
  if res.should_return(): return res
  return_value = return_value.copy().set_pos(node.pos_start, node.pos_end).set_context(context)
  return res.success(return_value)

method visit(node : nodes.TryNode, context : Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  let try_block = res.register(visit(node.try_block, context))
  var ret_value = if node.may_return: try_block
                  else: nullValue
  if res.should_return() and res.error.name == "NoError": return res
  if res.error.name != "NoError":
      res.reset()
      let except_block = res.register(visit(node.except_block, context))
      if res.should_return(): return res
      ret_value = if node.may_return: except_block
                  else: nullValue
  return res.success(ret_value)

method visit(node : nodes.ReturnNode, context : Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  var ret_value : Value
  if node.returnValue == nodes.emptyNode:
    ret_value = nullValue
  else:
    ret_value = res.register(visit(node.returnValue, context))
    if res.should_return(): return res
  return res.success_return(ret_value)

method visit(node : nodes.ContinueNode, context : Context) : RTResult {.locks: "unknown".} =
    return newRTResult().success_continue()

method visit(node : nodes.BreakNode, context : Context) : RTResult {.locks: "unknown".} =
  return newRTResult().success_break()

method visit(node : nodes.AssertNode, context : Context) : RTResult {.locks: "unknown".} =
  let res = newRTResult()
  let assertion = res.register(visit(node.assertion, context))
  if res.should_return(): return res
  if not assertion.is_true():
    return res.failure(newRTError(
      node.pos_start, node.pos_end,
      context,
      "Jo ap ne kaha wo sahi nahi"
    ))
  return res.success(nullValue)

proc run*(fn: string, inp: string, isPrelude: bool) : (string, bool)
let global_symbol_table = newSymbolTable(nil)
global_symbol_table.setValue("sahi", trueValue)
global_symbol_table.setValue("galat", falseValue)
global_symbol_table.setValue("khali", nullValue)
global_symbol_table.setValue("LINE_LIKHO", Value(Type: BuiltIn, builtin_name: "LINE_LIKHO", args: @["value"], fun:
  proc(exec_ctx: Context): Value =
    echo exec_ctx.symbol_table.getValue("value").toString()
    return nullValue
  ))
global_symbol_table.setValue("LIKHO", Value(Type: BuiltIn, builtin_name: "LIKHO", args: @["value"], fun:
  proc(exec_ctx: Context): Value =
    stdout.write(exec_ctx.symbol_table.getValue("value").toString())
    return nullValue
  ))
global_symbol_table.setValue("PUCHO", Value(Type: BuiltIn, builtin_name: "PUCHO", args: @["value"], fun:
  proc(exec_ctx: Context): Value =
    let text = exec_ctx.symbol_table.getValue("value").toString()
    stdout.write(text)
    let input = stdin.readLine()
    return Value(Type: String, strValue: input, pos_start: exec_ctx.parent_entry_pos, pos_end: exec_ctx.parent_entry_pos)
  ))
global_symbol_table.setValue("SAAF", Value(Type: BuiltIn, builtin_name: "SAAF", args: @[], fun:
  proc(exec_ctx: Context): Value =
    discard execCmd "cls"
    return nullValue
  ))
global_symbol_table.setValue("KYA_NUM", Value(Type: BuiltIn, builtin_name: "KYA_NUM", args: @["value"], fun:
  proc(exec_ctx: Context): Value =
    return Value(
      Type: Number,
      is_bool: true,
      is_null: false,
      numValue: if exec_ctx.symbol_table.getValue("value").Type == Number: 1
                else: 0,
      pos_start: exec_ctx.parent_entry_pos,
      pos_end: exec_ctx.parent_entry_pos
    )
  ))
global_symbol_table.setValue("KYA_STR", Value(Type: BuiltIn, builtin_name: "KYA_STR", args: @["value"], fun:
  proc(exec_ctx: Context): Value =
    return Value(
      Type: Number,
      is_bool: true,
      is_null: false,
      numValue: if exec_ctx.symbol_table.getValue("value").Type == String: 1
                else: 0,
      pos_start: exec_ctx.parent_entry_pos,
      pos_end: exec_ctx.parent_entry_pos
    )
  ))
global_symbol_table.setValue("KYA_LIST", Value(Type: BuiltIn, builtin_name: "KYA_LIST", args: @["value"], fun:
  proc(exec_ctx: Context): Value =
    return Value(
      Type: Number,
      is_bool: true,
      is_null: false,
      numValue: if exec_ctx.symbol_table.getValue("value").Type == Lis: 1
                else: 0,
      pos_start: exec_ctx.parent_entry_pos,
      pos_end: exec_ctx.parent_entry_pos
    )
  ))
global_symbol_table.setValue("KYA_KAM", Value(Type: BuiltIn, builtin_name: "KYA_KAM", args: @["value"], fun:
  proc(exec_ctx: Context): Value =
    return Value(
      Type: Number,
      is_bool: true,
      is_null: false,
      numValue: if exec_ctx.symbol_table.getValue("value").Type == Function: 1
                else: 0,
      pos_start: exec_ctx.parent_entry_pos,
      pos_end: exec_ctx.parent_entry_pos
    )
  ))
global_symbol_table.setValue("LIST", Value(Type: BuiltIn, builtin_name: "LIST", args: @["value"], fun:
  proc(exec_ctx: Context): Value =
    let value = exec_ctx.symbol_table.getValue("value")
    if value.Type != String:
      raise newException(OSError, "Pehla argument string hona chahiye")
    var new_seq = new seq[Value]
    new_seq[] = value.strValue.toSeq().map(proc(c: char) : Value = Value(Type: String, strValue: $c, pos_start: exec_ctx.parent_entry_pos, pos_end: exec_ctx.parent_entry_pos))
    return
      Value(
        Type: Lis,
        lisValue: new_seq,
        pos_start: exec_ctx.parent_entry_pos,
        pos_end: exec_ctx.parent_entry_pos
      )
  ))
global_symbol_table.setValue("DALO", Value(Type: BuiltIn, builtin_name: "DALO", args: @["list", "value", "index"], fun:
  proc(exec_ctx: Context): Value =
    let value = exec_ctx.symbol_table.getValue("value")
    let list = exec_ctx.symbol_table.getValue("list")
    let index = exec_ctx.symbol_table.getValue("index")
    if list.Type != Lis:
      raise newException(OSError, "Pehla argument list hona chahiye")
    if index.Type != Number:
      raise newException(OSError, "Teesra argument number hona chahiye")
    var ind: int
    if index.numValue != -1:
      ind = if index.numValue < 0f: len(list.lisValue[]) + index.numValue.toInt()
            else: index.numValue.toInt()
      list.lisValue[].insert(@[value], ind)
    else:
      list.lisValue[].add(value)
    return nullValue
  ))
global_symbol_table.setValue("STR", Value(Type: BuiltIn, builtin_name: "LIST", args: @["value"], fun:
  proc(exec_ctx: Context): Value =
    return
      Value(
        Type: String,
        strValue: $exec_ctx.symbol_table.getValue("value"),
        pos_start: exec_ctx.parent_entry_pos,
        pos_end: exec_ctx.parent_entry_pos
      )
  ))
global_symbol_table.setValue("NUM", Value(Type: BuiltIn, builtin_name: "LIST", args: @["value"], fun:
  proc(exec_ctx: Context): Value =
    let num = exec_ctx.symbol_table.getValue("value")
    var n : float
    if num.Type == String:
      try:
        n = parseFloat(num.strValue)
      except:
        raise newException(OSError, $num & " konumber nahi ban sakte")
    elif num.is_bool or num.is_null:
      n = num.numValue
    else:
      raise newException(OSError, "Pehla argument string hona chahiye")
    return
      Value(
        Type: Number,
        is_bool: false,
        is_null: false,
        numValue: n,
        pos_start: exec_ctx.parent_entry_pos,
        pos_end: exec_ctx.parent_entry_pos
      )
  ))
global_symbol_table.setValue("NIKAL", Value(Type: BuiltIn, builtin_name: "NIKAL", args: @["list", "index"], fun:
  proc(exec_ctx: Context): Value =
    let list = exec_ctx.symbol_table.getValue("list")
    let index = exec_ctx.symbol_table.getValue("index")
    if list.Type != Lis:
      raise newException(OSError, "Pehla argument list hona chahiye")
    if index.Type != Number:
      raise newException(OSError, "Teesra argument number hona chahiye")
    var ind: int
    if index.numValue == -1:
      ind = if index.numValue < 0f: len(list.lisValue[]) + index.numValue.toInt()
            else: index.numValue.toInt()
    var lis : seq[Value] = @[]
    for i, j in list.lisValue[]:
      if i != ind:
        lis.add(j)
    list.lisValue[] = lis
    return nullValue
  ))
global_symbol_table.setValue("LAMBAI", Value(Type: BuiltIn, builtin_name: "LAMBAI", args: @["list"], fun:
  proc(exec_ctx: Context): Value =
    let list = exec_ctx.symbol_table.getValue("list")
    if list.Type != Lis:
      raise newException(OSError, "Pehla argument list hona chahiye")
    return Value(
      Type: Number,
      is_bool: false,
      is_null: false,
      numValue: len(list.lisValue[]).toFloat(),
      pos_start: exec_ctx.parent_entry_pos,
      pos_end: exec_ctx.parent_entry_pos
    )
  ))

global_symbol_table.setValue("CHALAO", Value(Type: BuiltIn, builtin_name: "CHALAO", args: @["file"], fun:
  proc(exec_ctx: Context): Value =
    let fileName = exec_ctx.symbol_table.getValue("file")
    if fileName.Type != String:
      raise newException(OSError, "Pehla argument string hona chahiye")
    let file = $readFile(fileName.strValue).toSeq().filter(proc(c: char) : bool = c != '\r').join("")
    let (ran, isError) = run(fileName.strValue, file, false)
    if isError:
      raise newException(OSError, ran)
    return nullValue
  ))
global_symbol_table.setValue("STR_CHALAO", Value(Type: BuiltIn, builtin_name: "STR_CHALAO", args: @["str"], fun:
  proc(exec_ctx: Context): Value =
    let str = exec_ctx.symbol_table.getValue("str")
    let (ran, isError) = run(str.strValue, "<STR_CHALAO>", false)
    if isError:
      raise newException(OSError, ran)
    return nullValue
  ))
proc run*(fn: string, inp: string, isPrelude: bool) : (string, bool) =
  let (toks, invalidChar) = lexer.input(fn, inp)
  if invalidChar.name != "NoError":
    return (errors.as_string(invalidChar), true)
  let (ast, invalidSyntax) = parser.input(toks)
  if invalidSyntax.name != "NoError":
    return (errors.as_string(invalidSyntax), true)
  let context = Context(display_name: "<module>", symbol_table: global_symbol_table, parent: nil, parent_entry_pos: nil)
  let res = visit(ast, context)
  if res.error.name != "NoError":
    return (res.error.as_string(), true)
  return (res.value.toString(), false)

while true:
  stdout.write(">")
  let stringToEval = readLine(stdin)
  let (ran, _) = run("<module>", $stringToEval, false)
  echo ran
