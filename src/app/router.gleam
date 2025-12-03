import gleam/dict
import gleam/json
import app/web
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/list
import gleam/result
import wisp.{type Request, type Response}

import pub_types.{type ClientMessage, type EngineMessage, type Comment, type Post, type DirectMessage, RegisterAccount,CreateSubReddit,JoinSubreddit,LeaveSubreddit,PostInSubReddit, CommentInSubReddit, GetComment, Upvote, Downvote, RequestKarma, RequestFeed, SendMessage, RequestInbox, Ack, Nack, ActOnComment, ReceiveKarma, ReceiveFeed, DirectMessageInbox}

pub fn handle_request(
  req: Request,
  engine: process.Subject(EngineMessage),
) -> Response {
  use req <- web.middleware(req)
  case wisp.path_segments(req) {
    [] -> health_check(req)
    ["register_account"] -> register_account(req, engine)
    ["create_subreddit"] -> create_subreddit(req, engine)
    ["join_subreddit"] -> join_subreddit(req, engine)
    ["leave_subreddit"] -> leave_subreddit(req, engine)
    ["post_in_subreddit"] -> post_in_subreddit(req, engine)
    ["comment_in_subreddit"] -> comment_in_subreddit(req, engine)
    ["get_comment"] -> get_comment(req, engine)
    ["upvote"] -> upvote(req, engine)
    ["downvote"] -> downvote(req, engine)
    ["request_karma"] -> request_karma(req, engine)
    ["request_feed"] -> request_feed(req, engine)
    ["send_message"] -> send_message(req, engine)
    ["request_inbox"] -> request_inbox(req, engine)
    _ -> wisp.not_found()
  }
}

fn health_check(req: Request) -> Response {
  use <- wisp.require_method(req, Get)
  wisp.ok()
  |> wisp.html_body("api working")
}

// Helper function to handle standard Ack/Nack responses
fn handle_ack_nack_response(
  response: ClientMessage,
  operation_name: String,
) -> Result(String, String) {
  case response {
    Ack(message) -> Ok(message)
    Nack(message) -> {
      wisp.log_error(message)
      Error(message)
    }
    _ -> {
      wisp.log_error("not a correct message (" <> operation_name <> ")")
      Error("Invalid response type")
    }
  }
}

// Helper function to send HTML response based on Result
fn html_response_from_result(result: Result(String, String)) -> Response {
  case result {
    Ok(content) -> wisp.ok() |> wisp.html_body(content)
    Error(error_msg) -> wisp.bad_request(error_msg)
  }
}

// Helper function to send JSON response based on Result
fn json_response_from_result(result: Result(String, String)) -> Response {
  case result {
    Ok(json_str) -> wisp.json_response(json_str, 200)
    Error(error_msg) -> wisp.bad_request(error_msg)
  }
}

fn register_account(
  req: Request,
  engine: process.Subject(EngineMessage),
) -> Response {
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use user_id <- result.try(list.key_find(formdata.values, "user_id") |> result.replace_error("Missing user_id"))
    let subject = process.new_subject()
    process.send(engine, RegisterAccount(user_id, subject))
    let response = process.receive_forever(subject)
    echo response
    handle_ack_nack_response(response, "register account")
  }

  html_response_from_result(result)
}

fn create_subreddit(req: Request, engine: process.Subject(EngineMessage)) -> Response {
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use sr_id <- result.try(list.key_find(formdata.values, "sr_id") |> result.replace_error("Missing sr_id"))
    let subject = process.new_subject()
    process.send(engine, CreateSubReddit(sr_id, subject))
    let response = process.receive_forever(subject)
    echo response
    handle_ack_nack_response(response, "create subreddit")
  }

  html_response_from_result(result)
}

fn join_subreddit(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use user_id <- result.try(list.key_find(formdata.values, "user_id") |> result.replace_error("Missing user_id"))
    use sr_id <- result.try(list.key_find(formdata.values, "sr_id") |> result.replace_error("Missing sr_id"))
    let subject = process.new_subject()
    process.send(engine, JoinSubreddit(user_id, sr_id, subject))
    let response = process.receive_forever(subject)
    echo response
    handle_ack_nack_response(response, "join subreddit")
  }

  html_response_from_result(result)
}

fn leave_subreddit(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use user_id <- result.try(list.key_find(formdata.values, "user_id") |> result.replace_error("Missing user_id"))
    use sr_id <- result.try(list.key_find(formdata.values, "sr_id") |> result.replace_error("Missing sr_id"))
    let subject = process.new_subject()
    process.send(engine, LeaveSubreddit(user_id, sr_id, subject))
    let response = process.receive_forever(subject)
    echo response
    handle_ack_nack_response(response, "leave subreddit")
  }

  html_response_from_result(result)
}

fn post_in_subreddit(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use user_id <- result.try(list.key_find(formdata.values, "user_id") |> result.replace_error("Missing user_id"))
    use sr_id <- result.try(list.key_find(formdata.values, "sr_id") |> result.replace_error("Missing sr_id"))
    use post_text <- result.try(list.key_find(formdata.values, "post_text") |> result.replace_error("Missing post_text"))
    let subject = process.new_subject()
    process.send(engine, PostInSubReddit(user_id, sr_id, post_text, subject))
    let response = process.receive_forever(subject)
    echo response
    handle_ack_nack_response(response, "post in subreddit")
  }

  html_response_from_result(result)
}

fn comment_in_subreddit(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use parent_id <- result.try(list.key_find(formdata.values, "parent_id") |> result.replace_error("Missing parent_id"))
    use user_id <- result.try(list.key_find(formdata.values, "user_id") |> result.replace_error("Missing user_id"))
    use comment_text <- result.try(list.key_find(formdata.values, "comment_text") |> result.replace_error("Missing comment_text"))
    let subject = process.new_subject()
    process.send(engine, CommentInSubReddit(parent_id, user_id, comment_text, subject))
    let response = process.receive_forever(subject)
    echo response
    handle_ack_nack_response(response, "comment in subreddit")
  }

  html_response_from_result(result)
}

fn get_comment(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use comment_id <- result.try(list.key_find(formdata.values, "comment_id") |> result.replace_error("Missing comment_id"))
    let subject = process.new_subject()
    process.send(engine, GetComment(comment_id, subject))
    let response = process.receive_forever(subject)
    echo response
    case response{
      ActOnComment(comment)->{
        let object = json.object([
          #("comment_id", json.string(comment.comment_id)),
          #("parent_id", json.string(comment.parent_id)),
          #("user_id", json.string(comment.user_id)),
          #("comment_content", json.string(comment.comment_content)),
          #("upvotes", json.int(comment.upvotes)),
          #("downvotes", json.int(comment.downvotes)),
        ])
        Ok(json.to_string(object))
      }
      Nack(message)->{
        wisp.log_error(message)
        Error(message)
      }
      _->{
        wisp.log_error("not a correct message (get comment)")
        Error("Invalid response type")
      }
    }
  }

  json_response_from_result(result)
}

fn upvote(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use parent_id <- result.try(list.key_find(formdata.values, "parent_id") |> result.replace_error("Missing parent_id"))
    let subject = process.new_subject()
    process.send(engine, Upvote(parent_id, subject))
    let response = process.receive_forever(subject)
    echo response
    handle_ack_nack_response(response, "upvote")
  }

  html_response_from_result(result)
}

fn downvote(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use parent_id <- result.try(list.key_find(formdata.values, "parent_id") |> result.replace_error("Missing parent_id"))
    let subject = process.new_subject()
    process.send(engine, Downvote(parent_id, subject))
    let response = process.receive_forever(subject)
    echo response
    handle_ack_nack_response(response, "downvote")
  }

  html_response_from_result(result)
}

fn request_karma(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use user_id <- result.try(list.key_find(formdata.values, "user_id") |> result.replace_error("Missing user_id"))
    let subject = process.new_subject()
    process.send(engine, RequestKarma(user_id, subject))
    let response = process.receive_forever(subject)
    echo response
    case response{
      ReceiveKarma(karma)->{
        let object = json.object([
          #("user_id", json.string(user_id)),
          #("karma", json.int(karma)),
        ])
        Ok(json.to_string(object))
      }
      Nack(message)->{
        wisp.log_error(message)
        Error(message)
      }
      _->{
        wisp.log_error("not a correct message (request karma)")
        Error("Invalid response type")
      }
    }
  }

  json_response_from_result(result)
}

fn request_feed(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use user_id <- result.try(list.key_find(formdata.values, "user_id") |> result.replace_error("Missing user_id"))
    let subject = process.new_subject()
    process.send(engine, RequestFeed(user_id, subject))
    let response = process.receive_forever(subject)
    echo response
    case response{
      ReceiveFeed(posts)->{
        let posts_json = list.map(posts, fn(post) {
          json.object([
            #("post_id", json.string(post.post_id)),
            #("user_id", json.string(post.user_id)),
            #("subreddit_id", json.string(post.subreddit_id)),
            #("post_content", json.string(post.post_content)),
            #("comments", json.array(post.comments, of: json.string)),
            #("upvotes", json.int(post.upvotes)),
            #("downvotes", json.int(post.downvotes)),
          ])
        })
        let object = json.object([
          #("user_id", json.string(user_id)),
          #("posts", json.array(posts_json, fn(x) { x })),
        ])
        Ok(json.to_string(object))
      }
      Nack(message)->{
        wisp.log_error(message)
        Error(message)
      }
      _->{
        wisp.log_error("not a correct message (request feed)")
        Error("Invalid response type")
      }
    }
  }

  json_response_from_result(result)
}

fn send_message(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use from_user_id <- result.try(list.key_find(formdata.values, "from_user_id") |> result.replace_error("Missing from_user_id"))
    use to_user_id <- result.try(list.key_find(formdata.values, "to_user_id") |> result.replace_error("Missing to_user_id"))
    use message <- result.try(list.key_find(formdata.values, "message") |> result.replace_error("Missing message"))
    let subject = process.new_subject()
    process.send(engine, SendMessage(from_user_id, to_user_id, message, subject))
    let response = process.receive_forever(subject)
    echo response
    handle_ack_nack_response(response, "send message")
  }

  html_response_from_result(result)
}

fn request_inbox(req: Request, engine: process.Subject(EngineMessage)) -> Response{
  use <- wisp.require_method(req, Post)
  use formdata <- wisp.require_form(req)

  let result = {
    use user_id <- result.try(list.key_find(formdata.values, "user_id") |> result.replace_error("Missing user_id"))
    let subject = process.new_subject()
    process.send(engine, RequestInbox(user_id, subject))
    let response = process.receive_forever(subject)
    echo response
    case response{
      DirectMessageInbox(messages)->{
        let messages_json = dict.to_list(messages)
          |> list.map(fn(tuple) {
            let #(msg_id, dm) = tuple
            json.object([
              #("message_id", json.string(msg_id)),
              #("from_user_id", json.string(dm.from_user_id)),
              #("to_user_id", json.string(dm.to_user_id)),
              #("content", json.string(dm.content)),
            ])
          })
        let object = json.object([
          #("user_id", json.string(user_id)),
          #("messages", json.array(messages_json, fn(x) { x })),
        ])
        Ok(json.to_string(object))
      }
      Nack(message)->{
        wisp.log_error(message)
        Error(message)
      }
      _->{
        wisp.log_error("not a correct message (request inbox)")
        Error("Invalid response type")
      }
    }
  }

  json_response_from_result(result)
}
