import gleeunit
import glox/glox

pub fn main() -> Nil {
  gleeunit.main()
}

fn prints(input: String, output: String) -> Nil {
  let assert Ok([item]) = glox.execute_string_to_data(input)
  assert item == output
}

fn prints_these(input: String, output_list: List(String)) -> Nil {
  let assert Ok(item_list) = glox.execute_string_to_data(input)
  assert item_list == output_list
}

fn succeeds(input: String) -> Nil {
  let assert Ok(_) = glox.execute_string_to_data(input)
  Nil
}

pub fn arithmetic_test() -> Nil {
  prints("print (7+5)*3-2+1;", "35.0")
}

pub fn spacing_test() -> Nil {
  prints("print ( 7 + 5 ) * 3 - 2 + 1 ;", "35.0")
}

pub fn order_of_operations_test() -> Nil {
  prints("print -13.5*2+6>100==\"hello\"!=\"hi\";", "True")
}

pub fn multiple_statements_work_test() -> Nil {
  prints_these("print \"hi\"; print \"hello\";", ["hi", "hello"])
}

pub fn declaring_var_works_test() -> Nil {
  succeeds("var x;")
}

pub fn declaring_var_without_assignment_test() -> Nil {
  prints("var x; print x;", "Nil")
}

pub fn declaring_var_with_assignment_test() -> Nil {
  prints("var x = 7; print x;", "7.0")
}

pub fn var_can_be_used_in_expression_test() -> Nil {
  prints("var x = 5; print x + x;", "10.0")
}

pub fn redeclaring_variables_test() -> Nil {
  prints("var x = 7; var x = 1; print x;", "1.0")
}

pub fn assigning_var_test() -> Nil {
  prints("var x; x = 7; print x;", "7.0")
}

pub fn reassigning_var_test() -> Nil {
  prints("var x = 1; x = 2; x = 3; print x;", "3.0")
}

pub fn assignment_returns_value_test() -> Nil {
  prints("var x; print x = 1;", "1.0")
}

pub fn reassign_variable_to_expression_including_itself_test() -> Nil {
  prints("var x = 1; print x = x + 1;", "2.0")
}

pub fn reassigning_variables_within_nested_expressions_test() -> Nil {
  prints("var x = 2; print (x=8)+(x=(x+2));", "18.0")
}

pub fn blocks_run_code_test() -> Nil {
  prints("{print \"in a block\"; }", "in a block") 
}

pub fn blocks_run_multiple_statements_test() -> Nil {
  prints_these("print \"out\"; {print \"in a block\"; } print \"out again\";", ["out", "in a block", "out again"]) 
}

pub fn blocks_have_scope_test() -> Nil {
  prints_these("var x = 1; {print x; x = 2; print x; var x = 3; print x;} print x;", ["1.0", "2.0", "3.0", "2.0"])
}

