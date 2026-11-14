import gleam/list

pub type State(s, a) =
  fn(s) -> #(a, s)

pub type FailableState(s, a, e) =
  fn(s) -> #(Result(a, e), s)

pub fn return(output: a) -> State(s, a) {
  fn(state: s) { #(output, state) }
}

pub fn bind(eval: State(s, a), f: fn(a) -> State(s, b)) -> State(s, b) {
  fn(state: s) {
    let #(output, new_state) = eval(state)
    f(output)(new_state)
  }
}

pub fn try_bind(
  eval: FailableState(s, a, err),
  f: fn(a) -> FailableState(s, b, err),
) -> FailableState(s, b, err) {
  fn(state: s) {
    let #(output_result, new_state) = eval(state)
    case output_result {
      Ok(output) -> f(output)(new_state)
      Error(e) -> #(Error(e), state)
    }
  }
}

pub fn sequence(eval_list: List(State(s, a))) -> State(s, List(a)) {
  case eval_list {
    [] -> return([])
    [first, ..rest] -> {
      use output_first <- bind(first)
      use output_rest <- bind(sequence(rest))
      return([output_first, ..output_rest])
    }
  }
}

pub fn run(eval: State(s, a), state: s) -> #(a, s) {
  eval(state)
}

pub fn eval_state(eval: State(s, a), state: s) -> a {
  eval(state).0
}

pub fn exec_state(eval: State(s, a), state: s) -> s {
  eval(state).1
}

pub fn put(state: s) -> State(s, Nil) {
  fn(_: s) { #(Nil, state) }
}

pub fn get() -> State(s, s) {
  fn(state: s) { #(state, state) }
}

pub fn modify(f: fn(s) -> s) -> State(s, Nil) {
  fn(state: s) { #(Nil, f(state)) }
}

pub fn gets(f: fn(s) -> a) -> State(s, a) {
  fn(state: s) { #(f(state), state) }
}

pub fn replicate(eval_item: State(s, a), repeat: Int) -> State(s, List(a)) {
  sequence(list.repeat(eval_item, repeat))
}

pub fn fold_right(
  over: List(a),
  initial: State(s, b),
  state_cons: fn(a, b) -> State(s, b),
) -> State(s, b) {
  list.fold_right(over, initial, fn(state_rest, value) {
    use rest <- bind(state_rest)
    state_cons(value, rest)
  })
}

pub fn fold(
  over over: List(a),
  with_initial_state initial: State(s, b),
  combined_by state_append: fn(b, a) -> State(s, b),
) -> State(s, b) {
  list.fold(over, initial, fn(state_acc, value) {
    use acc <- bind(state_acc)
    state_append(acc, value)
  })
}

pub fn map(f: fn(a) -> State(s, b), over: List(a)) -> State(s, List(b)) {
  fold(over, return([]), fn(rest, value) {
    use mapped_value <- bind(f(value))
    return(list.append(rest, [mapped_value]))
  })
}

// Like `map`, but with no returned value. Useful for when we only care about the state changes the `map` would bring us.
pub fn for_each(
  run f: fn(a) -> State(s, b),
  over items: List(a),
) -> State(s, Nil) {
  fold(
    over: items,
    with_initial_state: return(Nil),
    combined_by: fn(_rest, value) {
      use _ <- bind(f(value))
      return(Nil)
    },
  )
}
