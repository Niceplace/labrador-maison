# Pipelines

## Deno

Ideally, the deno pipeline does not continously poll, it should be triggered (best way to do it TBD)

Commit statuses will be updated in Github using [Cogito - Concourse git status resource](https://github.com/Pix4D/cogito)

Job
- Plan
    - Task1: Try to format (only check) & lint the source code        
    - Task2: Run unit tests (checks for `*test.unit.ts` files)
    - Task3: Run integration tests (checks for `*test.unit.ts` files)    
    - TaskX: Publish coverage report for unit tests (v2)
    - TaskX: Publish coverage report for integration tests (v2)
## nodejs
