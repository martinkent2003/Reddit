import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/string
import in
import pub_types.{type Post}

const default_base = "http://127.0.0.1:8000"

const actions_prompt = "\n=== Reddit Client Menu ===
1) Create subreddit
2) Join subreddit
3) Leave subreddit
4) Post in subreddit
5) Comment in subreddit
6) Get comment
7) Upvote
8) Downvote
9) Request karma
10) Request feed
11) Send message
12) Request inbox
q) Quit
> "

pub fn main()-> Nil{
  start_cli()
}

fn perform_health_check() -> Bool {
  case request.to(default_base) {
    Ok(req) -> {
      let req = request.set_method(req, http.Get)
      case httpc.send(req) {
        Ok(_) -> True
        Error(_) -> False
      }
    }
    Error(_) -> False
  }
}

fn start_health_check_monitor() {
  spawn_link(fn() {
    process.sleep(10_000)
    health_check_loop()
  })
  Nil
}

fn health_check_loop() -> Nil {
  case perform_health_check() {
    False -> {
      print_header("xX Server Connection Lost Xx")
      io.println("  The server is no longer responding.")
      io.println("  Exiting CLI...\n")
      process.sleep(1000)
      halt_application()
    }
    True -> {
      process.sleep(10_000)
      health_check_loop()
    }
  }
}

@external(erlang, "erlang", "spawn_link")
fn spawn_link(func: fn() -> Nil) -> process.Pid

@external(erlang, "erlang", "halt")
fn halt_application() -> Nil

fn print_separator() {
  io.println("─────────────────────────────────────────────────────")
}

fn print_header(title: String) {
  io.println("")
  print_separator()
  io.println("  " <> title)
  print_separator()
}

fn print_field(label: String, value: String, indent: Int) {
  let indent_str = string.repeat(" ", indent)
  io.println(indent_str <> label <> ": " <> value)
}


fn feed_response_decoder() -> decode.Decoder(#(String, List(Post))) {
  use user_id <- decode.field("user_id", decode.string)
  use posts <- decode.field("posts", decode.list(post_decoder()))
  decode.success(#(user_id, posts))
}

fn post_decoder() -> decode.Decoder(Post) {
  use post_id <- decode.field("post_id", decode.string)
  use user_id <- decode.field("user_id", decode.string)
  use subreddit_id <- decode.field("subreddit_id", decode.string)
  use post_content <- decode.field("post_content", decode.string)
  // comments is optional - default empty list if not present
  use comments <- decode.optional_field("comments", [], decode.list(decode.string))
  use upvotes <- decode.field("upvotes", decode.int)
  use downvotes <- decode.field("downvotes", decode.int)
  decode.success(pub_types.Post(
    post_id: post_id,
    user_id: user_id,
    subreddit_id: subreddit_id,
    post_content: post_content,
    comments: comments,
    upvotes: upvotes,
    downvotes: downvotes,
  ))
}


fn print_post(post: Post, index: Int) {
  io.println("\n  Post #" <> int.to_string(index + 1))
  print_field("post_id", post.post_id, 4)
  print_field("user_id", post.user_id, 4)
  print_field("subreddit_id", post.subreddit_id, 4)
  print_field("post_content", post.post_content, 4)

  // Display comments if any exist
  case list.length(post.comments) {
    0 -> Nil
    count -> {
      print_field("comments", int.to_string(count) <> " comment(s)", 4)
      list.each(post.comments, fn(comment_id) {
        io.println("      - " <> comment_id)
      })
    }
  }

  print_field("upvotes", int.to_string(post.upvotes), 4)
  print_field("downvotes", int.to_string(post.downvotes), 4)
}

fn clean_json_string(s: String) -> String {
  s
  |> string.replace("{", "")
  |> string.replace("}", "")
  |> string.replace("[", "")
  |> string.replace("]", "")
  |> string.replace("\"", "")
}

fn print_key_value_pairs(json_str: String, indent: Int) {
  let cleaned = clean_json_string(json_str)
  let parts = string.split(cleaned, ",")
  list.each(parts, fn(part) {
    case string.split(part, ":") {
      [key, value] ->
        print_field(string.trim(key), string.trim(value), indent)
      _ -> Nil
    }
  })
}

fn format_and_display_response(body: String, path: String) {
  case path {
    "/register_account" | "/create_subreddit" | "/join_subreddit" |
    "/leave_subreddit" | "/post_in_subreddit" | "/comment_in_subreddit" |
    "/upvote" | "/downvote" | "/send_message" -> {
      print_header("ツSuccess")
      case string.contains(body, "message") {
        True -> {
          let cleaned = clean_json_string(body)
          let parts = string.split(cleaned, ",")
          list.each(parts, fn(part) {
            case string.split(part, ":") {
              [key, value] -> {
                case string.contains(key, "message") {
                  True -> io.println("  " <> string.trim(value))
                  False -> print_field(string.trim(key), string.trim(value), 2)
                }
              }
              _ -> Nil
            }
          })
        }
        False -> print_key_value_pairs(body, 2)
      }
      io.println("")
    }

    "/request_karma" -> {
      print_header("Karma Information")
      print_key_value_pairs(body, 2)
      io.println("")
    }

    "/get_comment" -> {
      print_header("Comment Details")
      print_key_value_pairs(body, 2)
      io.println("")
    }

    "/request_feed" -> {
      print_header("Feed")

      // Parse and decode the JSON response
      case json.parse(body, feed_response_decoder()) {
        Ok(#(_user_id, posts)) -> {
          case list.length(posts) {
            0 -> io.println("  No posts in feed")
            _ -> {
              list.index_map(posts, fn(post, idx) {
                print_post(post, idx)
              })
              Nil
            }
          }
        }
        Error(_) -> {
          io.println("  Failed to parse feed response")
          io.println("  Raw: " <> body)
        }
      }
      io.println("")
    }

    "/request_inbox" -> {
      print_header("Inbox")
      case string.contains(body, "[") && string.contains(body, "]") {
        True -> {
          let msgs_str = string.replace(body, "[", "")
          let msgs_str = string.replace(msgs_str, "]", "")
          case string.length(string.trim(msgs_str)) > 2 {
            True -> {
              let messages = string.split(msgs_str, "},")
              let _ = list.index_map(messages, fn(msg, idx) {
                io.println("\n  Message #" <> int.to_string(idx + 1))
                print_key_value_pairs(msg, 4)
              })
              Nil
            }
            False -> io.println("  No messages")
          }
        }
        False -> io.println("  No messages")
      }
      io.println("")
    }

    _ -> {
      print_header("Response")
      io.println("  " <> body)
      io.println("")
    }
  }
}

fn send_post_request(path: String, body: String) -> Result(String, String) {
  case request.to(default_base) {
    Error(_) -> {
      print_header("X Connection Error")
      io.println("  Unable to create request to server.")
      io.println("  Please check the server address and try again.")
      io.println("")
      Error("Failed to create request")
    }
    Ok(req) -> {
      let req =
        request.set_method(req, http.Post)
        |> request.set_path(path)
        |> request.set_header("content-type", "application/x-www-form-urlencoded")
        |> request.set_body(body)

      case httpc.send(req) {
        Error(_) -> {
          print_header("X Server Connection Failed")
          io.println("  Unable to connect to the server at " <> default_base)
          io.println("  Please ensure:")
          io.println("    - The server is running")
          io.println("    - The server address is correct")
          io.println("    - There are no network issues")
          io.println("")
          Error("Connection failed")
        }
        Ok(resp) -> {
          case resp.status {
            200 | 201 -> {
              format_and_display_response(resp.body, path)
              Ok(resp.body)
            }
            _ -> {
              print_header("X Error " <> int.to_string(resp.status))
              io.println("  " <> resp.body)
              io.println("")
              Error(resp.body)
            }
          }
        }
      }
    }
  }
}

fn handle_response_and_reprompt(
  result: Result(String, String),
  operation: String,
  retry_fn: fn() -> Nil,
) -> Nil {
  case result {
    Ok(_) -> Nil
    Error(_) -> {
      io.println("\n" <> operation <> " failed. Would you like to try again? (y/n)")
      let assert Ok(choice) = in.read_line()
      case string.trim(choice) {
        "y" | "Y" -> retry_fn()
        _ -> Nil
      }
    }
  }
}

fn create_subreddit() {
  io.print("Subreddit ID: ")
  let assert Ok(sr_id) = in.read_line()
  let sr_id = string.trim(sr_id)
  let result = send_post_request("/create_subreddit", "sr_id=" <> sr_id)
  handle_response_and_reprompt(result, "Create subreddit", create_subreddit)
}

fn join_subreddit(user_id: String) {
  io.print("Subreddit ID: ")
  let assert Ok(sr_id) = in.read_line()
  let sr_id = string.trim(sr_id)
  let result = send_post_request(
    "/join_subreddit",
    "user_id=" <> user_id <> "&sr_id=" <> sr_id,
  )
  handle_response_and_reprompt(result, "Join subreddit", fn() {
    join_subreddit(user_id)
  })
}

fn leave_subreddit(user_id: String) {
  io.print("Subreddit ID: ")
  let assert Ok(sr_id) = in.read_line()
  let sr_id = string.trim(sr_id)
  let result = send_post_request(
    "/leave_subreddit",
    "user_id=" <> user_id <> "&sr_id=" <> sr_id,
  )
  handle_response_and_reprompt(result, "Leave subreddit", fn() {
    leave_subreddit(user_id)
  })
}

fn post_in_subreddit(user_id: String) {
  io.print("Subreddit ID: ")
  let assert Ok(sr_id) = in.read_line()
  let sr_id = string.trim(sr_id)
  io.print("Post text: ")
  let assert Ok(post_text) = in.read_line()
  let post_text = string.trim(post_text)
  let result = send_post_request(
    "/post_in_subreddit",
    "user_id=" <> user_id <> "&sr_id=" <> sr_id <> "&post_text=" <> post_text,
  )
  handle_response_and_reprompt(result, "Post in subreddit", fn() {
    post_in_subreddit(user_id)
  })
}

fn comment_in_subreddit(user_id: String) {
  io.print("Parent ID (post or comment): ")
  let assert Ok(parent_id) = in.read_line()
  let parent_id = string.trim(parent_id)
  io.print("Comment text: ")
  let assert Ok(comment_text) = in.read_line()
  let comment_text = string.trim(comment_text)
  let result = send_post_request(
    "/comment_in_subreddit",
    "parent_id=" <> parent_id <> "&user_id=" <> user_id <> "&comment_text=" <> comment_text,
  )
  handle_response_and_reprompt(result, "Comment in subreddit", fn() {
    comment_in_subreddit(user_id)
  })
}

fn get_comment() {
  io.print("Comment ID: ")
  let assert Ok(comment_id) = in.read_line()
  let comment_id = string.trim(comment_id)
  let result = send_post_request("/get_comment", "comment_id=" <> comment_id)
  handle_response_and_reprompt(result, "Get comment", get_comment)
}

fn upvote() {
  io.print("Parent ID (post or comment): ")
  let assert Ok(parent_id) = in.read_line()
  let parent_id = string.trim(parent_id)
  let result = send_post_request("/upvote", "parent_id=" <> parent_id)
  handle_response_and_reprompt(result, "Upvote", upvote)
}

fn downvote() {
  io.print("Parent ID (post or comment): ")
  let assert Ok(parent_id) = in.read_line()
  let parent_id = string.trim(parent_id)
  let result = send_post_request("/downvote", "parent_id=" <> parent_id)
  handle_response_and_reprompt(result, "Downvote", downvote)
}

fn request_karma(user_id: String) {
  let result = send_post_request("/request_karma", "user_id=" <> user_id)
  handle_response_and_reprompt(result, "Request karma", fn() {
    request_karma(user_id)
  })
}

fn request_feed(user_id: String) {
  let result = send_post_request("/request_feed", "user_id=" <> user_id)
  handle_response_and_reprompt(result, "Request feed", fn() {
    request_feed(user_id)
  })
}

fn send_message(user_id: String) {
  io.print("To user ID: ")
  let assert Ok(to_user_id) = in.read_line()
  let to_user_id = string.trim(to_user_id)
  io.print("Message: ")
  let assert Ok(message) = in.read_line()
  let message = string.trim(message)
  let result = send_post_request(
    "/send_message",
    "from_user_id=" <> user_id <> "&to_user_id=" <> to_user_id <> "&message=" <> message,
  )
  handle_response_and_reprompt(result, "Send message", fn() {
    send_message(user_id)
  })
}

fn request_inbox(user_id: String) {
  let result = send_post_request("/request_inbox", "user_id=" <> user_id)
  handle_response_and_reprompt(result, "Request inbox", fn() {
    request_inbox(user_id)
  })
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
    "3" -> {
      leave_subreddit(user_id)
      prompt_user_action(user_id)
    }
    "4" -> {
      post_in_subreddit(user_id)
      prompt_user_action(user_id)
    }
    "5" -> {
      comment_in_subreddit(user_id)
      prompt_user_action(user_id)
    }
    "6" -> {
      get_comment()
      prompt_user_action(user_id)
    }
    "7" -> {
      upvote()
      prompt_user_action(user_id)
    }
    "8" -> {
      downvote()
      prompt_user_action(user_id)
    }
    "9" -> {
      request_karma(user_id)
      prompt_user_action(user_id)
    }
    "10" -> {
      request_feed(user_id)
      prompt_user_action(user_id)
    }
    "11" -> {
      send_message(user_id)
      prompt_user_action(user_id)
    }
    "12" -> {
      request_inbox(user_id)
      prompt_user_action(user_id)
    }
    "q" | "Q" -> {
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
  // First, check if server is available
  io.println("Connecting to server at " <> default_base <> "...")
  case perform_health_check() {
    False -> {
      print_header("X Server Unavailable")
      io.println("  Cannot connect to the server.")
      io.println("  Please ensure the server is running and try again.")
      io.println("")
      Nil
    }
    True -> {
      io.println("ツ Connected to server successfully\n")

      // Start the health check monitor
      start_health_check_monitor()

      let user_id = get_user_id()
      let result = send_post_request("/register_account", "user_id=" <> user_id)
      case result {
        Ok(_) -> prompt_user_action(user_id)
        Error(_) -> {
          io.println("\nFailed to register account. Please try again.")
          start_cli()
        }
      }
    }
  }
}
