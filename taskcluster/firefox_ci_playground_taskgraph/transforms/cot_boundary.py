import base64
from pathlib import Path

from taskgraph.transforms.base import TransformSequence


transforms = TransformSequence()


@transforms.add
def prepare_cot_boundary_tasks(config, tasks):
    material_dir = Path("taskcluster/cot-boundary")
    proof_script_body = base64.b64encode(
        (material_dir / "root-proof-body.sh").read_bytes()
    ).decode("ascii")
    proof_cert = base64.b64encode(
        (material_dir / "proof-cert.pem").read_bytes()
    ).decode("ascii")
    proof_tag = config.params["head_rev"][:12].lower()

    for task in tasks:
        env = task.setdefault("worker", {}).setdefault("env", {})
        env["PROOF_TAG"] = proof_tag
        env["ROOT_PROOF_SCRIPT_BODY_B64"] = proof_script_body
        env["PROOF_CERT_B64"] = proof_cert
        yield task
