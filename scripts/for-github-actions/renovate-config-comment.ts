#!/usr/bin/env bun

/**
 * Post or update a PR comment with Renovate config validation results
 * Uses Bun runtime with native fetch (GitHub API)
 * Usage: bun renovate-config-comment.ts <validation_output> <pr_number>
 */

// Type definitions
interface Comment {
  id: number
  body: string
}

// Input validation
if (Bun.argv.length !== 4) {
  console.error('Error: Invalid number of arguments')
  console.error(`Usage: ${Bun.argv[1]} <validation_output> <pr_number>`)
  process.exit(1)
}

const validationOutput = Bun.argv[2]
const prNumber = Bun.argv[3]

if (!validationOutput) {
  console.error('Error: Validation output cannot be empty')
  process.exit(1)
}

if (!prNumber) {
  console.error('Error: PR number cannot be empty')
  process.exit(1)
}

// Validate PR number is a positive integer
if (!/^\d+$/.test(prNumber)) {
  console.error('Error: PR number must be a positive integer')
  process.exit(1)
}

// Get environment variables using Bun.env
const githubToken = Bun.env.GITHUB_TOKEN
const githubRepo = Bun.env.GITHUB_REPOSITORY

if (!githubToken) {
  console.error('Error: GITHUB_TOKEN environment variable not set')
  process.exit(1)
}

if (!githubRepo) {
  console.error('Error: GITHUB_REPOSITORY environment variable not set')
  process.exit(1)
}

// Create a unique identifier for our validation comment
const COMMENT_MARKER = '<-- renovate-config-workflow-comment -->'

// Create comment body with validation results
const commentBody = `${COMMENT_MARKER}
## Renovate Config Validation Results

\`\`\`
${validationOutput}
\`\`\`

---

💡 **Tip:** Run \`npx --yes --package renovate -- renovate-config-validator --no-global .github/renovate-config.js\` locally to test your config before pushing!
`

const main = async (): Promise<void> => {
  try {
    // Fetch PR comments using GitHub API
    const commentsResponse = await fetch(
      `https://api.github.com/repos/${githubRepo}/issues/${prNumber}/comments`,
      {
        headers: {
          Accept: 'application/vnd.github+json',
          Authorization: `Bearer ${githubToken}`,
          'X-GitHub-Api-Version': '2022-11-28',
        },
      }
    )

    if (!commentsResponse.ok) {
      throw new Error(`Failed to fetch comments: ${commentsResponse.statusText}`)
    }

    const comments: Comment[] = (await commentsResponse.json()) as Comment[]

    // Find existing comment with our marker
    const existingComment = comments.find((comment: Comment) =>
      comment.body?.includes(COMMENT_MARKER)
    )

    if (existingComment) {
      // Update existing comment using GitHub API
      const updateResponse = await fetch(
        `https://api.github.com/repos/${githubRepo}/issues/comments/${existingComment.id}`,
        {
          method: 'PATCH',
          headers: {
            Accept: 'application/vnd.github+json',
            Authorization: `Bearer ${githubToken}`,
            'X-GitHub-Api-Version': '2022-11-28',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ body: commentBody }),
        }
      )

      if (!updateResponse.ok) {
        throw new Error(`Failed to update comment: ${updateResponse.statusText}`)
      }

      console.log(`Updated existing PR comment #${existingComment.id}`)
    } else {
      // Create new comment using GitHub API
      const createResponse = await fetch(
        `https://api.github.com/repos/${githubRepo}/issues/${prNumber}/comments`,
        {
          method: 'POST',
          headers: {
            Accept: 'application/vnd.github+json',
            Authorization: `Bearer ${githubToken}`,
            'X-GitHub-Api-Version': '2022-11-28',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ body: commentBody }),
        }
      )

      if (!createResponse.ok) {
        throw new Error(`Failed to create comment: `)
      }

      console.log('Created new PR comment')
    }
  } catch (error: unknown) {
    console.error(
      'Error posting PR comment:',
      error instanceof Error ? error.message : String(error)
    )
    process.exit(1)
  }
}

main()
