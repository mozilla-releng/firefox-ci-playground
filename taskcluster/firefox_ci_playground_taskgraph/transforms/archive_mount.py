from urllib.parse import urlsplit

from taskgraph.transforms.base import TransformSequence


transforms = TransformSequence()


def raw_github_url(repository, revision, filename):
    parsed = urlsplit(repository)
    if parsed.scheme != "https" or parsed.netloc != "github.com":
        raise ValueError(f"expected an https://github.com repository, got {repository!r}")

    repository_path = parsed.path.rstrip("/")
    if repository_path.endswith(".git"):
        repository_path = repository_path[:-4]
    return (
        f"https://raw.githubusercontent.com{repository_path}/{revision}/"
        f"taskcluster/archive-mount/{filename}"
    )


@transforms.add
def pin_archive_mount_inputs(config, tasks):
    repository = config.params["head_repository"]
    revision = config.params["head_rev"]

    for task in tasks:
        for mount in task.setdefault("worker", {}).get("mounts", []):
            content = mount.get("content", {})
            url = content.get("url", "")
            if url.startswith("archive-mount://"):
                filename = url[len("archive-mount://") :]
                content["url"] = raw_github_url(repository, revision, filename)
        yield task
