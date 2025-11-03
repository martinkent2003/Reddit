import gleam/erlang/process
import pub_types.{type ClientMessage, ActivitySim}

pub fn start_ticker(target: process.Subject(ClientMessage), interval_ms: Int) {
  process.spawn(fn() { ticker_loop(target, interval_ms) })
}

fn ticker_loop(target: process.Subject(ClientMessage), interval_ms: Int) {
  process.sleep(interval_ms)
  process.send(target, ActivitySim)
  ticker_loop(target, interval_ms)
}
