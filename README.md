Kochiku
=======

Kochiku means "Build" in Japanese (sort of). Kochiku runs your automated tests.

Kochiku consists of three pieces. A web server, background jobs which partition a build into many parts, and workers
that execute the individual build parts. Typically the first two run on a single machine, and there are many
machines running workers.


Who Should Use Kochiku
----------------------


Documentation
-------------

Most of the documentation is kept on the [wiki](https://github.com/square/kochiku/wiki).

Running Kochiku in development
------------------------------

It is not necessary to have a farm of workers in order to develop Kochiku. Just run the Kochiku web server
locally.

```sh
# create the database and seed it with dummy data
rake db:setup

# start server
rails server

# optionally spin up a partition worker
QUEUES=high,partition rake resque:work
```

Sometimes, you'll also want to run build jobs; if so also clone the [kochiku-worker][gh-kw] repository.

Contributing
------------

See [CONTRIBUTING](CONTRIBUTING.md).

[gh-kw]: https://github.com/square/kochiku-worker
