import client
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
import pub_types.{
  type ClientMessage, type EngineMessage, type SimulatorMessage,
  ClientJoinSubreddit, StartSimulator,
}

const avg_subreddits_per_user = 5

const zipf_s_subreddits = 1.0

const zipf_s_clients = 0.5

pub type SimulatorState {
  SimulatorState(
    main_process: Subject(String),
    engine_subject: Subject(EngineMessage),
    self_subject: Subject(SimulatorMessage),
    num_clients: Int,
    num_subreddits: Int,
    clients: Dict(Int, Subject(ClientMessage)),
    zipf_distribution_subreddits: List(Float),
    zipf_distribution_clients: List(Float),
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
      let num_subreddits = num_clients / 2
      let zipf_subreddits = zipf_distribution(num_subreddits, zipf_s_subreddits)
      let zipf_clients = zipf_distribution(num_clients, zipf_s_clients)
      let state =
        SimulatorState(
          main_process,
          engine_subject,
          self_subject,
          num_clients,
          num_clients / 2,
          dict.new(),
          zipf_subreddits,
          zipf_clients,
        )
      let _result =
        Ok(actor.initialised(state) |> actor.returning(self_subject))
    })
    |> actor.on_message(handle_message_simulator)
    |> actor.start
}

fn handle_message_simulator(
  state: SimulatorState,
  message: SimulatorMessage,
) -> actor.Next(SimulatorState, SimulatorMessage) {
  case message {
    StartSimulator -> {
      let new_state = spawn_clients(state, 1)
      let assert Ok(client1) = dict.get(new_state.clients, 1)
      create_subreddits(state.num_subreddits, new_state.engine_subject, client1)
      process.sleep(100)
      assign_subreddits(new_state, avg_subreddits_per_user)
      process.sleep(100)
      process.send(new_state.engine_subject, pub_types.PrintSubredditSizes)
      process.send(client1, pub_types.Connect)
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

// --- INITIALIZATION FUNCTIONS

fn zipf_distribution(n: Int, s: Float) {
  let ranks = list.range(1, n)
  let weights =
    list.map(ranks, fn(rank) {
      let assert Ok(denominator) = float.power(int.to_float(rank), s)
      1.0 /. denominator
    })
  let total = list.fold(weights, 0.0, fn(w, acc) { acc +. w })
  list.map(weights, fn(w) { w /. total })
}

fn create_subreddits(
  n: Int,
  engine: Subject(pub_types.EngineMessage),
  client: Subject(ClientMessage),
) {
  case n {
    n if n > 0 -> {
      process.send(
        engine,
        pub_types.CreateSubReddit("subreddit" <> int.to_string(n), client),
      )
      create_subreddits(n - 1, engine, client)
    }
    _ -> {
      Nil
    }
  }
}

fn assign_subreddits(state: SimulatorState, num_to_join: Int) {
  let cumulative =
    list.scan(state.zipf_distribution_subreddits, 0.0, fn(w, acc) { acc +. w })

  let total_joins = int.to_float(avg_subreddits_per_user * state.num_clients)
  let subreddits_to_join =
    list.map(state.zipf_distribution_clients, fn(w) {
      float.round(w *. total_joins) |> int.clamp(1, state.num_subreddits)
    })
  echo list.fold(subreddits_to_join, 0, fn(x, y) { x + y })

  let clients_list =
    dict.to_list(state.clients)
    |> list.sort(fn(a, b) { int.compare(a.0, b.0) })
  let paired = list.zip(clients_list, subreddits_to_join)

  list.each(paired, fn(pair) {
    let #(client_entry, count) = pair
    let #(_id, client) = client_entry
    let subreddit_ids = pick_unique_weighted_ids(cumulative, count)
    process.send(client, ClientJoinSubreddit(subreddit_ids))
  })
}

pub fn pick_unique_weighted_ids(
  cumulative: List(Float),
  count: Int,
) -> List(String) {
  let total = list.last(cumulative) |> result.unwrap(1.0)
  let cum_index = list.index_map(cumulative, fn(n, ind) { #(ind, n) })
  pick_loop(cum_index, [], total, count)
}

pub fn pick_loop(
  cumulative: List(#(Int, Float)),
  selected: List(String),
  total: Float,
  count: Int,
) {
  case list.length(selected) >= count {
    True -> selected
    False -> {
      let random = float.random() *. total
      let first = list.find(cumulative, fn(p) { p.1 >=. random })
      let new_selected = case first {
        Ok(p) -> {
          case list.contains(selected, "subreddit" <> int.to_string(p.0 + 1)) {
            True -> selected
            False ->
              list.append(selected, ["subreddit" <> int.to_string(p.0 + 1)])
          }
        }
        _ -> selected
      }
      pick_loop(cumulative, new_selected, total, count)
    }
  }
}
