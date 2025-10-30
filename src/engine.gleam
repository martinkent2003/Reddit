import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/string

import pub_types.{
  type Comment, type EngineMessage, type Post, type Subreddit, type User, User,
  Comment, CommentInSubReddit, CreateSubReddit, Downvote, GetInbox,
  JoinSubreddit, LeaveSubreddit, Post, PostInSubReddit, RegisterAccount,
  RequestFeed, RequestKarma, SendMessage, Subreddit, Upvote, 
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
    CommentInSubReddit(parent_id, user_id, comment_text) -> {
      let new_comment =
        Comment(
          "comment" <> int.to_string(dict.size(state.comments)),
          parent_id,
          user_id,
          comment_text,
          [],
          0,
          0
        )
      let new_state = update_comments(new_comment, state)
      actor.continue(
          new_state
        )
    }
    Upvote(parent_id) -> {
      io.println("upvoting"<>parent_id)
      let new_state = update_votes(True, parent_id, state)
      actor.continue(new_state)
    }
    Downvote(parent_id) -> {
      io.println("downvoting" <> parent_id)
      let new_state = update_votes(False, parent_id, state)
      actor.continue(new_state)
    }
    RequestKarma(user_id, _requester) -> {
      io.println("printed from engine")
      let user_exists = dict.get(state.users, user_id)
      case user_exists{
        Ok(user)->{
          io.println("ok users karma is" <> int.to_string(user.userkarma))
        }
        _->{
          io.println("user dne")
        }
      }
      actor.continue(state)
    }
    RequestFeed(_user_id, requester) -> {
      // Temporarily gives only one post
      let assert Ok(post) = dict.get(state.posts, "post0")
      process.send(requester, pub_types.ReceiveFeed(post))
      io.println(string.inspect(dict.to_list(state.comments)))
      actor.continue(state)
    }
    SendMessage(_from_user_id, _to_user_id, _message) -> {
      actor.continue(state)
    }
    GetInbox(_user_id, _requester) -> {
      actor.continue(state)
    }
    pub_types.PrintSubredditSizes -> {
      print_subreddit_size(state, 1, dict.size(state.subreddits))
      actor.continue(state)
    }
  }
}

fn print_subreddit_size(state: EngineState, i: Int, n: Int) {
  case i > n {
    True -> Nil
    False -> {
      let assert Ok(sr) =
        dict.get(state.subreddits, "subreddit" <> int.to_string(i))
      io.println(
        "subreddit"
        <> int.to_string(i)
        <> ": "
        <> int.to_string(list.length(sr.members)),
      )
      print_subreddit_size(state, i + 1, n)
    }
  }
}

fn update_comments(
  new_comment: Comment,
  state: EngineState,
) -> EngineState {
  let parent_is_post = string.starts_with(new_comment.parent_id, "post")
  case parent_is_post {
    True -> {
      let post_exists = dict.get(state.posts, new_comment.parent_id)
      case post_exists {
        Ok(post) -> {
          //Update State Comments
          let updated_comments = dict.insert(state.comments, new_comment.comment_id, new_comment)

          //Update State Posts
          let new_post_subcomments = list.append(post.comments, [new_comment.comment_id])
          let new_post = Post(..post, comments: new_post_subcomments)
          let updated_posts = dict.insert(state.posts, new_comment.parent_id, new_post)

          let new_state =EngineState(..state,
              posts: updated_posts,
              comments: updated_comments,
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
          //Insert the new comment into state comments
          
          let updated_comments = dict.insert(state.comments, new_comment.comment_id, new_comment)
          //Insert the updated parent
          let new_comments = list.append(parent_comment.comments, [new_comment.comment_id])
          let new_parent_comment =
            Comment(..parent_comment, comments: new_comments)
          let updated_comments =
            dict.insert(
              updated_comments,
              new_comment.parent_id,
              new_parent_comment,
            )
          let new_state = EngineState(..state, comments: updated_comments)
          new_state
        }
        _ -> {
          state
        }
      }
    }
  }
}

fn update_votes(
  upvote: Bool,
  parent_id: String,
  state: EngineState,
) -> EngineState {
  let parent_is_post = string.starts_with(parent_id, "post")
  case parent_is_post {
    True -> {
      let post_exists = dict.get(state.posts, parent_id)
      case post_exists {
        Ok(post) -> {
          let user_exists = dict.get(state.users, post.user_id)
          case user_exists{
            Ok(user) -> {
              case upvote{
                True->{
                  let updated_post = Post(..post, upvotes: post.upvotes + 1)
                  let updated_posts = dict.insert(state.posts, parent_id, updated_post)
                  let updated_user = User(..user, userkarma: user.userkarma + 1)
                  let updated_users = dict.insert(state.users, user.user_id, updated_user)
                  let new_state =EngineState(..state,
                      posts: updated_posts,
                      users: updated_users
                    )
                  new_state
                }
                False->{
                  let updated_post = Post(..post, downvotes: post.downvotes + 1)
                  let updated_posts = dict.insert(state.posts, parent_id, updated_post)
                  let updated_user = User(..user, userkarma: user.userkarma - 1)
                  let updated_users = dict.insert(state.users, user.user_id, updated_user)
                  let new_state =EngineState(..state,
                      posts: updated_posts,
                      users: updated_users
                    )
                  new_state
                }
              }
            }
            _ ->{
              io.println("User corresponding to the post was not found")
              state
            }
          }
        }
        _ -> {
          io.println(parent_id <> " does not exist in posts")
          state
        }
      }
    }
    False -> {
      let comment_exists = dict.get(state.comments, parent_id)
      case comment_exists {
        Ok(parent_comment) -> {
          let user_exists = dict.get(state.users, parent_comment.user_id)
          case user_exists{
            Ok(user) -> {
            case upvote {
              True ->{
                let updated_comment = Comment(..parent_comment, upvotes: parent_comment.upvotes + 1)
                let updated_comments = dict.insert(state.comments, parent_id, updated_comment)
                let updated_user = User(..user, userkarma: user.userkarma + 1)
                let updated_users = dict.insert(state.users, user.user_id, updated_user)
                let new_state =EngineState(..state,
                    comments: updated_comments,
                    users: updated_users
                  )
                new_state
              }
              False ->{
                let updated_comment = Comment(..parent_comment, downvotes: parent_comment.downvotes + 1)
                let updated_comments = dict.insert(state.comments, parent_id, updated_comment)

                let updated_user = User(..user, userkarma: user.userkarma - 1)
                let updated_users = dict.insert(state.users, user.user_id, updated_user)
                let new_state =EngineState(..state,
                    comments: updated_comments,
                    users: updated_users
                  )
                new_state
              }
            }
          }
          _ ->{
            io.println("User corresponding to the comment was never found")
            state
          }   
        }  
      }   
      _ -> {
        io.println("the parent id belongs to no comment")
        state
        }
      }
    }
  }
}


