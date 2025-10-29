import gleam/string
import gleam/int
import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/otp/actor

import pub_types.{type User, User, type Post, Post, type Comment, Comment, type Subreddit, Subreddit, type EngineMessage,
                RegisterAccount, CreateSubReddit, JoinSubreddit, LeaveSubreddit, PostInSubReddit, CommentInSubReddit, Upvote, Downvote,
                RequestKarma, RequestFeed, SendMessage, GetInbox
                 }

pub type EngineState{
    EngineState(
        //identifier and types stored/processed in engine(in part II actually passed to the Reddit API)
        users: Dict(String, User),
        posts: Dict(String, Post),
        comments: Dict(String, Comment),
        subreddits: Dict(String, Subreddit),
        num_comments: Int
    )
}

pub fn start_engine() {
    let _ =actor.new_with_initialiser(1000, fn(self_subject) {
        let state = EngineState(
            dict.new(),
            dict.new(),
            dict.new(),
            dict.new(),
            0
        )
        let _result = Ok(actor.initialised(state) |> actor.returning(self_subject))
        })
    |> actor.on_message(handle_message_engine)
    |> actor.start
}

fn handle_message_engine(
    state: EngineState,
    message: EngineMessage,
) -> actor.Next(EngineState, EngineMessage) {
    case message {
        RegisterAccount(user_id, requester)->{
            let new_user = User( user_id, 0, requester)
            let updated = dict.insert(state.users, user_id, new_user)
            let new_state = EngineState(..state, users: updated)
            io.println("User: " <> user_id <> " initialized")
            actor.continue(new_state)
        }
        CreateSubReddit(sr_id, _requester)->{
            let already_exists = dict.get(state.subreddits, sr_id)
            case already_exists{
                Ok(subreddit) -> {
                    io.println("Already exists")
                    actor.continue(state)
                }
                _ -> {
                    let new_sr = Subreddit(
                        sr_id,
                        [],
                        [],
                    )
                    let new_subreddits = dict.insert(state.subreddits, sr_id, new_sr)
                    let new_state = EngineState(..state, subreddits: new_subreddits)
                    actor.continue(new_state)
                }
            }
            
            actor.continue(state)
        }
        JoinSubreddit(user_id, sr_id, _requester)->{
            let exists = dict.get(state.subreddits, sr_id)
            case exists{
                Ok(subreddit) -> {
                    //add the user to list of members of the subreddit
                    let new_members = list.append(subreddit.members, [user_id])
                    let updated_subreddit = Subreddit(..subreddit, members:new_members)
                    let updated_subreddits = dict.insert(state.subreddits, sr_id, updated_subreddit)
                    let new_state = EngineState(..state, subreddits: updated_subreddits)
                    actor.continue(new_state)
                }
                _->{
                    actor.continue(state)
                }
            }
        }
        LeaveSubreddit(user_id, sr_id, _requester)->{
            let exists = dict.get(state.subreddits, sr_id)
            case exists{
                Ok(subreddit) -> {
                    let new_members = list.filter(subreddit.members, fn(x) {x != user_id})
                    let new_members = list.
                    let updated_subreddit = Subreddit(..subreddit, members:new_members)
                    let updated_subreddits = dict.insert(state.subreddits, sr_id, updated_subreddit)
                    let new_state = EngineState(..state, subreddits: updated_subreddits)
                    actor.continue(new_state)
                }
                _->{
                    actor.continue(state)
                }
            }
        }
        PostInSubReddit(user_id, sr_id, post_text)->{
            let exists = dict.get(state.subreddits, sr_id)
            case exists{
                Ok(subreddit)-> {
                    let post_id = "post"<>int.to_string(dict.size(state.posts))
                    let new_post = Post(
                        post_id,
                        user_id,
                        sr_id,
                        post_text,
                        [],
                        0,
                        0
                    )
                    let updated_posts = dict.insert(state.posts, post_id, new_post)
                    let new_state = EngineState(..state, posts: updated_posts)
                    actor.continue(new_state)
                }
                _->{
                    actor.continue(state)
                }
            }
        }
        CommentInSubReddit(sr_id, parent_id, comment_text)->{
            let exists = dict.get(state.subreddits, sr_id)
            let new_comment = Comment(
                "comment"<>int.to_string(state.num_comments),
                parent_id,
                comment_text,
                []

            )
            case exists{
                Ok(subreddit)-> {
                    let is_post = string.starts_with(parent_id, "post")
                    case is_post{
                        True->{
                            let post_exists = dict.get(state.posts, parent_id)
                            case post_exists{
                                Ok(post)->{
                                    let new_comments = list.append(post.comments, [new_comment])
                                    let new_post = Post(..post, comments: new_comments)
                                    let updated_posts = dict.insert(state.posts, parent_id, new_post)
                                    let new_state = EngineState(..state, posts: updated_posts)
                                    actor.continue(new_state)
                                }
                                _->{
                                    io.println(parent_id <> " does not exist in posts")
                                    actor.continue(state)
                                }
                            }
                            
                        }
                        False->{
                            let comment_exists = dict.get(state.comments, parent_id)
                            case comment_exists{
                                Ok(comment)->{
                                    let new_comments = list.append(comment.comments, [new_comment])
                                    let new_comment = Comment(..comment, comments: new_comments)
                                    //Update the post and shit here before finishing comment I want to change this asap
                                    //now we have Posts -> List[Comment] : Comment -> List[Comment]
                                    // we need to update the list of comments, the comment, (Recurse up the hierarchy, (theres gotta be a better solution))
                                    //if we add a dict of comments:
                                    //store comments 
                                    let new_post = Post()
                                    let update
                                    let new_post = Post(..post)
                                    let updated_comments = dict.insert(state.)
                                }
                                _ -> {

                                }
                            }
                            actor.continue(state)
                        }
                    }
                }
                _-> {

                }
            }
            actor.continue(state)
        }
        Upvote(_parent_id)->{
            actor.continue(state)
        }
        Downvote(_parent_id)->{
            actor.continue(state)
        }
        RequestKarma(_user_id, _requester)->{
            actor.continue(state)
        }
        RequestFeed(_user_id, _requester)->{
            actor.continue(state)
        }
        SendMessage(_from_user_id, _to_user_id, _message)->{
            actor.continue(state)
        }
        GetInbox(_user_id, _requester)->{
            actor.continue(state)
        }
        _ -> {
            io.println("Type of Engine Message Not Found")
            actor.continue(state)
        }
    }
}
