import gleam/erlang/process
import gleam/otp/actor

pub type SimulatorState {
  SimulatorState(
    main_process: process.Subject(String),
    engine_subject: process.Subject(String),
    num_clients: Int,
  )
}

pub fn start_simulator(
  main_process: process.Subject(String),
  engine_subject: process.Subject(String),
  num_clients: Int,
) {
  let _ =
    actor.new_with_initialiser(1000, fn(self_subject) {
      process.send(self_subject, "")
      let state = SimulatorState(main_process, engine_subject, num_clients)
      let _result =
        Ok(actor.initialised(state) |> actor.returning(self_subject))
    })
    |> actor.on_message(handle_message_simulator)
    |> actor.start
}

fn handle_message_simulator(
  state: SimulatorState,
  message: String,
) -> actor.Next(SimulatorState, String) {
  case message {
    _ -> {
      process.send(state.engine_subject, "Weiner")
      actor.continue(state)
    }
  }
}
