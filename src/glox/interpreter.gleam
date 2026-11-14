import gleam/io
import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import glox/abstract_syntax_tree as ast
import glox/state
import glox/util.{type Position, Position}

type Environment {
  Environment(
    current_scope: dict.Dict(ast.IdentifierName, ExprReturnType),
    enclosing_scope: Result(Environment, Nil),
  )
}

type EnvironmentError {
  LocationNotFoundErrorEnv(unfound_location: ast.IdentifierName)
}

fn environment_put(
  environment: Environment,
  name: ast.IdentifierName,
  value: ExprReturnType,
) -> Environment {
  Environment(
    dict.insert(environment.current_scope, name, value),
    environment.enclosing_scope,
  )
}

fn environment_get(
  environment: Environment,
  name: ast.IdentifierName,
) -> Result(ExprReturnType, EnvironmentError) {
  case dict.get(environment.current_scope, name) {
    Ok(value) -> Ok(value)
    Error(Nil) -> {
      case environment.enclosing_scope {
        Ok(Environment(..) as enclosing_scope) ->
          environment_get(enclosing_scope, name)
        Error(Nil) -> Error(LocationNotFoundErrorEnv(name))
      }
    }
  }
}

fn environment_set(
  environment: Environment,
  name: ast.IdentifierName,
  value: ExprReturnType,
) -> Result(Environment, EnvironmentError) {
  let Environment(current_scope, enclosing_scope) = environment
  case dict.has_key(current_scope, name) {
    True ->
      Ok(Environment(dict.insert(current_scope, name, value), enclosing_scope))
    False -> {
      case enclosing_scope {
        Ok(enclosing_scope_value) -> {
          use new_enclosing_scope <- result.try(environment_set(
            enclosing_scope_value,
            name,
            value,
          ))
          Ok(Environment(current_scope, Ok(new_enclosing_scope)))
        }
        Error(_) -> Error(LocationNotFoundErrorEnv(name))
      }
    }
  }
}

type InterpreterState {
  InterpreterState(environment: Environment, errors: List(EvalError), print_list: List(String))
}

pub type ExprReturnType {
  ExprNumber(number: Float)
  ExprString(str: String)
  ExprBool(bool: Bool)
  ExprNil
}

pub type EvalError {
  BinaryInvalidArgumentType(
    operator: ast.BinaryOperator,
    invalid_arguments: #(ExprReturnType, ExprReturnType),
    expected_arguments: List(#(ExprReturnType, ExprReturnType)),
  )

  UnaryInvalidArgumentType(
    operator: ast.UnaryOperator,
    invalid_arguments: ExprReturnType,
    expected_arguments: List(ExprReturnType),
  )

  DivisionByZero(position: Position)

  AssignedLocationDoesNotExist(var: ast.IdentifierName, position: Position)
}

type ExprResult =
  Result(ExprReturnType, List(EvalError))

type Evaluator(a) =
  state.State(InterpreterState, a)

fn set_var_internal(
  interpreter_state: InterpreterState,
  variable: ast.Identifier,
  value: ExprReturnType,
) -> Result(InterpreterState, List(EvalError)) {
  case environment_set(interpreter_state.environment, variable.name, value) {
    Ok(new_env) ->
      Ok(InterpreterState(..interpreter_state, environment: new_env))
    Error(LocationNotFoundErrorEnv(location)) ->
      Error([AssignedLocationDoesNotExist(location, variable.position)])
  }
}

fn set_var(
  variable: ast.Identifier,
  value: ExprReturnType,
  then: fn() -> Evaluator(ExprResult),
) -> Evaluator(ExprResult) {
  use environment_result <- state.try_bind(
    state.gets(set_var_internal(_, variable, value)),
  )
  state.bind(state.put(environment_result), fn(_) { then() })
}

fn define_var_internal(
  interpeter_state: InterpreterState,
  variable: ast.Identifier,
  value: ExprReturnType,
) -> InterpreterState {
  let new_env =
    environment_put(interpeter_state.environment, variable.name, value)
  InterpreterState(..interpeter_state, environment: new_env)
}

fn define_var(
  variable: ast.Identifier,
  value: ExprReturnType,
  then: fn() -> Evaluator(a),
) -> Evaluator(a) {
  state.bind(state.modify(define_var_internal(_, variable, value)), fn(_) {
    then()
  })
}

fn get_var_internal(
  interpreter_state: InterpreterState,
  variable: ast.Identifier,
) -> ExprResult {
  case environment_get(interpreter_state.environment, variable.name) {
    Ok(value) -> Ok(value)
    Error(LocationNotFoundErrorEnv(location)) ->
      Error([AssignedLocationDoesNotExist(location, variable.position)])
  }
}

fn get_var(
  variable: ast.Identifier,
  then: fn(ExprReturnType) -> Evaluator(ExprResult),
) -> Evaluator(ExprResult) {
  state.try_bind(state.gets(get_var_internal(_, variable)), then)
}

fn record_errors_internal(
  interpeter_state: InterpreterState,
  errors_to_add: List(EvalError),
) -> InterpreterState {
  InterpreterState(
    ..interpeter_state,
    errors: list.append(interpeter_state.errors, errors_to_add),
  )
}

fn record_errors(
  errors: List(EvalError),
  then: fn() -> Evaluator(a),
) -> Evaluator(a) {
  state.bind(state.modify(record_errors_internal(_, errors)), fn(_) { then() })
}

fn lox_print_internal(interpreter_state: InterpreterState, to_print: String) -> InterpreterState {
  InterpreterState(..interpreter_state, print_list: list.append(interpreter_state.print_list, [to_print]))
}

fn lox_print(print to_print: String, then then: fn() -> Evaluator(a)) -> Evaluator(a) {
  state.bind(state.modify(lox_print_internal(_, to_print)), fn(_) { then() })
}

fn eval_return_value_to_string(eval: ExprReturnType) -> String {
  case eval {
    ExprNumber(number) -> float.to_string(number)
    ExprString(string) -> string
    ExprBool(boolean) -> bool.to_string(boolean)
    ExprNil -> "Nil"
  }
}

fn eval_return_type_to_string(eval: ExprReturnType) -> String {
  case eval {
    ExprNumber(_) -> "number"
    ExprString(_) -> "string"
    ExprBool(_) -> "boolean"
    ExprNil -> "nil"
  }
}

fn make_invalid_argument_error_message(
  position position: Position,
  operator operator: a,
  operator_to_string operator_to_string: fn(a) -> String,
  invalid_arguments invalid_arguments: b,
  expected_arguments expected_arguments: List(b),
  arguments_to_string arguments_to_string: fn(b) -> String,
) {
  let Position(x, y, _) = position
  "Error at collumn "
  <> int.to_string(x)
  <> ", line "
  <> int.to_string(y)
  <> ". Invalid Argument: "
  <> operator_to_string(operator)
  <> "operator recieved "
  <> arguments_to_string(invalid_arguments)
  <> ". Expected: "
  <> {
    list.map(expected_arguments, arguments_to_string)
    |> string.join(" or ")
  }
}

fn eval_error_to_string(error: EvalError) -> String {
  case error {
    BinaryInvalidArgumentType(operator, invalid_arguments, expected_arguments) ->
      make_invalid_argument_error_message(
        position: operator.position,
        operator:,
        operator_to_string: ast.binary_operator_to_string,
        invalid_arguments:,
        expected_arguments:,
        arguments_to_string: fn(x) {
          let #(left, right) = x
          eval_return_type_to_string(left)
          <> " and "
          <> eval_return_type_to_string(right)
        },
      )
    UnaryInvalidArgumentType(operator, invalid_arguments, expected_arguments) ->
      make_invalid_argument_error_message(
        position: operator.position,
        operator:,
        operator_to_string: ast.unary_operator_to_string,
        invalid_arguments:,
        expected_arguments:,
        arguments_to_string: eval_return_type_to_string,
      )
    DivisionByZero(position) -> {
      let Position(x, y, _) = position
      "Error at collumn "
      <> int.to_string(x)
      <> ", line "
      <> int.to_string(y)
      <> ". Division by zero."
    }
    AssignedLocationDoesNotExist(var:, position:) -> {
      let Position(x, y, _) = position
      "Error at collumn "
      <> int.to_string(x)
      <> ", line "
      <> int.to_string(y)
      <> ". Variable"
      <> var.name
      <> " does not exist."
    }
  }
}

fn eval_error_list_to_string(eval_errors: List(EvalError)) -> String {
  "Errors:\n"
  <> eval_errors
  |> list.map(eval_error_to_string)
  |> string.join("\n")
}

fn eval_result_to_string(eval_result: ExprResult) -> String {
  case eval_result {
    Ok(eval_return) -> eval_return_value_to_string(eval_return)
    Error(eval_errors) -> eval_error_list_to_string(eval_errors)
  }
}

fn eval_binary(
  left: ast.Expr,
  operator: ast.BinaryOperator,
  right: ast.Expr,
) -> Evaluator(ExprResult) {
  use left_result <- state.bind(eval_expr(left))
  use right_result <- state.bind(eval_expr(right))
  case left_result, right_result {
    // Error cases
    Error(_) as error, Ok(_) -> state.return(error)
    Ok(_), Error(_) as error -> state.return(error)
    Error(left_error_list), Error(right_error_list) ->
      state.return(Error(list.append(left_error_list, right_error_list)))

    // Non-Error Cases
    Ok(left_expression_value), Ok(right_expression_value) -> {
      case left_expression_value, operator, right_expression_value {
        // Equals and Not Equals
        left_value, ast.EQUAL(_), right_value ->
          state.return(Ok(ExprBool(left_value == right_value)))
        left_value, ast.NOTEQUAL(_), right_value ->
          state.return(Ok(ExprBool(left_value != right_value)))

        // Numerical Operators
        // Addition is also the string concatenation operator
        ExprNumber(left_number), ast.PLUS(_), ExprNumber(right_number) ->
          state.return(Ok(ExprNumber(left_number +. right_number)))
        ExprString(left_string), ast.PLUS(_), other_right ->
          state.return(
            Ok(ExprString(
              left_string <> eval_return_value_to_string(other_right),
            )),
          )
        other_left, ast.PLUS(_), ExprString(right_string) ->
          state.return(
            Ok(ExprString(
              eval_return_value_to_string(other_left) <> right_string,
            )),
          )
        other_left, ast.PLUS(_) as operator, other_right ->
          state.return(
            Error([
              BinaryInvalidArgumentType(operator, #(other_left, other_right), [
                #(ExprString(""), ExprString("")),
                #(ExprNumber(0.0), ExprNumber(0.0)),
              ]),
            ]),
          )

        ExprNumber(left_number), ast.MINUS(_), ExprNumber(right_number) ->
          state.return(Ok(ExprNumber(left_number -. right_number)))
        ExprNumber(left_number), ast.DIVIDE(position), ExprNumber(right_number)
        -> {
          case right_number {
            0.0 -> state.return(Error([DivisionByZero(position)]))
            _ -> state.return(Ok(ExprNumber(left_number /. right_number)))
          }
        }
        ExprNumber(left_number), ast.TIMES(_), ExprNumber(right_number) ->
          state.return(Ok(ExprNumber(left_number *. right_number)))
        ExprNumber(left_number), ast.GREATER(_), ExprNumber(right_number) ->
          state.return(Ok(ExprBool(left_number >. right_number)))
        ExprNumber(left_number), ast.GREATEREQUAL(_), ExprNumber(right_number)
        -> state.return(Ok(ExprBool(left_number >=. right_number)))
        ExprNumber(left_number), ast.LESS(_), ExprNumber(right_number) ->
          state.return(Ok(ExprBool(left_number <. right_number)))
        ExprNumber(left_number), ast.LESSEQUAL(_), ExprNumber(right_number) ->
          state.return(Ok(ExprBool(left_number <=. right_number)))

        left_other, ast.MINUS(_) as operator, right_other
        | left_other, ast.DIVIDE(_) as operator, right_other
        | left_other, ast.TIMES(_) as operator, right_other
        | left_other, ast.GREATER(_) as operator, right_other
        | left_other, ast.GREATEREQUAL(_) as operator, right_other
        | left_other, ast.LESS(_) as operator, right_other
        | left_other, ast.LESSEQUAL(_) as operator, right_other
        ->
          state.return(
            Error([
              BinaryInvalidArgumentType(operator, #(left_other, right_other), [
                #(ExprNumber(0.0), ExprNumber(0.0)),
              ]),
            ]),
          )
      }
    }
  }
}

fn negate_expr(expression: ExprReturnType) -> Evaluator(ExprResult) {
  case expression {
    ExprNil -> state.return(Ok(ExprBool(True)))
    ExprBool(boolean) -> state.return(Ok(ExprBool(!boolean)))
    _ -> state.return(Ok(ExprBool(False)))
  }
}

fn eval_unary(
  operator: ast.UnaryOperator,
  expression: ast.Expr,
) -> Evaluator(ExprResult) {
  use result <- state.bind(eval_expr(expression))
  case result {
    Error(_) as err -> state.return(err)
    Ok(expression_value) -> {
      case operator, expression_value {
        ast.BOOLNEGATE(_), value -> negate_expr(value)
        ast.NUMNEGATE(_), ExprNumber(number) ->
          state.return(Ok(ExprNumber(float.negate(number))))
        ast.NUMNEGATE(_) as operator, invalid_value ->
          state.return(
            Error([
              UnaryInvalidArgumentType(operator, invalid_value, [
                ExprNumber(0.0),
              ]),
            ]),
          )
      }
    }
  }
}

fn eval_variable(variable: ast.Identifier) -> Evaluator(ExprResult) {
  use value <- get_var(variable)
  state.return(Ok(value))
}

fn eval_assignment(
  variable: ast.Identifier,
  value: ast.Expr,
) -> Evaluator(ExprResult) {
  use evaluated_value <- state.try_bind(eval_expr(value))
  use <- set_var(variable, evaluated_value)
  state.return(Ok(evaluated_value))
}

fn eval_expr(expression: ast.Expr) -> Evaluator(ExprResult) {
  case expression {
    ast.Binary(left, operator, right) -> eval_binary(left, operator, right)
    ast.Unary(operator, expression) -> eval_unary(operator, expression)
    ast.Grouping(inner) -> eval_expr(inner)
    ast.Assignment(variable, value) -> eval_assignment(variable, value)
    ast.Variable(variable) -> eval_variable(variable)
    ast.LiteralString(literal, _) -> state.return(Ok(ExprString(literal)))
    ast.LiteralNumber(literal, _) -> state.return(Ok(ExprNumber(literal)))
    ast.LiteralBool(literal, _) -> state.return(Ok(ExprBool(literal)))
    ast.LoxNil(_) -> state.return(Ok(ExprNil))
  }
}

fn eval_statement(statement: ast.Declaration) -> Evaluator(Nil) {
  case statement {
    ast.PrintStatement(expression) -> {
      use evaluated_expression_result <- state.bind(eval_expr(expression))
      case evaluated_expression_result {
        Ok(expression_value) -> {
          let to_print = eval_return_value_to_string(expression_value)
          io.println(to_print)
          use <- lox_print(to_print)
          state.return(Nil)
        }
        Error(err_list) -> {
          use <- record_errors(err_list)
          state.return(Nil)
        }
      }
    }
    ast.ExpressionStatement(expression) -> {
      use evaluated_expression_result <- state.bind(eval_expr(expression))
      case evaluated_expression_result {
        Ok(_) -> state.return(Nil)
        Error(error_list) -> {
          use <- record_errors(error_list)
          state.return(Nil)
        }
      }
    }
    ast.VariableDeclaration(name, initialiser) -> {
      use variable_value <- state.bind(eval_expr(initialiser))
      case variable_value {
        Ok(variable) -> {
          use <- define_var(name, variable)
          state.return(Nil)
        }
        Error(error_list) -> {
          use <- record_errors(error_list)
          state.return(Nil)
        }
      }
    }
  }
}

fn eval_program(program: ast.Program) -> Evaluator(Nil) {
  state.for_each(run: eval_statement, over: program)
}

pub fn interpret(program: ast.Program) -> Result(List(String), List(EvalError)) {
  let initial_state =
    InterpreterState(
      environment: Environment(current_scope: dict.new(), enclosing_scope: Error(Nil)),
      errors: [],
      print_list: []
    )
  let InterpreterState(errors:, print_list:, ..) = state.exec_state(eval_program(program), initial_state)
  case errors {
    [] -> Ok(print_list)
    errors -> Error(errors)
  }
}
