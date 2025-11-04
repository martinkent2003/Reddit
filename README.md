# Reddit-like Engine Simulation

**Project 4: Part I**  
*Authors: Martin Kent and Alex Vargas*  
*Date: November 1, 2025*

## Overview

A Reddit-like social media engine simulator implemented in Gleam using the actor model. The system simulates concurrent user interactions including posting, commenting, voting, and direct messaging across multiple subreddits. The implementation leverages Erlang's OTP framework to handle concurrent client processes communicating with a centralized engine.

## System Architecture

The simulation consists of three main components:

- **Engine Process**: Centralized server that manages all data structures (users, posts, comments, subreddits, direct messages) and handles state updates
- **Client Actor Processes**: Independent processes representing individual users that maintain local state and perform simulated activities
- **Simulator Coordinator**: Initializes the system, spawns clients, and collects performance metrics

## Features

### Core Reddit Functionality
- User registration with karma tracking
- Subreddit creation and membership management
- Text-based posts within subreddits
- Hierarchical comment system (comments on posts and comments)
- Upvote/downvote system with karma calculation
- Personalized feed generation based on subscriptions
- User-to-user direct messaging with inbox management

### Realistic Behavior Simulation
- **Zipf Distribution for Subreddits** (s=1.0): Models how few subreddits attract many subscribers while most have fewer members
- **Zipf Distribution for User Activity** (s=0.5): Creates varying engagement patterns with highly active and less active users
- **Six Activity Types**: Direct messaging, posting, post interaction, comment interaction, feed refresh, and inbox checking

## Installation & Usage

### Prerequisites
- Gleam (latest version)
- Erlang/OTP

### Running the Simulation

```bash
# Build the project
gleam build

# Run with specified number of clients
gleam run <num_of_clients>

# Example: Run with 100 clients
gleam run 100
```

### Simulation Parameters
- **num_clients**: Total number of simulated users (command-line argument)
- **num_subreddits**: Automatically set to num_clients / 2
- **avg_subreddits_per_user**: 5 subscriptions per user on average
- **zipf_s_subreddits**: 1.0 (high concentration in popular subreddits)
- **zipf_s_clients**: 0.5 (moderate concentration in active users)
- **simulation_duration**: 100 seconds (100 ping-pong iterations)

## File Structure

```
├── reddit.gleam          # Main entry point
├── engine.gleam          # Centralized engine process
├── client.gleam          # Client actor implementation
├── simulator.gleam       # Simulator coordinator
├── tick.gleam           # Activity ticker for clients
└── pub_types.gleam      # Type definitions
```

## How It Works

### Engine Implementation
The engine maintains dictionaries for users, posts, comments, subreddits, user inboxes, and direct messages. It processes messages through pattern matching and handles:
- User registration and karma tracking
- Subreddit creation, joining, and leaving
- Post creation with unique IDs
- Hierarchical comment structure (posts → comments → nested comments)
- Vote processing (upvotes/downvotes affect karma)
- Feed generation (aggregates posts from subscribed subreddits)
- Direct messaging system with inbox management

### Client Implementation
Each client maintains local state including subscribed subreddits, cached feed, karma, and inbox. Upon connection, clients start an activity ticker that triggers one of six random actions:
1. **Direct Messaging** (16.7%): Reply to inbox messages or message random post authors
2. **Posting** (16.7%): Create posts in random subscribed subreddits
3. **Post Interaction** (16.7%): Comment, upvote, or downvote posts
4. **Comment Interaction** (16.7%): Interact with comments or recurse into nested threads
5. **Feed Refresh** (16.7%): Request updated feed from engine
6. **Inbox Check** (16.7%): Request updated direct messages

### Simulator Implementation
The simulator:
1. Generates Zipf distributions for subreddit popularity and user activity
2. Spawns client actors with activity timeouts based on Zipf distribution (50ms to 30s)
3. Creates subreddits (num_clients / 2)
4. Assigns subreddit memberships weighted by popularity
5. Monitors performance through ping-pong latency tests
6. Collects metrics: response time, posts/second, comments/second, messages/second

## Performance Results

### Test Configuration
- **Clients**: 100 concurrent users
- **Duration**: 100 seconds
- **Metrics**: Engine delay, content generation rates

### Key Findings

#### Response Time Patterns
- **0-27s**: Sub-millisecond response times (<1ms)
- **28-64s**: Moderate delays (10-60ms)
- **65-99s**: Exponential degradation (589ms to 18.7s)

#### Content Generation (Steady-State)
- **Posts**: ~320 posts/second
- **Comments**: ~100-130 comments/second
- **Messages**: ~200-300 messages/second

#### Critical Threshold
System performance degrades significantly after:
- ~21,000 posts
- ~5,000 comments
- ~12,000 messages

### Performance Summary Table

| Time | Delay (s) | Posts  | Comments | Messages | ΔPosts | ΔComments | ΔMsgs |
|------|-----------|--------|----------|----------|--------|-----------|-------|
| 0    | 0.0002    | 18     | 0        | 1        | 18     | 0         | 1     |
| 30   | 0.0348    | 9,531  | 1,440    | 3,575    | 263    | 78        | 176   |
| 60   | 0.0463    | 19,454 | 4,351    | 10,402   | 339    | 104       | 246   |
| 90   | 10.9723   | 29,489 | 7,674    | 18,362   | 326    | 115       | 296   |
| 99   | 18.6550   | 32,476 | 8,707    | 20,859   | 307    | 85        | 263   |

## Technical Details

### Zipf Distribution Formula
```
P(k) = (1/k^s) / Σ(1/n^s) for n=1 to N
```
where:
- k = rank
- s = distribution parameter
- N = total number of items

### Activity Timeout Calculation
```
wait = min(0.05 / (scale × zipf_weight), 30.0) seconds
scale = √(num_clients)
```

## Conclusions

### Strengths
- Successfully implements all required Reddit functionality
- Actor model provides excellent isolation and concurrency
- Maintains sub-millisecond response times up to ~20,000 posts
- Content generation rates remain stable even under engine stress
- Zipf distributions create realistic user behavior patterns

### Limitations
- Single-process engine becomes bottleneck at high load
- Exponential degradation after ~21,000 posts with 100 clients
- Message queue buildup causes response time explosion
- Feed generation becomes expensive with large subreddit post counts

### Future Enhancements
- Distributed engine architecture with sharding
- Post scoring algorithms (hot, top, controversial)
- Moderation features and user permissions
- Markdown and rich content support
- Real-time updates using pub-sub patterns

## License
Academic project for distributed systems coursework.

## Contact
- Martin Kent
- Alex Vargas