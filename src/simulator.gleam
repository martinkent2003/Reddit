import client
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/io
import gleam/otp/actor
import pub_types.{type ClientMessage, type EngineMessage, type SimulatorMessage, StartSimulator}

pub type SimulatorState {
  SimulatorState(
    main_process: Subject(String),
    engine_subject: Subject(EngineMessage),
    self_subject: Subject(SimulatorMessage),
    num_clients: Int,
    clients: Dict(Int, Subject(ClientMessage)),
  )
}

pub fn start_simulator(
  main_process: Subject(String),
  engine_subject: Subject(EngineMessage),
  num_clients: Int,
) {
  let _ =
    actor.new_with_initialiser(1000, fn(self_subject) {
      process.send(self_subject, StartSimulator)
      let state =
        SimulatorState(
          main_process,
          engine_subject,
          self_subject,
          num_clients,
          dict.new(),
        )
      let _result =
        Ok(actor.initialised(state) |> actor.returning(self_subject))
    })
    |> actor.on_message(handle_message_simulator)
    |> actor.start
}

fn handle_message_simulator(state: SimulatorState, message: SimulatorMessage) -> actor.Next(SimulatorState, SimulatorMessage) {
  case message {
    StartSimulator-> {
      let new_state = spawn_clients(state, 1)
      actor.continue(new_state)
    }
  }
}

fn spawn_clients(state: SimulatorState, curr_user_id) {
  case curr_user_id {
    curr_user_id if curr_user_id <= state.num_clients -> {
      let assert Ok(new_client) =
        client.start_client(
          state.self_subject,
          state.engine_subject,
          int.to_string(curr_user_id),
        )
      let updated_clients =
        dict.insert(state.clients, curr_user_id, new_client.data)
      let updated_state = SimulatorState(..state, clients: updated_clients)
      spawn_clients(updated_state, curr_user_id + 1)
    }
    _ -> {
      state
    }
  }
}
