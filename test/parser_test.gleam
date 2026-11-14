import gleeunit
import glox/abstract_syntax_tree as ast
import glox/parser
import glox/util.{type Position, Position}

pub fn main() -> Nil {
  gleeunit.main()
}

fn parses_with_value(
  input: String,
  expected_value: List(ast.Declaration),
) -> Nil {
  let actual_value = parser.parse(input)

  assert actual_value == Ok(expected_value)
}

pub fn print_test() -> Nil {
  parses_with_value("print \"hi\";", [
    ast.PrintStatement(ast.LiteralString("hi", Position(0, 6, 6))),
  ])
}

pub fn print_with_space_before_semicolon_test() -> Nil {
  parses_with_value("print \"hi\" ;", [
    ast.PrintStatement(ast.LiteralString("hi", Position(0, 6, 6))),
  ])
}

pub fn two_print_test() -> Nil {
  parses_with_value("print \"hi\"; print \"hello\";", [
    ast.PrintStatement(ast.LiteralString("hi", Position(0, 6, 6))),
    ast.PrintStatement(ast.LiteralString("hello", Position(0, 18, 18))),
  ])
}


