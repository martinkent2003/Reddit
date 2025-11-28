import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/string
import wisp

import pub_types.{
  type Comment, type DirectMessage, type EngineMessage, type Post,
  type Subreddit, type User, type UserInbox, ActOnComment, Comment,
  CommentInSubReddit, CreateSubReddit, DirectMessage, DirectMessageInbox,
  Downvote, GetComment, JoinSubreddit, LeaveSubreddit, Pong, Post,
  PostInSubReddit, ReceiveFeed, ReceiveKarma, RegisterAccount, RequestFeed,
  RequestInbox, RequestKarma, SendMessage, Subreddit, Upvote, User, UserInbox, Nack, Ack, ListAck
}

pub type EngineState {
  EngineState(
    //identifier and types stored/processed in engine(in part II actually passed to the Reddit API)
    users: Dict(String, User),
    posts: Dict(String, Post),
    comments: Dict(String, Comment),
    subreddits: Dict(String, Subreddit),
    users_inbox: Dict(String, UserInbox),
    direct_messages: Dict(String, DirectMessage),
    num_comments: Int,
  )
}

pub fn start_engine() {
  let _ =
    actor.new_with_initialiser(1000, fn(self_subject) {
      let state =
        EngineState(
          dict.new(),
          dict.new(),
          dict.new(),
          dict.new(),
          dict.new(),
          dict.new(),
          0,
        )
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
      let already_exists = dict.get(state.users, user_id)
      case already_exists{
        Ok(user) -> {
          actor.send(requester, Nack(user.user_id <> " already existed"))
          actor.continue(state)
        }
        _->{
          let new_user = User(user_id, 0, requester, [])
          let updated_users = dict.insert(state.users, user_id, new_user)
          let new_inbox = UserInbox(user_id, dict.new())
          let updated_inboxes = dict.insert(state.users_inbox, user_id, new_inbox)
          let new_state =
            EngineState(..state, users: updated_users, users_inbox: updated_inboxes)
          actor.send(requester, Ack(user_id <> " created"))
          actor.continue(new_state)
        }
      }
    }
    CreateSubReddit(sr_id, requester) -> {
      let already_exists = dict.get(state.subreddits, sr_id)
      case already_exists {
        Ok(subreddit) -> {
          //io.println("Already exists")
          //need to notify api process that we already
          actor.send(requester, Nack(subreddit.sr_id <> " already existed"))
          actor.continue(state)
        }
        _ -> {
          let new_sr = Subreddit(sr_id, [], [])
          let new_subreddits = dict.insert(state.subreddits, sr_id, new_sr)
          let new_state = EngineState(..state, subreddits: new_subreddits)
          actor.send(requester, Ack(sr_id <> " created"))
          actor.continue(new_state)
        }
      }
    }

    JoinSubreddit(user_id, sr_id, requester) -> {
      let sr_exists = dict.get(state.subreddits, sr_id)
      let user_exists = dict.get(state.users, user_id)
      case sr_exists, user_exists {
        Ok(subreddit), Ok(user) -> {
          //add the user to list of members of the subreddit
          let new_members = list.append(subreddit.members, [user_id])
          let updated_subreddit = Subreddit(..subreddit, members: new_members)
          let updated_subreddits =
            dict.insert(state.subreddits, sr_id, updated_subreddit)
          //add the subreddit to the user's list of subscribed subbreddits
          let updated_subscribed_sr = list.append(user.subscribed_sr, [sr_id])
          let new_user = User(..user, subscribed_sr: updated_subscribed_sr)
          let updated_users = dict.insert(state.users, user_id, new_user)
          let new_state =
            EngineState(
              ..state,
              users: updated_users,
              subreddits: updated_subreddits,
            )
          actor.send(requester, Ack(user_id<> " joined " <> sr_id <> " successfully"))
          actor.continue(new_state)
        }
        _, _ -> {
          actor.send(requester, Nack("user_id or sr_id invalid"))
          actor.continue(state)
        }
      }
    }

    LeaveSubreddit(user_id, sr_id, _requester) -> {
      let sr_exists = dict.get(state.subreddits, sr_id)
      let user_exists = dict.get(state.users, user_id)
      case sr_exists, user_exists {
        Ok(subreddit), Ok(user) -> {
          //filter out the user from the subreddit
          let new_members =
            list.filter(subreddit.members, fn(x) { x != user_id })
          let updated_subreddit = Subreddit(..subreddit, members: new_members)
          let updated_subreddits =
            dict.insert(state.subreddits, sr_id, updated_subreddit)
          //filter out the subreddit from the user
          let updated_subscribed_sr =
            list.filter(user.subscribed_sr, fn(x) { x != sr_id })
          let updated_user = User(..user, subscribed_sr: updated_subscribed_sr)
          let updated_users = dict.insert(state.users, user_id, updated_user)
          let new_state =
            EngineState(
              ..state,
              users: updated_users,
              subreddits: updated_subreddits,
            )
          actor.continue(new_state)
        }
        _, _ -> {
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
          0,
        )
      let new_state = update_comments(new_comment, state)
      actor.continue(new_state)
    }
    GetComment(comment_id, requester) -> {
      let comment_exists = dict.get(state.comments, comment_id)
      case comment_exists {
        Ok(comment) -> {
          process.send(requester, ActOnComment(comment))
        }
        _ -> {
          //io.println(comment_id <> "does not exist, failed GetCommment")
          Nil
        }
      }
      actor.continue(state)
    }
    Upvote(parent_id) -> {
      //io.println("upvoting" <> parent_id)
      let new_state = update_votes(True, parent_id, state)
      actor.continue(new_state)
    }
    Downvote(parent_id) -> {
      //io.println("downvoting" <> parent_id)
      let new_state = update_votes(False, parent_id, state)
      actor.continue(new_state)
    }
    RequestKarma(user_id, requester) -> {
      //io.println("printed from engine")
      let user_exists = dict.get(state.users, user_id)
      case user_exists {
        Ok(user) -> {
          //io.println("ok users karma is" <> int.to_string(user.userkarma))
          process.send(requester, ReceiveKarma(user.userkarma))
        }
        _ -> {
          //io.println("user dne")
          Nil
        }
      }
      actor.continue(state)
    }
    RequestFeed(user_id, requester) -> {
      // Get posts from each subreddit the user is subscribed to
      let user_exists = dict.get(state.users, user_id)
      case user_exists {
        Ok(user) -> {
          let subreddits =
            dict.values(dict.take(state.subreddits, user.subscribed_sr))
          let post_ids =
            list.map(subreddits, fn(sr) { sr.posts })
            |> list.flatten()
          let posts = dict.values(dict.take(state.posts, post_ids))
          let remove = int.min(list.length(posts) - 100, 0)
          let posts = list.drop(posts, remove)
          process.send(requester, ReceiveFeed(posts))
        }
        _ -> {
          //io.println("User " <> user_id <> " does not exist and is requesting a feed",)
          Nil
        }
      }
      actor.continue(state)
    }
    SendMessage(from_user_id, to_user_id, message) -> {
      //update direct messages 
      let direct_message = DirectMessage(from_user_id, to_user_id, message)
      let message_id = int.to_string(dict.size(state.direct_messages))
      let updated_direct_messages =
        dict.insert(state.direct_messages, message_id, direct_message)
      //update inbox of user who got the message
      let receiver_inbox = dict.get(state.users_inbox, to_user_id)
      case receiver_inbox {
        Ok(receiver) -> {
          let senders_sent_messages = dict.get(receiver.inboxes, from_user_id)
          case senders_sent_messages {
            Ok(sent) -> {
              //update inbox for that particular sender
              let updated_sent_from_user = list.append(sent, [message_id])
              let updated_sent =
                dict.insert(
                  receiver.inboxes,
                  from_user_id,
                  updated_sent_from_user,
                )
              let updated_receiver =
                UserInbox(..receiver, inboxes: updated_sent)
              let updated_users_inbox =
                dict.insert(state.users_inbox, to_user_id, updated_receiver)

              //update state
              let new_state =
                EngineState(
                  ..state,
                  direct_messages: updated_direct_messages,
                  users_inbox: updated_users_inbox,
                )
              actor.continue(new_state)
            }
            _ -> {
              //create inbox as there previously didn't exist one, insert a list with the message id as the only value
              let updated_sent =
                dict.insert(receiver.inboxes, from_user_id, [message_id])
              let updated_receiver =
                UserInbox(..receiver, inboxes: updated_sent)
              let updated_users_inbox =
                dict.insert(state.users_inbox, to_user_id, updated_receiver)

              //update state
              let new_state =
                EngineState(
                  ..state,
                  direct_messages: updated_direct_messages,
                  users_inbox: updated_users_inbox,
                )
              actor.continue(new_state)
            }
          }
        }
        _ -> {
          //io.println("User Id not found in inboxes")
          actor.continue(state)
        }
      }
    }
    RequestInbox(user_id, requester) -> {
      let check_user = dict.get(state.users_inbox, user_id)
      case check_user {
        Ok(user_inbox) -> {
          //send list of direct_message to requester
          let user_inbox_values = list.flatten(dict.values(user_inbox.inboxes))
          let filtered_state =
            dict.take(state.direct_messages, user_inbox_values)
          process.send(requester, DirectMessageInbox(filtered_state))
        }
        _ -> {
          //io.println("User Id not found in inboxes")
          Nil
        }
      }
      actor.continue(state)
    }
    pub_types.PrintSubredditSizes -> {
      //print_subreddit_size(state, 1, dict.size(state.subreddits))
      actor.continue(state)
    }
    Pong(iteration, return_to) -> {
      let posts_comments_dms = #(
        dict.size(state.posts),
        dict.size(state.comments),
        dict.size(state.direct_messages),
      )
      process.send(
        return_to,
        pub_types.ReceivePong(iteration, posts_comments_dms),
      )
      actor.continue(state)
    }
  }
}

// fn print_subreddit_size(state: EngineState, i: Int, n: Int) {
//   case i > n {
//     True -> Nil
//     False -> {
//       let assert Ok(sr) =
//         dict.get(state.subreddits, "subreddit" <> int.to_string(i))
//       io.println(
//         "subreddit"
//         <> int.to_string(i)
//         <> ": "
//         <> int.to_string(list.length(sr.members)),
//       )
//       print_subreddit_size(state, i + 1, n)
//     }
//   }
// }

fn update_comments(new_comment: Comment, state: EngineState) -> EngineState {
  let parent_is_post = string.starts_with(new_comment.parent_id, "post")
  case parent_is_post {
    True -> {
      let post_exists = dict.get(state.posts, new_comment.parent_id)
      case post_exists {
        Ok(post) -> {
          //Update State Comments
          let updated_comments =
            dict.insert(state.comments, new_comment.comment_id, new_comment)

          //Update State Posts
          let new_post_subcomments =
            list.append(post.comments, [new_comment.comment_id])
          let new_post = Post(..post, comments: new_post_subcomments)
          let updated_posts =
            dict.insert(state.posts, new_comment.parent_id, new_post)

          let new_state =
            EngineState(
              ..state,
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

          let updated_comments =
            dict.insert(state.comments, new_comment.comment_id, new_comment)
          //Insert the updated parent
          let new_comments =
            list.append(parent_comment.comments, [new_comment.comment_id])
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
          case user_exists {
            Ok(user) -> {
              case upvote {
                True -> {
                  let updated_post = Post(..post, upvotes: post.upvotes + 1)
                  let updated_posts =
                    dict.insert(state.posts, parent_id, updated_post)
                  let updated_user = User(..user, userkarma: user.userkarma + 1)
                  let updated_users =
                    dict.insert(state.users, user.user_id, updated_user)
                  let new_state =
                    EngineState(
                      ..state,
                      posts: updated_posts,
                      users: updated_users,
                    )
                  new_state
                }
                False -> {
                  let updated_post = Post(..post, downvotes: post.downvotes + 1)
                  let updated_posts =
                    dict.insert(state.posts, parent_id, updated_post)
                  let updated_user = User(..user, userkarma: user.userkarma - 1)
                  let updated_users =
                    dict.insert(state.users, user.user_id, updated_user)
                  let new_state =
                    EngineState(
                      ..state,
                      posts: updated_posts,
                      users: updated_users,
                    )
                  new_state
                }
              }
            }
            _ -> {
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
          case user_exists {
            Ok(user) -> {
              case upvote {
                True -> {
                  let updated_comment =
                    Comment(
                      ..parent_comment,
                      upvotes: parent_comment.upvotes + 1,
                    )
                  let updated_comments =
                    dict.insert(state.comments, parent_id, updated_comment)
                  let updated_user = User(..user, userkarma: user.userkarma + 1)
                  let updated_users =
                    dict.insert(state.users, user.user_id, updated_user)
                  let new_state =
                    EngineState(
                      ..state,
                      comments: updated_comments,
                      users: updated_users,
                    )
                  new_state
                }
                False -> {
                  let updated_comment =
                    Comment(
                      ..parent_comment,
                      downvotes: parent_comment.downvotes + 1,
                    )
                  let updated_comments =
                    dict.insert(state.comments, parent_id, updated_comment)

                  let updated_user = User(..user, userkarma: user.userkarma - 1)
                  let updated_users =
                    dict.insert(state.users, user.user_id, updated_user)
                  let new_state =
                    EngineState(
                      ..state,
                      comments: updated_comments,
                      users: updated_users,
                    )
                  new_state
                }
              }
            }
            _ -> {
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
