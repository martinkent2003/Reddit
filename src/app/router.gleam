import gleam/http/response
import gleam/io
import app/web
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/list
import gleam/result
import wisp.{type Request, type Response}

import pub_types.{type ClientMessage, type EngineMessage, RegisterAccount,CreateSubReddit,JoinSubreddit,LeaveSubreddit,PostInSubReddit, ListAck, Ack, Nack}

pub fn handle_request(
  req: Request,
  engine: process.Subject(EngineMessage),
) -> Response {
  use req <- web.middleware(req)
  case wisp.path_segments(req) {
    [] -> health_check(req)
    //TODO  1:1 for each engine message
    ["register_account"] -> register_account(req, engine)
    ["create_subreddit"] -> create_subreddit(req, engine)
    ["join_subreddit"] -> join_subreddit(req, engine)
    ["leave_subreddit"] -> leave_subreddit(req, engine)
    ["post_in_subreddit"] -> post_in_subreddit(req, engine)
    //["comment_in_subreddit"] -> comment_in_subreddit(req, engine)
    //maybe fix these routes to more closely resemble the reddit api before doing the rest of them 
    //right now they're just kinda resembling the engine 1:1 
    //
    // This matches all other paths.
    _ -> wisp.not_found()
  }
}

fn health_check(req: Request) -> Response {
  use <- wisp.require_method(req, Get)
  wisp.ok()
  |> wisp.html_body("api working")
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

fn post_in_subreddit(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)
  let result = {
    use user_id <- result.try(list.key_find(formdata.values, "user_id"))
    use sr_id <- result.try(list.key_find(formdata.values, "sr_id"))
    use post_text <- result.try(list.key_find(formdata.values, "post_text"))
    let subject = process.new_subject()
    process.send(engine, PostInSubReddit(user_id, sr_id, post_text, subject))
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

 