import mist
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}

pub type User {
  User(
    user_id: String,
    userkarma: Int,
    user_subject: Subject(ClientMessage),
    subscribed_sr: List(String),
  )
}

pub type UserInbox {
  UserInbox(
    user_id: String,
    inboxes: Dict(String, List(String)),
    // here the string is the id to the DirectMessage
  )
}

pub type DirectMessage {
  DirectMessage(from_user_id: String, to_user_id: String, content: String)
}

pub type Comment {
  Comment(
    comment_id: String,
    parent_id: String,
    user_id: String,
    //have some way of determining if the parent (where the comment was placed) is a comment or post
    comment_content: String,
    comments: List(String),
    upvotes: Int,
    downvotes: Int,
  )
}

pub type Post {
  Post(
    post_id: String,
    //passed by the user----
    user_id: String,
    subreddit_id: String,
    post_content: String,
    //                  ----
    comments: List(String),
    //storing comment Id's instead of actual comment
    upvotes: Int,
    downvotes: Int,
  )
}

pub type Subreddit {
  Subreddit(
    sr_id: String,
    members: List(String),
    //of userId's
    posts: List(String),
    //of postId's
  )
}

pub type SimulatorMessage {
  StartSimulator
  Ping(iteration: Int)
  ReceivePong(iteration: Int, values: #(Int, Int, Int))
  EndSimulation
}



pub type ClientMessage {
  Connect
  Shutdown
  //these two are actually used only in the API router ===
  Nack(String)
  Ack(String)
  ListAck(messages: List(String))
  //======================================================
  DirectMessageInbox(messages: Dict(String, DirectMessage))
  ClientJoinSubreddit(List(String))
  ReceiveFeed(posts: List(Post))
  ReceiveKarma(karma: Int)
  ActivitySim
  ActOnComment(comment: Comment)
}

pub type EngineMessage {
  RegisterAccount(user_id: String, requester: Subject(ClientMessage))
  //SubReddit needs an identifier reddit.com/subreddit
  CreateSubReddit(sr_id: String, requester: Subject(ClientMessage))
  JoinSubreddit(
    user_id: String,
    sr_id: String,
    requester: Subject(ClientMessage),
  )
  LeaveSubreddit(
    user_id: String,
    sr_id: String,
    requester: Subject(ClientMessage),
  )
  //Posts
  PostInSubReddit(user_id: String, sr_id: String, post_text: String)
  //Comment
  CommentInSubReddit(
    parent_id: String,
    user_id: String,
    comment_message: String,
  )
  GetComment(comment_id: String, requester: Subject(ClientMessage))
  //Upvote/Downvote(on comment or post)
  Upvote(parent_id: String)
  Downvote(parent_id: String)
  RequestKarma(user_id: String, requester: Subject(ClientMessage))
  //Feed
  RequestFeed(user_id: String, requester: Subject(ClientMessage))
  //Messages
  SendMessage(from_user_id: String, to_user_id: String, message: String)
  RequestInbox(user_id: String, requester: Subject(ClientMessage))
  PrintSubredditSizes

  Pong(iteration: Int, return_to: Subject(SimulatorMessage))
}
