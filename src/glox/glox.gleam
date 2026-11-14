import argv
import gleam/result
import glox/interpreter
import gleam/io
import glox/parser
import glox/parser_combinator as pc
import simplifile

@external(erlang, "erlang", "halt")
@external(javascript, "node:process", "exit")
fn die(with code: Int) -> Nil

pub type ExecutionError {
  ParserError(pc.Message)
  InterpreterErrors(List(interpreter.EvalError))
}

pub fn execute_string_to_data(
  program: String,
) -> Result(List(String), ExecutionError) {
  use ast <- result.try(
    result.try_recover(parser.parse(program), fn(errors) {
      Error(ParserError(errors))
    }),
  )
  use program_output <- result.try(
    result.try_recover(interpreter.interpret(ast), fn(errors) {
      Error(InterpreterErrors(errors))
    }),
  )
  Ok(program_output)
}

pub fn main() -> Nil {
  case argv.load().arguments {
    [filepath] ->
      case simplifile.read(filepath) {
        Ok(contents) -> {
          // We execute this just for it's side effects (printing to the stdout, which is done in the interpreter module)
          let _ = execute_string_to_data(contents)
          Nil
        }
        Error(_) -> {
          io.println_error("Error reading file from path")
          die(1)
        }
      }
      _ -> {
        io.println_error("Usage: glox <path_to_file>")
        die(1)
      }
  }
}
