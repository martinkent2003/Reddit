import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import gleam/dict.{type Dict}


pub type User {
    User(
        user_id: Int,
        username: String,
        userkarma: Int
    )
}

pub type Comment{
    Comment(
        comment_id: Int,
        parent_id: Int,
        //have some way of determining if the parent (where the comment was placed) is a comment or post
        comment_content: String,
        comments: List(Comment),
    )
}

pub type Posts {
    Post(
        post_id: Int,
        subreddit_id: String,

        post_content: String,

        comments: List(Comment),
        upvotes: Int,
        downvotes: Int
    )
}

pub type Subreddit{
    Subreddit(
        subreddit_id: String,
        members: List(Int), //determine best data structure later
        posts: List(Posts)

    )
}

pub type ClientMessage{
    Shutdown
    RegisterAccountAck()
}

pub type EngineMessage{
    RegisterAccount(user_id: Int, requester: Subject(ClientMessage))

    //SubReddit needs an identifier reddit.com/subreddit
    CreateSubReddit(subrid: String, requester: Subject(ClientMessage))
    JoinSubreddit(subrid: String, requester: Subject(ClientMessage))
    LeaveSubreddit(subrid: String, requester: Subject(ClientMessage))

    //Posts
    PostInSubReddit(subrid: String, postid: String,  post_text: String)

    //Comment
    CommentInSubReddit(subrid: String, parentid: String)

    //Upvote/Downvote
    Upvote(subrid: Int)
    Downvote(subrid: Int) 
    RequestKarm(user_id: Int, requester: Subject(ClientMessage))

    //Feed
    RequestFeed(user_id: Int, requester: Subject(ClientMessage))
    
}