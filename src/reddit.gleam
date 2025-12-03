import app/router
import engine
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  let _main_process = process.new_subject()
  let assert Ok(engine) = engine.start_engine()
  // NOT STARTING SIMULATOR 
  //run_simulation(main_process, engine.data, num_clients)
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    wisp_mist.handler(
      fn(req) { router.handle_request(req, engine.data) },
      secret_key_base,
    )
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep(1000)
  process.sleep_forever()
  Nil
}

// fn run_simulation(
//   main_process: process.Subject(String),
//   engine: process.Subject(EngineMessage),
//   num_clients: Int,
// ) {
//   io.println(
//     "Starting Reddit simulation with "
//     <> int.to_string(num_clients)
//     <> " clients",
//   )
//   let assert Ok(_simulator) =
//     simulator.start_simulator(main_process, engine, num_clients)
//   let _response = process.receive_forever(main_process)
//   Nil
// }
