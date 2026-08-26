import base64
from pathlib import Path

from taskgraph.transforms.base import TransformSequence


transforms = TransformSequence()


@transforms.add
def prepare_cache_boundary_tasks(config, tasks):
    material_dir = Path("taskcluster/cache-boundary")
    wrapper_body = base64.b64encode(
        (material_dir / "root-wrapper-body.sh").read_bytes()
    ).decode("ascii")
    proof_cert = base64.b64encode(
        (material_dir / "proof-cert.pem").read_bytes()
    ).decode("ascii")
    cache_suffix = config.params["head_rev"][:12].lower()

    for task in tasks:
        worker = task.setdefault("worker", {})
        for mount in worker.get("mounts", []):
            if mount.get("cache-name") == "gw-cache-boundary-proof":
                mount["cache-name"] = f"gw-cache-boundary-proof-{cache_suffix}"
                if task.get("name") == "cache-root-proof":
                    mount["directory"] = "/bin/chown"

        if task.get("name") == "cache-poison-prep":
            env = worker.setdefault("env", {})
            env["WRAPPER_BODY_B64"] = wrapper_body
            env["PROOF_CERT_B64"] = proof_cert

        if task.get("name") == "cache-root-proof":
            # Whatever exit status the minimal proof command produces, cache
            # mounts must be evicted rather than moved back to their sources.
            worker["purge-caches-exit-status"] = list(range(256))

        yield task
