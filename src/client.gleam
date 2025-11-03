import gleam/float
import tick
import gleam/int
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/string
import pub_types.{
  type ClientMessage, type Comment, type EngineMessage, type Post, type DirectMessage, DirectMessage,
  type SimulatorMessage, ClientJoinSubreddit, CommentInSubReddit, Connect,
  CreateSubReddit, DirectMessageInbox, Downvote, RequestInbox, JoinSubreddit,
  PostInSubReddit, ReceiveFeed, RegisterAccount, RequestFeed, RequestKarma,
  SendMessage, Upvote, ActivitySim, ActOnComment, GetComment
}

pub type ClientState {
  ClientState(
    simulator_subject: process.Subject(SimulatorMessage),
    engine_subject: process.Subject(EngineMessage),
    self_subject: process.Subject(ClientMessage),
    user_id: String,
    activity_timeout: Float,
    sr_ids: List(String),
    feed: List(Post),
    inbox : Dict(String, DirectMessage)
  )
}

pub fn start_client(
  simulator_subject: process.Subject(SimulatorMessage),
  engine_subject: process.Subject(EngineMessage),
  user_id: String,
  activity_timeout: Float,
) {
  let _ =
    actor.new_with_initialiser(1000, fn(self_subject) {
      process.send(engine_subject, RegisterAccount(user_id, self_subject))
      let state =
        ClientState(
          simulator_subject,
          engine_subject,
          self_subject,
          user_id,
          activity_timeout,
          [],
          [],
          dict.new()
        )
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
      //test_functions(state)
      tick.start_ticker(state.self_subject, float.round(state.activity_timeout *. 1000.0))
      actor.continue(state)
    }
    ReceiveFeed(posts) -> {
      //io.println("Client " <> state.user_id <> " received feed:")
      //io.println(string.inspect(posts))
      let updated_state = ClientState(..state, feed: posts)
      actor.continue(updated_state)
    }
    DirectMessageInbox(user_inbox) -> {
      //io.println("Client " <> state.user_id <> " received inbox:")
      //io.println(string.inspect(dict.to_list(user_inbox))<>"\n")
      let updated_state = ClientState(..state, inbox: user_inbox)
      actor.continue(updated_state)
    }
    ClientJoinSubreddit(sr_ids) -> {

      list.each(sr_ids, fn(sr_id) {
        process.send(
          state.engine_subject,
          JoinSubreddit(state.user_id, sr_id, state.self_subject),
        )
      })
      let updated_state = ClientState(..state, sr_ids: sr_ids)
      actor.continue(updated_state)
    }
    ActivitySim()->{
      //activity 0:Message 1:Post 2:ActonPost 3:ActOnComment(req comment) 4:GetFeed 5:GetInbox
      case int.random(6) {
        0 ->{
          //Reply to a DM
          let inbox_size = dict.size(state.inbox)
          case inbox_size{
            0->{
              //Get a user_id from random post and send them a message
              let first_post = list.first(state.feed)
              case first_post {
                Ok(post)->{
                  let message = "This is a message being sent from "<> state.user_id <> " to the user: "<> post.user_id <> " from post: "<> post.post_id
                  process.send(state.engine_subject, SendMessage(state.user_id, post.user_id, message ))
                }
                _->{
                  io.println("Client "<>state.user_id<>" no feed, no inbox, cannot send message")
                }
              }
            }
            _->{
              //Get a random message from inbox and reply to from_user
              let inbox = dict.keys(state.inbox)
              let first_inbox = list.first(inbox)
              case first_inbox {
                Ok(target_id)->{
                  let message = "This is a message being sent from "<> state.user_id <> " to the user: "<> target_id
                  process.send(state.engine_subject, SendMessage(state.user_id, target_id, message))
                }
                _->{
                  io.println("No messages in inbox SOMETHING IS WEIRD")
                }
              }
              Nil
            }
          }
        }
        1 ->{
          //Make Post
          let ind = int.random(list.length(state.sr_ids))
          let sr_id = list.first(list.drop(state.sr_ids, ind))
          case sr_id {
            Ok(sr_id) -> process.send(state.engine_subject, PostInSubReddit(state.user_id, sr_id, "Post by " <> state.user_id <> " in " <> sr_id))
            _ -> io.println("SOMETHING IS WEIRD choosing a subreddit to post to")
          }
          Nil
        }
        2 ->{
          //Comment, Upvote, Downvote on post
          let ind = int.random(list.length(state.feed))
          let post = list.first(list.drop(state.feed, ind))
          case post {
            Ok(post) -> {
                act_on_parent_id(post.post_id, state.user_id, state.engine_subject)
            }
            _->{
              io.println("Client "<>state.user_id<>" has no posts to interact with in their feed :(")
            }
          }
        }
        3 ->{
          //Comment, Upvote, Downvote on comment (handled in received comment)
          let ind = int.random(list.length(state.feed))
          let post_exists = list.first(list.drop(state.feed, ind))
          case post_exists {
            Ok(post) -> {
              let ind2 = int.random(list.length(post.comments))
              let comment_exists = list.first(list.drop(post.comments, ind2))
              case comment_exists {
                Ok(comment) ->{
                  process.send(state.engine_subject, GetComment(comment, state.self_subject))
                }
                _->{
                  io.println("Comment not existing under post: Activity commenting")
                }
              }
            }
            _->{
              io.println("Client "<>state.user_id<>" has no posts to interact with in their feed :(")
            }
          }
        }
        4->{
          process.send(state.engine_subject, RequestFeed(state.user_id, state.self_subject))
        }
        5->{
          process.send(state.engine_subject, RequestInbox(state.user_id, state.self_subject))
        }
        _->{

        }
      }
      actor.continue(state)
    }
    ActOnComment(comment)->{
      let recurse = int.random(3)
      case recurse{
        0->{
          //we either go into the comments and request another nested comment
          let ind2 = int.random(list.length(comment.comments))
          let comment_exists = list.first(list.drop(comment.comments, ind2))
          case comment_exists {
            Ok(comment) ->{
              process.send(state.engine_subject, GetComment(comment, state.self_subject))
            }
            _->{
              io.println("Comment not existing under post: Activity commenting")
            }
          }
        }
        _->{
          //or act on one of the existing comments (more likely to happen)
          act_on_parent_id(comment.comment_id, state.user_id, state.engine_subject)
        }
      }
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
    CommentInSubReddit(
      "comment0",
      state.user_id,
      "Replying to the first comment ever",
    ),
  )
  process.sleep(20)
  process.send(state.engine_subject, Upvote("comment0"))
  process.sleep(20)
  process.send(state.engine_subject, Upvote("post0"))
  process.send(state.engine_subject, Downvote("comment1"))
  process.sleep(20)
  process.send(
    state.engine_subject,
    RequestKarma(state.user_id, state.self_subject),
  )
  process.sleep(20)
  case state.user_id {
    "1" -> {
      process.send(
        state.engine_subject,
        SendMessage(state.user_id, "2", "Hello from user 1"),
      )
    }
    "2" -> {
      process.send(
        state.engine_subject,
        SendMessage(state.user_id, "1", "Hello from user 2"),
      )
    }
    _ -> {
      Nil
    }
  }
  process.sleep(20)
  process.send(
    state.engine_subject,
    RequestInbox(state.user_id, state.self_subject),
  )
  process.sleep(20)
  process.send(
    state.engine_subject,
    RequestFeed(state.user_id, state.self_subject),
  )
}



pub fn act_on_parent_id(parent_id: String, user_id: String, engine: Subject(EngineMessage)){
    case int.random(3) {
      0 -> process.send(engine, CommentInSubReddit(parent_id, user_id, "Comment by " <> user_id <> " on " <> parent_id))
      1 -> process.send(engine, Upvote(parent_id))
      2 -> process.send(engine, Downvote(parent_id))
      _ -> Nil
    }
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
