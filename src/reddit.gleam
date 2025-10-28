import argv
import engine
import gleam/erlang/process
import gleam/int
import gleam/io
import pub_types.{type EngineMessage}
import simulator

pub fn main() -> Nil {
  let args = argv.load().arguments
  case args {
    [arg1] -> {
      let num_clients = int.parse(arg1)
      case num_clients {
        Ok(num_clients) -> {
          let main_process = process.new_subject()
          let assert Ok(engine) = engine.start_engine()
          run_simulation(main_process, engine.data, num_clients)
        }
        _ -> {
          io.println("Argument must be of type integer")
        }
      }
    }
    _ -> {
      io.println("Please provide one argument for number of users")
    }
  }
}

fn run_simulation(
  main_process: process.Subject(String),
  engine: process.Subject(EngineMessage),
  num_clients: Int,
) {
  io.println(
    "Starting Reddit simulation with "
    <> int.to_string(num_clients)
    <> " clients",
  )
  let _simulator = simulator.start_simulator(main_process, engine, num_clients)
  process.sleep(1000)
}
