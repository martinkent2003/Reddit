import gleam/dict
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/string
import pub_types.{
  type ClientMessage, type EngineMessage, type SimulatorMessage,
  CommentInSubReddit, Connect, CreateSubReddit, PostInSubReddit, ReceiveFeed,
  RegisterAccount, RequestFeed, Upvote, Downvote, RequestKarma,
  type Comment, type Post, ClientJoinSubreddit, JoinSubreddit, DirectMessageInbox,
  SendMessage, GetInbox
}

pub type ClientState {
  ClientState(
    simulator_subject: process.Subject(SimulatorMessage),
    engine_subject: process.Subject(EngineMessage),
    self_subject: process.Subject(ClientMessage),
    user_id: String,
  )
}

pub fn start_client(
  simulator_subject: process.Subject(SimulatorMessage),
  engine_subject: process.Subject(EngineMessage),
  user_id: String,
) {
  let _ =
    actor.new_with_initialiser(1000, fn(self_subject) {
      process.send(engine_subject, RegisterAccount(user_id, self_subject))
      let state =
        ClientState(simulator_subject, engine_subject, self_subject, user_id)
      let _result =
        Ok(actor.initialised(state) |> actor.returning(self_subject))
    })
    |> actor.on_message(handle_message_client)
    |> actor.start
}

fn handle_message_client(
  state: ClientState,
  message: ClientMessage,
) -> actor.Next(ClientState, ClientMessage) {
  case message {
    Connect -> {
      test_functions(state)
      actor.continue(state)
    }
    ReceiveFeed(posts) -> {
      io.println("Client " <> state.user_id <> " received feed:")
      io.println(string.inspect(posts))
      //print_post(post)
      actor.continue(state)
    }
    DirectMessageInbox(user_inbox) -> {
      io.println("Client " <> state.user_id <> " received inbox:")
      io.println(string.inspect(dict.to_list(user_inbox))<>"\n")
      actor.continue(state)
    }
    ClientJoinSubreddit(sr_ids) -> {
      list.each(sr_ids, fn(sr_id) {
        process.send(
          state.engine_subject,
          JoinSubreddit(state.user_id, sr_id, state.self_subject),
        )
      })
      actor.continue(state)
    }
    _ -> {
      io.println("Client " <> state.user_id <> " received unknown message")
      actor.continue(state)
    }
  }
}

fn test_functions(state: ClientState) {
  process.send(
    state.engine_subject,
    CreateSubReddit("subreddit 1", state.self_subject),
  )
  process.sleep(200)
  process.send(
    state.engine_subject,
    PostInSubReddit(state.user_id, "subreddit 1", "First post ever"),
  )
  process.sleep(20)
  process.send(
    state.engine_subject,
    CommentInSubReddit("post0", state.user_id, "First comment ever"),
  )
  process.send(
    state.engine_subject,
    CommentInSubReddit("post0", state.user_id, "Second comment ever"),
  )
  process.sleep(20)
  process.send(
    state.engine_subject,
    CommentInSubReddit("comment0", state.user_id, "Replying to the first comment ever"),
  )
  process.sleep(20)
  process.send(
    state.engine_subject,
    Upvote("comment0")
  )
  process.sleep(20)
  process.send(
    state.engine_subject,
    Upvote("post0")
  )
  process.send(
    state.engine_subject,
    Downvote("comment1")
  )
  process.sleep(20)
  process.send(
    state.engine_subject,
    RequestKarma(state.user_id, state.self_subject)
  )
  process.sleep(20)
  case state.user_id {
    "1" -> {
      process.send(
        state.engine_subject,
        SendMessage(state.user_id, "2", "Hello from user 1")
      )
    }
    "2" -> {
      process.send(
        state.engine_subject,
        SendMessage(state.user_id, "1", "Hello from user 2")
      )
    }
    _ -> {
      Nil
    }
  }
  process.sleep(20)
  process.send(
     state.engine_subject,
     GetInbox(state.user_id, state.self_subject)
  )
  process.sleep(20)
  process.send(
    state.engine_subject,
    RequestFeed(state.user_id, state.self_subject),
  )
}

// pub fn print_post(post: Post) {
//   io.println("-> " <> post.post_id <> ": " <> post.post_content)
// }

// fn print_comments(comments: List(Comment), depth: Int) {
//   list.each(comments, fn(comment) {
//     let indent = string.repeat("    ", depth)
//     // 4 spaces per depth
//     io.println(
//       indent <> "-> " <> comment.comment_id <> ": " <> comment.comment_content,
//     )
//     print_comments(comment.comments, depth + 1)
//   })
// }
