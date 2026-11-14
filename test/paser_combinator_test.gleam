import gleam/result
import gleeunit
import glox/parser_combinator as pc
import glox/util.{type Position, Position}

pub fn main() -> Nil {
  gleeunit.main()
}

fn assert_with_input_parser_value(
  input: String,
  parser: pc.Parser(a),
  expected_value: pc.Parsed(a),
) -> Nil {
  let actual_value =
    pc.new_state(input)
    |> parser
    |> pc.consumed_to_parsed()

  assert actual_value == expected_value
}

fn parses_with_value(
  input: String,
  parser: pc.Parser(a),
  expected_value: a,
) -> Nil {
  let actual_value =
    pc.new_state(input)
    |> parser
    |> pc.consumed_to_parsed()

  assert actual_value == Ok(expected_value)
}

pub fn satisfy_matches_test() -> Nil {
  assert_with_input_parser_value("h", pc.satisfy(fn(_) { True }), Ok("h"))
}

pub fn satisfy_fails_test() -> Nil {
  assert_with_input_parser_value(
    "h",
    pc.satisfy(fn(_) { False }),
    Error(pc.Message(Position(0, 0, 0), "h", [])),
  )
}

pub fn satisfy_fails_with_correct_position_test() {
  let value =
    pc.new_state("hx")
    |> pc.sequence(pc.satisfy(fn(x) { x != "x" }), fn(_) {
      pc.satisfy(fn(x) { x != "x" })
    })()
    |> pc.consumed_to_parsed()

  let assert Error(pc.Message(pos, _, _)) = value
  assert pos == Position(0, 1, 1)
}

pub fn satisfy_fails_with_correct_line_test() {
  let value =
    pc.new_state("\nx")
    |> pc.sequence(pc.satisfy(fn(x) { x != "x" }), fn(_) {
      pc.satisfy(fn(x) { x != "x" })
    })()
    |> pc.consumed_to_parsed()

  let assert Error(pc.Message(pos, _, _)) = value
  assert pos == Position(1, 0, 1)
}

pub fn string_matches_test() -> Nil {
  assert_with_input_parser_value(
    "hello world!",
    pc.string("hello world!"),
    Ok("hello world!"),
  )
}

pub fn choice_matches_correct_choice_test_1() -> Nil {
  assert_with_input_parser_value(
    "blorbo",
    pc.choice(pc.string("blorbo"), pc.string("skrunky")),
    Ok("blorbo"),
  )
}

pub fn choice_matches_correct_choice_test_2() -> Nil {
  assert_with_input_parser_value(
    "blorbo",
    pc.choice(pc.string("skrunky"), pc.string("blorbo")),
    Ok("blorbo"),
  )
}

fn assert_with_input_parser_predicate(
  input: String,
  parser: pc.Parser(a),
  predicate: fn(pc.Parsed(a)) -> Bool,
) -> Nil {
  let actual_value =
    pc.new_state(input)
    |> parser
    |> pc.consumed_to_parsed()

  assert predicate(actual_value) == True
}

pub fn choice_fails_both_choices_merges_expected_productions_test() -> Nil {
  assert_with_input_parser_predicate(
    "blorbo",
    pc.choice(
      pc.label(pc.string("hello"), "hello"),
      pc.label(pc.string("nuhuh"), "nuhuh"),
    ),
    fn(x) {
      let assert Error(pc.Message(_, _, expected)) = x
      expected == ["hello", "nuhuh"]
    },
  )
}

pub fn choice_does_not_lookahead_by_default_test() -> Nil {
  assert_with_input_parser_predicate(
    "choose",
    pc.choice(pc.string("choosing"), pc.string("choose")),
    result.is_error,
  )
}

pub fn choice_does_lookashead_with_try_test() -> Nil {
  assert_with_input_parser_value(
    "choose",
    pc.choice(pc.try(pc.string("choosing")), pc.string("choose")),
    Ok("choose"),
  )
}

pub fn choice_list_empty_fails_test() -> Nil {
  assert_with_input_parser_predicate("doesntmatter", pc.choice_list([]), fn(x) {
    result.is_error(x)
  })
}

pub fn choice_list_of_one_matches_argument_parser_test() -> Nil {
  let val1 =
    pc.new_state("hello")
    |> pc.choice_list([pc.string("hello")])()
    |> pc.consumed_to_parsed()

  assert val1 == Ok("hello")

  let val2 =
    pc.new_state("sdjfdsdfkj")
    |> pc.choice_list([pc.string("hello")])()
    |> pc.consumed_to_parsed()

  assert result.is_error(val2) == True
}

pub fn choice_list_of_two_same_as_choice_test() -> Nil {
  assert_with_input_parser_value(
    "blorbo",
    pc.choice_list([pc.string("blorbo"), pc.string("skrunky")]),
    Ok("blorbo"),
  )

  assert_with_input_parser_value(
    "blorbo",
    pc.choice_list([pc.string("skrunky"), pc.string("blorbo")]),
    Ok("blorbo"),
  )

  assert_with_input_parser_predicate(
    "blorbo",
    pc.choice_list([
      pc.label(pc.string("hello"), "hello"),
      pc.label(pc.string("nuhuh"), "nuhuh"),
    ]),
    fn(x) {
      let assert Error(pc.Message(_, _, expected)) = x
      expected == ["hello", "nuhuh"]
    },
  )

  assert_with_input_parser_predicate(
    "choose",
    pc.choice_list([pc.string("choosing"), pc.string("choose")]),
    result.is_error,
  )

  assert_with_input_parser_value(
    "choose",
    pc.choice_list([pc.try(pc.string("choosing")), pc.string("choose")]),
    Ok("choose"),
  )
}

pub fn choice_list_matches_third_test() -> Nil {
  assert_with_input_parser_value(
    "hello",
    pc.choice_list([pc.string("aaaa"), pc.string("bbbbb"), pc.string("hello")]),
    Ok("hello"),
  )
}

pub fn label_labels_test() -> Nil {
  assert_with_input_parser_predicate(
    "segal",
    pc.label(pc.string("label"), "label"),
    fn(x) {
      let assert Error(pc.Message(_, _, expected)) = x
      expected == ["label"]
    },
  )
}

pub fn label_not_apply_consumed_test() -> Nil {
  assert_with_input_parser_predicate(
    "lebal",
    pc.label(pc.string("label"), "label"),
    fn(x) {
      let assert Error(pc.Message(_, _, expected)) = x
      expected == ["a"]
    },
  )
}

pub fn many_matches_zero_times_test() -> Nil {
  assert_with_input_parser_value("hello", pc.many(pc.char("i")), Ok([]))
}

pub fn many_matches_on_empty_input_test() -> Nil {
  assert_with_input_parser_value("", pc.many(pc.char("i")), Ok([]))
}

pub fn many_matches_multiple_test() -> Nil {
  assert_with_input_parser_value(
    "xxxxhi",
    pc.many(pc.char("x")),
    Ok(["x", "x", "x", "x"]),
  )
}

pub fn many1_fails_match_zero_times_test() -> Nil {
  assert_with_input_parser_predicate(
    "hxxxx",
    pc.many1(pc.char("x")),
    result.is_error,
  )
}

pub fn many1_matches_multiple_times_test() -> Nil {
  assert_with_input_parser_value(
    "xxxxhi",
    pc.many1(pc.char("x")),
    Ok(["x", "x", "x", "x"]),
  )
}

pub fn look_ahead_succeeds_without_consuming_input_test() {
  assert_with_input_parser_value(
    "]a",
    pc.sequence(pc.look_ahead(pc.char("]")), fn(_) { pc.string("]a") }),
    Ok("]a"),
  )
}

pub fn string_until_fails_empty_test() -> Nil {
  assert_with_input_parser_predicate("", pc.string_until(")"), result.is_error)
}

pub fn string_until_fails_when_out_of_input_test() -> Nil {
  assert_with_input_parser_predicate(
    "hello hiii yooyoyoyoyo",
    pc.string_until(")"),
    result.is_error,
  )
}

pub fn string_until_succeeds_with_correct_string_test() -> Nil {
  assert_with_input_parser_value("]", pc.string_until("]"), Ok(""))
}

pub fn string_until_succeeds_with_longer_correct_string_test() -> Nil {
  assert_with_input_parser_value("h]", pc.string_until("]"), Ok("h"))
}

pub fn string_until_does_not_consume_last_character_test() -> Nil {
  assert_with_input_parser_value(
    "]",
    pc.sequence(pc.string_until("]"), fn(_) { pc.char("]") }),
    Ok("]"),
  )
}

pub fn eof_parser_test() -> Nil {
  parses_with_value("", pc.eof(), "")
}

pub fn eof_parser_2_test() -> Nil {
  parses_with_value(
    "hii",
    pc.sequence(pc.string("hii"), fn(_) { pc.eof() }),
    "",
  )
}
