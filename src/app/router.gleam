import gleam/http/response
import gleam/io
import app/web
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/list
import gleam/result
import wisp.{type Request, type Response}

import pub_types.{type ClientMessage, type EngineMessage, RegisterAccount,CreateSubReddit,JoinSubreddit,LeaveSubreddit, ListAck, Ack, Nack}

pub fn handle_request(
  req: Request,
  engine: process.Subject(EngineMessage),
) -> Response {
  use req <- web.middleware(req)
  case wisp.path_segments(req) {
    // This matches `/`.
    [] -> health_check(req)
    ["comments"] -> comments(req)
    ["comments", id] -> show_comment(req, id)
    //our implementation (not example wisp code anymore)
    //TODO somehow get the engine message in here and get a 1:1 for each engine message
    ["register_account"] -> register_account(req, engine)
    ["create_subreddit"] -> create_subreddit(req, engine)
    ["join_subreddit"] -> join_subreddit(req, engine)
    ["leave_subreddit"] -> leave_subreddit(req, engine)
    //
    // This matches all other paths.
    _ -> wisp.not_found()
  }
}

fn health_check(req: Request) -> Response {
  // The home page can only be accessed via GET requests, so this middleware is
  // used to return a 405: Method Not Allowed response for all other methods.
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.html_body("api working")
}

fn comments(req: Request) -> Response {
  // This handler for `/comments` can respond to both GET and POST requests,
  // so we pattern match on the method here.
  case req.method {
    Get -> list_comments()
    Post -> create_comment(req)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn list_comments() -> Response {
  // In a later example we'll show how to read from a database.
  wisp.ok()
  |> wisp.html_body("Comments!")
}

fn create_comment(_req: Request) -> Response {
  // In a later example we'll show how to parse data from the request body.
  wisp.created()
  |> wisp.html_body("Created")
}

fn show_comment(req: Request, id: String) -> Response {
  use <- wisp.require_method(req, Get)

  // The `id` path parameter has been passed to this function, so we could use
  // it to look up a comment in a database.
  // For now we'll just include in the response body.
  wisp.ok()
  |> wisp.html_body("Comment with id " <> id)
}

fn register_account(
  req: Request,
  engine: process.Subject(EngineMessage),
) -> Response {
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)
  // Now you can send messages to the engine:
  let result = {
    use user_id <- result.try(list.key_find(formdata.values, "user_id"))
    let subject = process.new_subject()
    process.send(engine, RegisterAccount(user_id, subject))
    let response = process.receive_forever(subject)
    echo response
    case response{
      Ack(message)->{
        Ok(message)
      }
      Nack(message)->{
        wisp.log_error(message)
        Error(Nil)
      }
      _-> {
        wisp.log_error("not a correct message (register account)")
        Error(Nil)
      }
    }
  }

  case result {
    Ok(content) -> {
      wisp.ok()
      |> wisp.html_body(content)
    }
    Error(_) -> {
      wisp.bad_request("Invalid form")
    }
  }
}

fn create_subreddit(req: Request, engine: process.Subject(EngineMessage)) -> Response {
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)
  let result = {
    use sr_id <- result.try(list.key_find(formdata.values, "sr_id"))
    let subject = process.new_subject()
    process.send(engine, CreateSubReddit(sr_id, subject))
    let response = process.receive_forever(subject)
    echo response
    case response{
      Ack(message)->{
        Ok(message)
      }
      Nack(message)->{
        wisp.log_error(message)
        Error(Nil)
      }
      _ -> {
        wisp.log_error("not a correct message (create subreddit)")
        Error(Nil)
      }
    }
  }
    case result {
    Ok(content) -> {
      wisp.ok()
      |> wisp.html_body(content)
    }
    Error(_) -> {
      wisp.bad_request("Invalid form")
    }
  }
}

fn join_subreddit(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)
  let result = {
    use user_id <- result.try(list.key_find(formdata.values, "user_id"))
    use sr_id <- result.try(list.key_find(formdata.values, "sr_id"))
    let subject = process.new_subject()
    process.send(engine, JoinSubreddit(user_id, sr_id, subject))
    let response = process.receive_forever(subject)
    echo response
    case response{
      Ack(message)->{
        Ok(message)
      }
      Nack(message)->{
        wisp.log_error(message)
        Error(Nil)
      }
      _->{
        wisp.log_error("not a correct message (join subreddit)")
        Error(Nil)
      }
    }
  }
  case result {
    Ok(content) -> {
      wisp.ok()
      |> wisp.html_body(content)
    }
    Error(_) -> {
      wisp.bad_request("Invalid form")
    }
  }
}


fn leave_subreddit(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)
  let result = {
    use user_id <- result.try(list.key_find(formdata.values, "user_id"))
    use sr_id <- result.try(list.key_find(formdata.values, "sr_id"))
    let subject = process.new_subject()
    process.send(engine, LeaveSubreddit(user_id, sr_id, subject))
    let response = process.receive_forever(subject)
    echo response
    case response{
      Ack(message)->{
        Ok(message)
      }
      Nack(message)->{
        wisp.log_error(message)
        Error(Nil)
      }
      _->{
        wisp.log_error("not a correct message (join subreddit)")
        Error(Nil)
      }
    }
  }
  case result {
    Ok(content) -> {
      wisp.ok()
      |> wisp.html_body(content)
    }
    Error(_) -> {
      wisp.bad_request("Invalid form")
    }
  }
}