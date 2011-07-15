Kochiku is "Build" in Japanese (according to google translate).

# Currently

Kochiku consists of two pieces. There is a master process and a number of slave workers. The slave workers check out a copy of your project into a directory and run a subset of the tests inside of it. They then report status, any build artifacts (logs, etc) and statistical information back to the master server.

### Models
 - Build: a sha to build
 - Build parts: A build has many of these, each one corresponds to the atomic unit of your tests
 - Build attempts: Each build part can have many build attempts. This records state so we can retry parts.
 - Build artifacts: Each attempt has artifacts (only log files right now) that are associated with that run.

## Master
Responsibilities:

 - Is alerted about git changes
 - Reads the build.yml from the checked out project
 - divides build into parts
 - puts the parts on a resque queue


## Worker
### BuildPartitioningJob
Fills the queue with build part jobs. Enqueued by the master.

### BuildPartJob
Runs the tests for a particular part of the build. Updates status.

### BuildStateUpdateJob
Promotes a tag if the build is successful. Enqueued by BuildAttemptObserver.


# Future Work
## TODO
X - fix workers to upload build artifacts
X - fix log display to not suck
X - make ui pretty
- email on build failures
- Rebuild button on part page
- Fix colors on index page to be related to status, not kind
- rename "dogfood" to "feature_branch" or "staging"
- run different queues on master and slaves
- increase granularity of parts
- A new master build should cancel any pending builds on master
- Cancel button for pending builds
- Factories
- integration tests
- Additional reporting for build parts in ui
 - frequent failures
 - change in build time for a part
- Auto retry failed parts
- sort build parts based on previous build times (front load slow parts)
- speed up test start up (sql cache, ram disk, etc)
- reduce overhead for spinning up a new worker
  - Add apis so build part workers don't have to talk to database
  - split queues so internal queues (updating state and partitioning) run on master machine only
  - make sure we have minimal prereqs for a worker
- Add details about our architecture to README
- open source