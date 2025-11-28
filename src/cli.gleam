import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/string
import in

const default_base = "http://127.0.0.1:8000"

const actions_prompt = "\n1) Create subreddit\n2) Join Subreddit\nq) Quit\n> "

fn send_post_request(path: String, body: String) {
  let assert Ok(req) = request.to(default_base)
  let req =
    request.set_method(req, http.Post)
    |> request.set_path(path)
    |> request.set_header("content-type", "application/x-www-form-urlencoded")
    |> request.set_body(body)

  let assert Ok(resp) = httpc.send(req)
  case resp.status {
    200 | 201 -> io.println(resp.body)
    _ -> io.println("Error " <> int.to_string(resp.status) <> ": " <> resp.body)
  }
}

fn create_subreddit() {
  io.print("Subreddit ID: ")
  let assert Ok(sr_id) = in.read_line()
  let sr_id = string.trim(sr_id)
  send_post_request("/create_subreddit", "sr_id=" <> sr_id)
}

fn join_subreddit(user_id: String) {
  io.print("Subreddit ID: ")
  let assert Ok(sr_id) = in.read_line()
  let sr_id = string.trim(sr_id)
  send_post_request(
    "/join_subreddit",
    "user_id=" <> user_id <> "&sr_id=" <> sr_id,
  )
}

fn prompt_user_action(user_id: String) {
  io.print(actions_prompt)
  let assert Ok(action) = in.read_line()
  case string.trim(action) {
    "1" -> {
      create_subreddit()
      prompt_user_action(user_id)
    }
    "2" -> {
      join_subreddit(user_id)
      prompt_user_action(user_id)
    }
    "q" -> {
      io.println("Thank you for using Reddit")
      Nil
    }
    _ -> {
      io.println("Invalid Action Selected")
      prompt_user_action(user_id)
    }
  }
}

fn get_user_id() {
  io.print("Choose username: ")
  let username = in.read_line()
  case username {
    Ok(username) -> {
      case string.length(username) > 3 {
        True -> string.trim(username)
        False -> {
          io.println("Username must be at least 3 characters")
          get_user_id()
        }
      }
    }
    Error(_) -> {
      io.println("There's something wrong with the username you chose")
      get_user_id()
    }
  }
}

pub fn start_cli() {
  let user_id = get_user_id()
  send_post_request("/register_account", "user_id=" <> user_id)
  prompt_user_action(user_id)
}
