# Summary

Kochiku is a continuous integration tool built specifically for test suites that have become too long to execute serially and need to be broken down into smaller pieces and run in parallel.

The word Kochiku means "Build" in Japanese.

# Features

Coming soon...

# Architecture

Kochiku has two main components. A web application and a builder process.

## Kochiku Web Application

The Kochiku web application provides everything you need to add new projects and view the status and results of each build.

TODO: insert screenshot here

## Kochiku Builder

The builder is a long running resque process that runs on each server that is running tests. Builders can be removed and added at will.
