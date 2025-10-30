import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/string

import pub_types.{
  type Comment, type EngineMessage, type Post, type Subreddit, type User,
  Comment, CommentInSubReddit, CreateSubReddit, Downvote, GetInbox,
  JoinSubreddit, LeaveSubreddit, Post, PostInSubReddit, RegisterAccount,
  RequestFeed, RequestKarma, SendMessage, Subreddit, Upvote, User,
}

pub type EngineState {
  EngineState(
    //identifier and types stored/processed in engine(in part II actually passed to the Reddit API)
    users: Dict(String, User),
    posts: Dict(String, Post),
    comments: Dict(String, Comment),
    subreddits: Dict(String, Subreddit),
    num_comments: Int,
  )
}

pub fn start_engine() {
  let _ =
    actor.new_with_initialiser(1000, fn(self_subject) {
      let state = EngineState(dict.new(), dict.new(), dict.new(), dict.new(), 0)
      let _result =
        Ok(actor.initialised(state) |> actor.returning(self_subject))
    })
    |> actor.on_message(handle_message_engine)
    |> actor.start
}

fn handle_message_engine(
  state: EngineState,
  message: EngineMessage,
) -> actor.Next(EngineState, EngineMessage) {
  case message {
    RegisterAccount(user_id, requester) -> {
      let new_user = User(user_id, 0, requester)
      let updated = dict.insert(state.users, user_id, new_user)
      let new_state = EngineState(..state, users: updated)
      io.println("User: " <> user_id <> " initialized")
      actor.continue(new_state)
    }
    CreateSubReddit(sr_id, _requester) -> {
      let already_exists = dict.get(state.subreddits, sr_id)
      case already_exists {
        Ok(_subreddit) -> {
          io.println("Already exists")
          actor.continue(state)
        }
        _ -> {
          let new_sr = Subreddit(sr_id, [], [])
          let new_subreddits = dict.insert(state.subreddits, sr_id, new_sr)
          let new_state = EngineState(..state, subreddits: new_subreddits)
          actor.continue(new_state)
        }
      }
    }
    JoinSubreddit(user_id, sr_id, _requester) -> {
      let exists = dict.get(state.subreddits, sr_id)
      case exists {
        Ok(subreddit) -> {
          //add the user to list of members of the subreddit
          let new_members = list.append(subreddit.members, [user_id])
          let updated_subreddit = Subreddit(..subreddit, members: new_members)
          let updated_subreddits =
            dict.insert(state.subreddits, sr_id, updated_subreddit)
          let new_state = EngineState(..state, subreddits: updated_subreddits)
          actor.continue(new_state)
        }
        _ -> {
          actor.continue(state)
        }
      }
    }
    LeaveSubreddit(user_id, sr_id, _requester) -> {
      let exists = dict.get(state.subreddits, sr_id)
      case exists {
        Ok(subreddit) -> {
          let new_members =
            list.filter(subreddit.members, fn(x) { x != user_id })
          let updated_subreddit = Subreddit(..subreddit, members: new_members)
          let updated_subreddits =
            dict.insert(state.subreddits, sr_id, updated_subreddit)
          let new_state = EngineState(..state, subreddits: updated_subreddits)
          actor.continue(new_state)
        }
        _ -> {
          actor.continue(state)
        }
      }
    }
    PostInSubReddit(user_id, sr_id, post_text) -> {
      let exists = dict.get(state.subreddits, sr_id)
      case exists {
        Ok(subreddit) -> {
          let post_id = "post" <> int.to_string(dict.size(state.posts))
          let new_post = Post(post_id, user_id, sr_id, post_text, [], 0, 0)
          let updated_posts = dict.insert(state.posts, post_id, new_post)
          let updated_subreddit =
            Subreddit(
              ..subreddit,
              posts: list.append(subreddit.posts, [post_id]),
            )
          let updated_subreddits =
            dict.insert(state.subreddits, subreddit.sr_id, updated_subreddit)
          let new_state =
            EngineState(
              ..state,
              posts: updated_posts,
              subreddits: updated_subreddits,
            )
          actor.continue(new_state)
        }
        _ -> {
          actor.continue(state)
        }
      }
    }
    CommentInSubReddit(parent_id, comment_text) -> {
      let new_comment =
        Comment(
          "comment" <> int.to_string(state.num_comments),
          parent_id,
          comment_text,
          [],
        )
      let new_state = update_comments_recursively(new_comment, state)
      actor.continue(
        EngineState(
          ..new_state,
          comments: dict.insert(
            new_state.comments,
            new_comment.comment_id,
            new_comment,
          ),
          num_comments: state.num_comments + 1,
        ),
      )
    }
    Upvote(_parent_id) -> {
      actor.continue(state)
    }
    Downvote(_parent_id) -> {
      actor.continue(state)
    }
    RequestKarma(_user_id, _requester) -> {
      actor.continue(state)
    }
    RequestFeed(_user_id, requester) -> {
      // Temporarily gives only one post
      let assert Ok(post) = dict.get(state.posts, "post0")
      process.send(requester, pub_types.ReceiveFeed(post))
      actor.continue(state)
    }
    SendMessage(_from_user_id, _to_user_id, _message) -> {
      actor.continue(state)
    }
    GetInbox(_user_id, _requester) -> {
      actor.continue(state)
    }
  }
}

fn update_comments_recursively(
  new_comment: Comment,
  state: EngineState,
) -> EngineState {
  let parent_is_post = string.starts_with(new_comment.parent_id, "post")
  case parent_is_post {
    True -> {
      let post_exists = dict.get(state.posts, new_comment.parent_id)
      case post_exists {
        Ok(post) -> {
          let new_comments = list.append(post.comments, [new_comment])
          let new_post = Post(..post, comments: new_comments)
          let updated_posts =
            dict.insert(state.posts, new_comment.parent_id, new_post)

          // Update subreddit
          let subreddit_exists = dict.get(state.subreddits, post.subreddit_id)
          let updated_subreddits = case subreddit_exists {
            Ok(subreddit) -> {
              dict.insert(state.subreddits, post.subreddit_id, subreddit)
            }
            _ -> {
              state.subreddits
            }
          }

          let new_state =
            EngineState(
              ..state,
              posts: updated_posts,
              subreddits: updated_subreddits,
            )
          new_state
        }
        _ -> {
          io.println(new_comment.parent_id <> " does not exist in posts")
          state
        }
      }
    }
    False -> {
      let comment_exists = dict.get(state.comments, new_comment.parent_id)
      case comment_exists {
        Ok(parent_comment) -> {
          let new_comments = list.append(parent_comment.comments, [new_comment])
          let new_parent_comment =
            Comment(..parent_comment, comments: new_comments)
          let updated_comments =
            dict.insert(
              state.comments,
              new_comment.parent_id,
              new_parent_comment,
            )
          let new_state = EngineState(..state, comments: updated_comments)
          update_comments_recursively(new_parent_comment, new_state)
        }
        _ -> {
          state
        }
      }
    }
  }
}
