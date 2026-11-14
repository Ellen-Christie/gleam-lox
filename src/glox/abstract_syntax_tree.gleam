import glox/util.{type Position}

pub type IdentifierName {
  IdentifierName(name: String)
}

pub type Identifier {
  Identifier(name: IdentifierName, position: Position)
}


fn identifier_to_string(identifier: Identifier) -> String {
  "identifier: \"" <> identifier.name.name <> "\""
}

pub type UnaryOperator {
  BOOLNEGATE(position: Position)
  NUMNEGATE(position: Position)
}

pub fn unary_operator_to_string(operator: UnaryOperator) {
  case operator {
    BOOLNEGATE(_) -> "boolean negation (!)"
    NUMNEGATE(_) -> "numerical negation (-)"
  }
}

pub type BinaryOperator {
  DIVIDE(position: Position)
  TIMES(position: Position)
  MINUS(position: Position)
  PLUS(position: Position)
  NOTEQUAL(position: Position)
  EQUAL(position: Position)
  GREATER(position: Position)
  GREATEREQUAL(position: Position)
  LESS(position: Position)
  LESSEQUAL(position: Position)
}

pub fn binary_operator_to_string(operator: BinaryOperator) -> String {
  case operator {
    DIVIDE(_) -> "division (/)"
    TIMES(_) -> "multiplication (*)"
    MINUS(_) -> "subtraction (-)"
    PLUS(_) -> "addition (+)"
    NOTEQUAL(_) -> "non-equality (!=)"
    EQUAL(_) -> "equality (==)"
    GREATER(_) -> "greater than (>)"
    GREATEREQUAL(_) -> "greater than or equal to (>=)"
    LESS(_) -> "less than (<)"
    LESSEQUAL(_) -> "less than or equal to (<=)"
  }
}

pub type Expr {
  Assignment(name: Identifier, value: Expr)
  Binary(left: Expr, operator: BinaryOperator, right: Expr)
  Grouping(expression: Expr)
  LiteralString(value: String, position: Position)
  LiteralNumber(value: Float, position: Position)
  LiteralBool(value: Bool, position: Position)
  Variable(name: Identifier)
  LoxNil(position: Position)
  Unary(operator: UnaryOperator, right: Expr)
}

pub type Declaration {
  VariableDeclaration(name: Identifier, initializer: Expr)
  ExpressionStatement(expression: Expr)
  PrintStatement(expression: Expr)
}

pub type Program = List(Declaration)
