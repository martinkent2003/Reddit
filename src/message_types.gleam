import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import gleam/dict.{type Dict}

pub type ClientMessage{
    Shutdown
    RegisterAccountAcc()
}

pub type EngineMessage{
    RegisterAccount()
    //SubReddit needs an identifier reddit.com/subreddit
    CreateSubReddit(id: Int)
    JoinSubreddit(id: Int )
    LeaveSubreddit()
}