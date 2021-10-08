import nodes
import sets
import hashes
import sequtils
import strutils
import lexer
import parser
import errors

var includeSet = initHashSet[string]()

proc includeSingle(node: IncludeNode): (seq[Node], string) = 
    if node.includes in includeSet: return (@[], "")
    let fn = node.includes
    includeSet.incl(fn)
    let inp = $readFile(fn).toSeq().filter(proc(c: char) : bool = c != '\r').join("")
    let (toks, invalidChar) = lexer.input(fn, inp)
    if invalidChar.name != "NoError":
        return (@[], errors.as_string(invalidChar))
    let (ast, invalidSyntax) = parser.input(toks)
    if invalidSyntax.name != "NoError":
        return (@[], errors.as_string(invalidChar))
    if ast of ProgramNode:
        return (cast[ProgramNode](ast).statements, "")

proc includer(statements: seq[Node]): (seq[Node], string) =
    var new_statements: seq[Node] = @[]
    for statement in statements:
        if statement of IncludeNode:
            let (includedStatements, err) = includeSingle(cast[IncludeNode](statement))
            if err != "": return (@[], err)
            let (includes, err2) = includer(includedStatements)
            if err != "": return (@[], err2)
            new_statements = new_statements.concat(includes)
        else: new_statements.add(statement)
    return (new_statements, "")

proc doInclude*(statements: seq[Node]): (seq[Node], string) = 
    includeSet = initHashSet[string]()
    result = includer(statements)
    includeSet = initHashSet[string]()
