import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import glox/util.{type Position, Position}

// Types

// `input` Is only meant to take a list of graphemes, but no way to express that in type system
pub opaque type State {
  State(input: String, pos: Position)
}

pub fn new_state(input: String) {
  State(input, Position(0, 0, 0))
}

pub type Message {
  Message(
    pos: Position,
    unexpectedinput: String,
    expectedproductions: List(String),
  )
}

fn position_to_string(position: Position) -> String {
  let Position(line:, column:, ..) = position
  "line " <> int.to_string(line) <> " column " <> int.to_string(column)
}

pub fn message_to_string(message: Message) -> String {
  let Message(pos:, unexpectedinput:, expectedproductions:) = message
  "Unexpected input at "
  <> position_to_string(pos)
  <> ": "
  <> unexpectedinput
  <> "."
  <> "Expected one of: "
  <> string.join(expectedproductions, ", ")
}

type ValidReply(a) {
  ValidReply(parsed: a, state: State, possible_error: Message)
}

type Reply(a) =
  Result(ValidReply(a), Message)

pub type Parsed(a) =
  Result(a, Message)

pub opaque type Consumed(a) {
  // We thunk the consumed varient to emulate the lazy evaluation that the original parsec uses for an optimisation in `bind`
  Consumed(thunk: fn() -> Reply(a))
  Empty(value: Reply(a))
}

pub fn consumed_to_parsed(consumed: Consumed(a)) -> Parsed(a) {
  case consumed {
    Consumed(thunk) -> result.try(thunk(), fn(x) { Ok(x.parsed) })
    Empty(val) -> result.try(val, fn(x) { Ok(x.parsed) })
  }
}

pub type Parser(a) =
  fn(State) -> Consumed(a)

// Primative Parsers

pub fn return(x: a) -> Parser(a) {
  fn(state: State) {
    Empty(Ok(ValidReply(x, state, Message(state.pos, "", []))))
  }
}

pub fn fail() -> Parser(a) {
  fn(state: State) { Empty(Error(Message(state.pos, "", []))) }
}

pub fn eof() -> Parser(String) {
  fn(state: State) {
    let State(input, ..) = state
    case input {
      "" ->
        Empty(Ok(ValidReply("", state, Message(state.pos, "End Of File", []))))
      _ -> Empty(Error(Message(state.pos, "End Of File", [])))
    }
  }
}

pub fn get_position() -> Parser(Position) {
  fn(state: State) {
    Empty(Ok(ValidReply(state.pos, state, Message(state.pos, "", []))))
  }
}

fn nextpos(pos: Position, char: String) {
  let Position(line, column, charcount) = pos
  case char {
    "\n" -> Position(line + 1, 0, charcount + 1)
    _ -> Position(line, column + 1, charcount + 1)
  }
}

pub fn satisfy(testf: fn(String) -> Bool) -> Parser(String) {
  fn(state: State) {
    let State(input, pos) = state
    case string.pop_grapheme(input) {
      Error(Nil) -> Empty(Error(Message(pos, "End of Input.", [])))
      Ok(#(first, rest)) -> {
        let newpos = nextpos(pos, first)
        let newstate = State(rest, newpos)
        case testf(first) {
          True ->
            Consumed(fn() {
              Ok(ValidReply(first, newstate, Message(pos, "", [])))
            })
          False -> Empty(Error(Message(pos, first, [])))
        }
      }
    }
  }
}

// Combinators

pub fn sequence(p: Parser(a), f: fn(a) -> Parser(b)) -> Parser(b) {
  fn(input: State) {
    case p(input) {
      Empty(result1) -> {
        case result1 {
          Ok(ValidReply(x, rest, _)) -> {
            f(x)(rest)
          }
          Error(err) -> Empty(Error(err))
        }
      }
      Consumed(thunk) ->
        Consumed(fn() {
          let result1 = thunk()
          case result1 {
            Ok(ValidReply(x, rest, _)) -> {
              case f(x)(rest) {
                Consumed(reply2) -> reply2()
                Empty(reply2) -> reply2
              }
            }
            Error(err) -> Error(err)
          }
        })
    }
  }
}

fn merge(msg1: Message, msg2: Message) {
  Message(
    ..msg1,
    expectedproductions: list.append(
      msg1.expectedproductions,
      msg2.expectedproductions,
    ),
  )
}

fn merge_ok(x: a, inp: State, msg1: Message, msg2: Message) {
  Empty(Ok(ValidReply(x, inp, merge(msg1, msg2))))
}

fn merge_error(msg1: Message, msg2: Message) {
  Empty(Error(merge(msg1, msg2)))
}

pub fn choice(p: Parser(a), q: Parser(a)) -> Parser(a) {
  fn(state: State) {
    case p(state) {
      Empty(Error(msg1)) -> {
        case q(state) {
          Empty(Error(msg2)) -> merge_error(msg1, msg2)
          Empty(Ok(ValidReply(x, inp, msg2))) -> merge_ok(x, inp, msg1, msg2)
          Consumed(_) as value -> value
        }
      }
      Empty(Ok(ValidReply(x, inp, msg1))) -> {
        case q(state) {
          Empty(Error(msg2)) -> merge_ok(x, inp, msg1, msg2)
          Empty(Ok(ValidReply(_, _, msg2))) -> merge_ok(x, inp, msg1, msg2)
          Consumed(_) as value -> value
        }
      }
      Consumed(_) as value -> value
    }
  }
}

pub fn try(p: Parser(a)) -> Parser(a) {
  fn(state: State) {
    case p(state) {
      Consumed(thunk) -> {
        case thunk() {
          Error(_) as err -> Empty(err)
          other -> Consumed(fn() { other })
        }
      }
      other -> other
    }
  }
}

pub fn look_ahead(p: Parser(a)) -> Parser(a) {
  fn(input_state: State) {
    case p(input_state) {
      Consumed(thunk) -> {
        case thunk() {
          Ok(ValidReply(parsed, _, possible_err)) ->
            Consumed(fn() { Ok(ValidReply(parsed, input_state, possible_err)) })
          Error(_) as err -> Consumed(fn() { err })
        }
      }
      Empty(Ok(ValidReply(parsed, _, possible_err))) ->
        Empty(Ok(ValidReply(parsed, input_state, possible_err)))
      Empty(Error(_)) as err -> err
    }
  }
}

fn expect(msg: Message, label: String) -> Message {
  Message(..msg, expectedproductions: [label])
}

pub fn label(p: Parser(a), label: String) -> Parser(a) {
  fn(state: State) {
    case p(state) {
      Empty(Error(msg)) -> Empty(Error(expect(msg, label)))
      Empty(Ok(ValidReply(x, state, msg))) ->
        Empty(Ok(ValidReply(x, state, expect(msg, label))))
      other -> other
    }
  }
}

// Utility Parsers

pub fn char(c: String) -> Parser(String) {
  label(satisfy(fn(a: String) { a == c }), c)
}

pub fn any_char() -> Parser(String) {
  satisfy(fn(_) { True })
}

pub fn choice_list(parser_list: List(Parser(a))) -> Parser(a) {
  case parser_list {
    [] -> fail()
    [first, ..rest] -> choice(first, choice_list(rest))
  }
}

pub fn many1_reduce(p: Parser(a), default: b, f: fn(b, a) -> b) -> Parser(b) {
  use first <- sequence(p)
  choice(many1_reduce(p, f(default, first), f), return(default))
}

pub fn string(str: String) -> Parser(String) {
  case string.pop_grapheme(str) {
    Error(Nil) -> return("")
    Ok(#(first, rest)) -> {
      use first_part <- sequence(char(first))
      use rest_part <- sequence(string(rest))
      return(first_part <> rest_part)
    }
  }
}

pub fn many1(p: Parser(a)) -> Parser(List(a)) {
  use first <- sequence(p)
  use rest <- sequence(choice(many1(p), return([])))
  return([first, ..rest])
}

pub fn many(p: Parser(a)) -> Parser(List(a)) {
  choice(many1(p), return([]))
}

pub fn once_or_none(p: Parser(a)) -> Parser(Result(a, Nil)) {
  choice(
    {
      use result <- sequence(p)
      return(Ok(result))
    },
    return(Error(Nil)),
  )
}

fn is_alpha(inputstring: String) -> Bool {
  string.to_graphemes(inputstring)
  |> list.flat_map(string.to_utf_codepoints)
  |> list.map(string.utf_codepoint_to_int)
  |> list.all(fn(x: Int) {
    { { 65 <= x } && { x <= 90 } } || { 97 <= x } && { x <= 122 }
  })
}

fn is_digit(string: String) -> Bool {
  string.to_graphemes(string)
  |> list.flat_map(string.to_utf_codepoints)
  |> list.map(string.utf_codepoint_to_int)
  |> list.all(fn(x: Int) { { 48 <= x } && { x <= 57 } })
}

pub fn letter() -> Parser(String) {
  label(satisfy(is_alpha), "letter")
}

pub fn digit() -> Parser(String) {
  label(satisfy(is_digit), "digit")
}

pub fn parse_as(p: Parser(a), value: b) -> Parser(b) {
  use _ <- sequence(p)
  return(value)
}

pub fn number() -> Parser(Float) {
  use left <- sequence(many1(digit()))
  use rest <- sequence(choice(
    {
      use _ <- sequence(char("."))
      use right <- sequence(many1(digit()))
      return([".", ..right])
    },
    return([]),
  ))

  let num =
    list.append(left, rest)
    |> string.concat()
    |> fn(x) {
      result.or(float.parse(x), result.map(int.parse(x), int.to_float))
    }

  case num {
    Ok(num) -> return(num)
    Error(_) -> fail()
  }
}

pub fn not_char(char: String) -> Parser(String) {
  satisfy(fn(x) { x != char })
}

fn string_until_with_acc(until_char: String, acc: String) -> Parser(String) {
  choice(
    {
      use _ <- sequence(look_ahead(char(until_char)))
      return(acc)
    },
    {
      use matched_char <- sequence(any_char())
      string_until_with_acc(until_char, acc <> matched_char)
    },
  )
}

pub fn string_until(until_char: String) -> Parser(String) {
  string_until_with_acc(until_char, "")
}
