# Pipelines

## Deno 

### Summary
This pipeline automatically builds & deploy a [deno](https://deno.land/) app using [the best pipeline tool known to humans](https://concourse-ci.org/docs.html)

Commit statuses of apps in scope are be updated in Github using [Cogito - Concourse git status resource](https://github.com/Pix4D/cogito)

Currently the pipeline is configured to poll at regular intervals for new versions, ideally it should be triggered via webhooks so we don't waste previous seconds waiting.

### Pipeline overview

- Code formatting & linting validation to ensure code readability & convention
- Tests (unit & integration) to safeguard against regressions
- Semver-ish version bump, home-made, generates a git tag & used later on with the Docker image
- Build Docker image
- Push generated Docker image to private registry with appropriate tags
- Deploy generated Docker image to production, cleaning up older running images of same app in the process
