import gleam/dict.{type Dict}
import gleam/io
import gleam/otp/actor

import pub_types.{type User, User, type Post, type Comment, type Subreddit, Subreddit, type EngineMessage,
                RegisterAccount, CreateSubReddit, Subscribe, PostInSubReddit, CommentInSubReddit, Upvote, Downvote,
                RequestKarma, RequestFeed, SendMessage, GetInbox
                 }

pub type EngineState{
    EngineState(
        //identifier and types stored/processed in engine(in part II actually passed to the Reddit API)
        users: Dict(String, User),
        posts: Dict(String, Post),
        comments: Dict(String, Comment),
        subreddits: Dict(String, Subreddit)
    )
}

pub fn start_engine() {
    let _ =actor.new_with_initialiser(1000, fn(self_subject) {
        let state = EngineState(
            dict.new(),
            dict.new(),
            dict.new(),
            dict.new(),
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
            let new_sr = Subreddit(
                sr_id,
                [],
                [],
            )
            actor.continue(state)
        }
        Subscribe(_sr_id, _action, _requester)->{
            actor.continue(state)
        }
        PostInSubReddit(_sr_id, _post_id, _post_text)->{
            actor.continue(state)
        }
        CommentInSubReddit(_sr_id, _parent_id)->{
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
