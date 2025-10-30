import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import gleam/dict.{type Dict}


pub type User{
    User(
        user_id: String,
        userkarma: Int,
        user_subject: Subject(ClientMessage)
    )
}

pub type Comment{
    Comment(
        comment_id: String,
        parent_id: String,
        //have some way of determining if the parent (where the comment was placed) is a comment or post
        comment_content: String,
        comments: List(Comment),
    )
}

pub type Post{
    Post(
        post_id: String,
        //passed by the user----
        user_id: String,
        subreddit_id: String,
        post_content: String,
        //                  ----
        comments: List(Comment),//storing comment Id's instead of actual comment
        upvotes: Int,
        downvotes: Int
    )
}

pub type Subreddit{
    Subreddit(
        sr_id: String,
        members: List(String), //of userId's
        posts: List(String)//of postId's
    )
}

pub type SimulatorMessage{
    StartSimulator()
}

pub type ClientMessage{
    Shutdown
    RegisterAccountAck()
}

pub type EngineMessage{
    RegisterAccount(user_id: String, requester: Subject(ClientMessage))

    //SubReddit needs an identifier reddit.com/subreddit
    CreateSubReddit(sr_id: String, requester: Subject(ClientMessage))
    JoinSubreddit(user_id: String, sr_id: String, requester: Subject(ClientMessage))
    LeaveSubreddit(user_id: String, sr_id: String, requester: Subject(ClientMessage))

    //Posts
    PostInSubReddit(user_id: String, sr_id: String, post_text: String)
 
    //Comment
    CommentInSubReddit(parent_id: String, comment_message: String)

    //Upvote/Downvote(on comment or post)
    Upvote(parent_id: String)
    Downvote(parent_id: String) 
    RequestKarma(user_id: String, requester: Subject(ClientMessage))

    //Feed
    RequestFeed(user_id: String, requester: Subject(ClientMessage))

    //Messages
    SendMessage(from_user_id: String, to_user_id: String, message: String)

    GetInbox(user_id: String, requester: Subject(ClientMessage))
    
}