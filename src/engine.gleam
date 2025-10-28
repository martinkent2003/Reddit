import gleam/io
import gleam/otp/actor

pub fn start_engine() {
  let _ =
    actor.new_with_initialiser(1000, fn(self_subject) {
      let state = ""
      let _result =
        Ok(actor.initialised(state) |> actor.returning(self_subject))
    })
    |> actor.on_message(handle_message_engine)
    |> actor.start
}

fn handle_message_engine(
  state: String,
  message: String,
) -> actor.Next(String, String) {
  case message {
    _ -> {
      io.println(message)
      actor.continue(state)
    }
  }
}
