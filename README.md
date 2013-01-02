Kochiku
=======

Kochiku is "Build" in Japanese (according to google translate).

Kochiku consists of two pieces. There is a master process and a number of slave
workers. The slave workers check out a copy of your project into a directory
and run a subset of the tests inside of it. They then report status, any build
artifacts (logs, etc) and statistical information back to the master server.


Master
------

Responsibilities:

 - Is alerted about git changes
 - Reads the build.yml from the checked out project
 - divides build into parts
 - puts the parts on a resque queue

### Models
 - Build: a sha to build
 - Build parts: A build has many of these, each one corresponds to the atomic unit of your tests
 - Build attempts: Each build part can have many build attempts. This records state so we can retry parts.
 - Build artifacts: Each attempt has artifacts (only log files right now) that are associated with that run.


Worker
------

The worker is in [its own GitHub repository][kochiku-worker].

### BuildPartitioningJob
Fills the queue with build part jobs. Enqueued by the master.

### BuildPartJob
Runs the tests for a particular part of the build. Updates status.

### BuildStateUpdateJob
Promotes a tag if the build is successful. Enqueued by BuildAttemptObserver.


Getting Started
---------------

    # create database
    rake db:setup

    # start server
    rails server

    # run a partition worker
    QUEUE=high,partition rake resque:work

Make sure to also clone the [kochiku-worker] repository if you need to run
build jobs.

[kochiku-worker]: https://git.squareup.com/square/kochiku-worker
