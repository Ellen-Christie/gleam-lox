import gleam/list
import gleam/string
import glox/abstract_syntax_tree as ast
import glox/parser_combinator as pc

// Main function

pub fn parse(str: String) -> pc.Parsed(ast.Program) {
  pc.new_state(str)
  |> parse_program()()
  |> pc.consumed_to_parsed()
}

// Helper functions

/// Matches a whitespace character.
/// 
/// Whitespace in this function is the set of characters stripped from a string by the gleam/string `string.trim` function.  
fn whitespace() -> pc.Parser(String) {
  pc.satisfy(fn(character) {
    case character {
      " " -> True
      "\u{000A}" -> True
      // Line feed
      "\u{000B}" -> True
      // Vertical tabulation
      "\u{000C}" -> True
      // Form feed
      "\u{000D}" -> True
      // Carriage return
      "\u{0085}" -> True
      // Next line
      "\u{2028}" -> True
      // Line separator
      "\u{2029}" -> True
      // Paragraph separator
      _ -> False
    }
  })
}

fn discard_trailing_whitespace(parser: pc.Parser(a)) -> pc.Parser(a) {
  use value <- pc.sequence(parser)
  use _ <- pc.sequence(pc.many(whitespace()))
  pc.return(value)
}

fn character_without_trailing_whitespace(
  character: String,
) -> pc.Parser(String) {
  discard_trailing_whitespace(pc.char(character))
}

fn string_without_trailing_whitespace(str: String) -> pc.Parser(String) {
  discard_trailing_whitespace(pc.string(str))
}

// AST Parsing functions

fn parse_token(token_string: String, token_value: a) -> pc.Parser(a) {
  pc.parse_as(string_without_trailing_whitespace(token_string), token_value)
}

fn parse_indentifier() -> pc.Parser(ast.Identifier) {
  use position <- pc.sequence(pc.get_position())
  use identifier_name <- pc.sequence(pc.label(
    discard_trailing_whitespace(pc.many1(pc.choice(pc.letter(), pc.char("_")))),
    "identifier",
  ))
  pc.return(ast.Identifier(
    ast.IdentifierName(string.concat(identifier_name)),
    position,
  ))
}

fn parse_grouping() -> pc.Parser(ast.Expr) {
  use _ <- pc.sequence(character_without_trailing_whitespace("("))
  use result <- pc.sequence(parse_expr())
  use _ <- pc.sequence(character_without_trailing_whitespace(")"))
  pc.return(ast.Grouping(result))
  // use result <- pc.sequence(pc.bracket(character_without_trailing_whitespace("("), parse_expr(), pc.char(")")))
  // pc.return(ast.Grouping(result))
}

fn parse_literal_string() -> pc.Parser(ast.Expr) {
  use current_position <- pc.sequence(pc.get_position())
  use _ <- pc.sequence(pc.char("\""))
  use str <- pc.sequence(pc.string_until("\""))
  use _ <- pc.sequence(character_without_trailing_whitespace("\""))
  pc.return(ast.LiteralString(str, current_position))
}

fn parse_literal_number() -> pc.Parser(ast.Expr) {
  use current_position <- pc.sequence(pc.get_position())
  use num <- pc.sequence(discard_trailing_whitespace(pc.number()))
  pc.return(ast.LiteralNumber(num, current_position))
}

fn parse_literal_bool() -> pc.Parser(ast.Expr) {
  use current_position <- pc.sequence(pc.get_position())
  pc.choice(
    parse_token("true", ast.LiteralBool(True, current_position)),
    parse_token("false", ast.LiteralBool(False, current_position)),
  )
}

fn parse_variable() -> pc.Parser(ast.Expr) {
  use identifier_to_wrap <- pc.sequence(parse_indentifier())
  pc.return(ast.Variable(identifier_to_wrap))
}

fn parse_expr() -> pc.Parser(ast.Expr) {
  parse_assignment()
}

fn parse_primary() -> pc.Parser(ast.Expr) {
  use current_position <- pc.sequence(pc.get_position())
  pc.choice_list([
    parse_literal_number(),
    parse_literal_string(),
    parse_literal_bool(),
    parse_token("Nil", ast.LoxNil(current_position)),
    parse_grouping(),
    parse_variable(),
  ])
}

fn parse_unary_operator() -> pc.Parser(ast.UnaryOperator) {
  use current_position <- pc.sequence(pc.get_position())
  pc.choice(
    parse_token("-", ast.NUMNEGATE(current_position)),
    parse_token("!", ast.BOOLNEGATE(current_position)),
  )
}

fn parse_unary() -> pc.Parser(ast.Expr) {
  pc.choice(
    {
      use token <- pc.sequence(parse_unary_operator())
      use right <- pc.sequence(parse_unary())
      pc.return(ast.Unary(token, right))
    },
    parse_primary(),
  )
}

fn parse_factor_token() -> pc.Parser(ast.BinaryOperator) {
  use current_position <- pc.sequence(pc.get_position())
  pc.choice(
    parse_token("/", ast.DIVIDE(current_position)),
    parse_token("*", ast.TIMES(current_position)),
  )
}

fn parse_factor() -> pc.Parser(ast.Expr) {
  parse_binary(parse_unary(), parse_factor_token())
}

fn parse_term_token() -> pc.Parser(ast.BinaryOperator) {
  use current_position <- pc.sequence(pc.get_position())
  pc.choice(
    parse_token("-", ast.MINUS(current_position)),
    parse_token("+", ast.PLUS(current_position)),
  )
}

fn parse_term() -> pc.Parser(ast.Expr) {
  parse_binary(parse_factor(), parse_term_token())
}

fn parse_comparator_token() -> pc.Parser(ast.BinaryOperator) {
  use current_position <- pc.sequence(pc.get_position())
  pc.choice_list([
    pc.try(parse_token(">", ast.GREATER(current_position))),
    parse_token(">=", ast.GREATEREQUAL(current_position)),
    pc.try(parse_token("<", ast.LESS(current_position))),
    parse_token("<=", ast.LESSEQUAL(current_position)),
  ])
}

fn parse_comparison() -> pc.Parser(ast.Expr) {
  parse_binary(parse_term(), parse_comparator_token())
}

fn parse_equality_token() -> pc.Parser(ast.BinaryOperator) {
  use current_position <- pc.sequence(pc.get_position())
  pc.choice(
    parse_token("==", ast.EQUAL(current_position)),
    parse_token("!=", ast.NOTEQUAL(current_position)),
  )
}

fn parse_equality() -> pc.Parser(ast.Expr) {
  parse_binary(parse_comparison(), parse_equality_token())
}

fn parse_binary(
  argument_parser: pc.Parser(ast.Expr),
  token_parser: pc.Parser(ast.BinaryOperator),
) -> pc.Parser(ast.Expr) {
  use left <- pc.sequence(argument_parser)
  use token_and_right_pairs <- pc.sequence(
    pc.many({
      use token <- pc.sequence(token_parser)
      use right <- pc.sequence(argument_parser)
      pc.return(#(token, right))
    }),
  )
  let tree =
    list.fold(token_and_right_pairs, left, fn(acc, item) {
      ast.Binary(acc, item.0, item.1)
    })
  pc.return(tree)
}

fn parse_assignment() -> pc.Parser(ast.Expr) {
  pc.choice(
    pc.try({
      use identifier <- pc.sequence(parse_indentifier())
      use _ <- pc.sequence(character_without_trailing_whitespace("="))
      use expression <- pc.sequence(parse_assignment())
      pc.return(ast.Assignment(identifier, expression))
    }),
    parse_equality(),
  )
}

fn parse_print_statement() -> pc.Parser(ast.Declaration) {
  use _ <- pc.sequence(pc.try(string_without_trailing_whitespace("print ")))
  use expression <- pc.sequence(parse_expr())
  use _ <- pc.sequence(character_without_trailing_whitespace(";"))
  pc.return(ast.PrintStatement(expression))
}

fn parse_expression_statement() -> pc.Parser(ast.Declaration) {
  use expression <- pc.sequence(parse_expr())
  use _ <- pc.sequence(character_without_trailing_whitespace(";"))
  pc.return(ast.ExpressionStatement(expression))
}

fn parse_statement() -> pc.Parser(ast.Declaration) {
  pc.choice(parse_print_statement(), parse_expression_statement())
}

fn parse_variable_declaration() -> pc.Parser(ast.Declaration) {
  use _ <- pc.sequence(pc.try(string_without_trailing_whitespace("var ")))
  use identifier <- pc.sequence(parse_indentifier())
  use value_to_assign <- pc.sequence(
    pc.once_or_none({
      use _ <- pc.sequence(character_without_trailing_whitespace("="))
      parse_expr()
    }),
  )
  use current_position <- pc.sequence(pc.get_position())
  let value_to_assign = {
    case value_to_assign {
      Error(Nil) -> ast.LoxNil(current_position)
      Ok(other) -> other
    }
  }
  use _ <- pc.sequence(character_without_trailing_whitespace(";"))
  pc.return(ast.VariableDeclaration(identifier, value_to_assign))
}

fn parse_declaration() -> pc.Parser(ast.Declaration) {
  pc.choice(parse_variable_declaration(), parse_statement())
}

fn parse_program() -> pc.Parser(ast.Program) {
  // Discard whitespace at beginning of file
  use _ <- pc.sequence(pc.many(whitespace()))
  use program <- pc.sequence(pc.many(parse_declaration()))
  //use _ <- pc.sequence(pc.eof())
  pc.return(program)
}
