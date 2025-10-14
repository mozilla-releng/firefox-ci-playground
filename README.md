# firefox-ci-playground

This repo provides a place to experiment and play around with Taskgraph on the
Firefox-CI Taskcluster instance.

## How to Use

1. Request write access to the repo in [#firefox-ci] on Matrix.
2. Clone this repo (no need for a fork) and create a new branch based off of main.
3. Create apps, add tasks, make changes, do whatever you want! If you are
   unfamiliar with Taskgraph, the [official documentation] is a great resource
   for getting started.
4. Either create a pull request or push to a non-main branch (depending on what
   you are testing out).

   If you are creating a pull request, please keep it in the draft state so we
   know that it is not intended to be merged.

   If pushing to a non-main branch, please consider prefixing
   it with your user name to help keep things tidy. E.g, assuming you named
   your branch ``my-branch`` and your user name is ``user``, you can run:

   $ git push origin my-branch:user/my-branch

If you have any questions or requests, please reach out on [#firefox-ci]!

[#firefox-ci]: https://matrix.to/#/#firefox-ci:mozilla.org
[official documentation]: https://taskcluster-taskgraph.readthedocs.io/en/latest/
