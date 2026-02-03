---
description: This skill should be used when the user asks to "reply to PR comments", "respond to review comments", "reply to PR #123", "answer PR feedback", or wants to respond to unresolved review threads or comments from other users on a pull request.
argument-hint: "<pr-number>"
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob
---

# GitHub PR Comment Replier

Reply to comments on a GitHub pull request by analyzing unresolved review threads and comments from other users, generating thoughtful responses based on codebase context, and posting replies directly.

## Workflow

### Step 1: Fetch PR Information

Retrieve the pull request details and identify the current user:

```bash
gh api user --jq '.login'
```

Store the current user's login to filter out self-authored comments.

### Step 2: Fetch Review Threads

Query review threads using GitHub GraphQL API:

```bash
gh api graphql -f query='
query($owner:String!,$repo:String!,$pr:Int!) {
  repository(owner:$owner,name:$repo) {
    pullRequest(number:$pr) {
      id
      reviewThreads(first:100) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          isResolved
          path
          line
          comments(last:1) {
            nodes {
              id
              author { login }
              body
              createdAt
            }
          }
        }
      }
    }
  }
}' -F owner='{owner}' -F repo='{repo}' -F pr=$ARGUMENTS
```

Extract owner and repo from the current git remote:

```bash
gh repo view --json owner,name --jq '"\(.owner.login) \(.name)"'
```

### Step 3: Filter Actionable Threads

Identify threads requiring replies based on these criteria:

1. **Unresolved threads** (`isResolved == false`)
2. **Latest comment is from another user** (not the current user)

Filter logic:
- Skip threads where `isResolved == true`
- Skip threads where the latest comment author matches the current user
- Include all remaining threads as actionable

### Step 4: Analyze and Generate Replies

For each actionable thread:

1. **Read the comment**: Understand what the reviewer is asking or suggesting
2. **Examine the code context**: Read the file at the specified path and line
3. **Analyze the codebase**: Use Grep and Glob to understand related code, patterns, and context
4. **Generate a thoughtful reply**: Address the reviewer's concern with specifics

When generating replies:
- Be concise but thorough
- Reference specific code when relevant
- Acknowledge valid points
- Explain reasoning for decisions
- If changes were made, mention the fix
- If changes are not needed, explain why respectfully

### Step 5: Post Replies

Post each reply using the GraphQL mutation:

```bash
gh api graphql -f query='
mutation($thread:ID!,$body:String!) {
  addPullRequestReviewThreadReply(input:{
    pullRequestReviewThreadId:$thread
    body:$body
  }) {
    comment { id }
  }
}' -f thread="$THREAD_ID" -f body="$REPLY_BODY"
```

### Step 6: Report Summary

After processing all threads, provide a summary:
- Number of threads processed
- Number of replies posted
- Any threads that were skipped and why

## Important Guidelines

### Reply Quality

- Address the specific concern raised in the comment
- Provide context from the codebase when relevant
- Be professional and collaborative
- Keep replies focused and actionable

### Codebase Analysis

- Read the file mentioned in the thread's `path` field
- Look at surrounding code for context
- Check for related patterns elsewhere in the codebase
- Consider the reviewer's perspective

### Error Handling

- If `gh` CLI is not authenticated, inform the user to run `gh auth login`
- If the PR number is invalid, report the error clearly
- If no actionable threads are found, report that no replies are needed
- If posting a reply fails, report the error and continue with remaining threads

### Pagination

For PRs with many threads (>100), handle pagination:
- Check `pageInfo.hasNextPage`
- Use `endCursor` for subsequent queries
- Process all pages before generating replies
