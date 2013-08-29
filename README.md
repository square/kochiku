Kochiku - Distributed tests made easy
=====================================

Kochiku is a distributed platform for test automation. It has three main components:

- A **web server**, which lets you inspect builds and manage repositories
- **Background jobs** that divide builds into distributable parts
- **Workers** that run individual parts of a build

A single machine typically runs the web server and background jobs, whereas many machines run workers.

Use Kochiku to distribute large test suites quickly and easily.

### Git integration

Kochiku currently integrates with git repositories stored in Github (including Github Enterprise) or Atlassian Stash. This lets Kochiku automatically run test suites for pull requests and commits to the master branch. Kochiku can also build any git revision on request.

Support for headless git servers is coming soon.

## User Guide
- [Installation & Deployment](https://github.com/square/kochiku/wiki/Installation-&-Deployment)
- [Adding a repository](https://github.com/square/kochiku/wiki/How-to-add-a-repository-to-Kochiku)
- [Initiating a build](https://github.com/square/kochiku/wiki/How-to-initiate-a-build-on-Kochiku)
- [Additional documentation](https://github.com/square/kochiku/wiki/_pages)
- [Contributing to Kochiku](CONTRIBUTING.md)