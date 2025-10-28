import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import pub_types.{type ClientMessage, type EngineMessage, type SimulatorMessage, RegisterAccount}

pub type ClientState {
  ClientState(
    simulator_subject: process.Subject(SimulatorMessage),
    engine_subject: process.Subject(EngineMessage),
    self_subject: process.Subject(ClientMessage),
    user_id: String,
  )
}

pub fn start_client(
  simulator_subject: process.Subject(SimulatorMessage),
  engine_subject: process.Subject(EngineMessage),
  user_id: String,
) {
  let _ =
    actor.new_with_initialiser(1000, fn(self_subject) {
      process.send(engine_subject, RegisterAccount(user_id, self_subject))
      let state =
        ClientState(simulator_subject, engine_subject, self_subject, user_id)
      let _result =
        Ok(actor.initialised(state) |> actor.returning(self_subject))
    })
    |> actor.on_message(handle_message_client)
    |> actor.start
}

fn handle_message_client(
  state: ClientState,
  message: ClientMessage,
) -> actor.Next(ClientState, ClientMessage) {
  case message {
    _ -> {
      io.println("Client " <> state.user_id <> " received unknown message")
      actor.continue(state)
    }
  }
}
