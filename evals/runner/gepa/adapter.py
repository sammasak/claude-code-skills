"""GEPA adapter for optimizing skill descriptions via evolutionary search."""

from __future__ import annotations

import asyncio
import re
import threading
from collections.abc import Mapping, Sequence
from typing import Any

from gepa import EvaluationBatch, GEPAAdapter

from runner.trigger.dataset import EVALS_ROOT, build_trigger_dataset
from runner.trigger.task import build_dispatcher_agent, load_skill_descriptions

SKILLS_ROOT = EVALS_ROOT.parent / "skills"

# Persistent event loop running in a background thread.
# Reusing one loop across all evaluate() calls prevents httpx connection-pool
# teardown errors that occur when asyncio.run() closes its loop between calls.
_BG_LOOP: asyncio.AbstractEventLoop = asyncio.new_event_loop()
threading.Thread(target=_BG_LOOP.run_forever, daemon=True, name="gepa-eval-loop").start()


def _run_async(coro: object) -> object:
    """Run an async coroutine on the persistent background loop and return its result."""
    import asyncio as _asyncio

    future = _asyncio.run_coroutine_threadsafe(coro, _BG_LOOP)  # type: ignore[arg-type]
    return future.result()


class SkillDescriptionAdapter(GEPAAdapter):
    """Optimizes skill description strings to maximize trigger eval accuracy.

    The 'candidate' dict maps skill names to their current description strings.
    GEPA evolves these descriptions to maximize dispatch accuracy on the trigger dataset.
    """

    def evaluate(
        self,
        batch: list[dict[str, Any]],
        candidate: dict[str, str],
        capture_traces: bool = False,
    ) -> EvaluationBatch:
        """Run the dispatcher with candidate descriptions on the given batch."""
        agent = build_dispatcher_agent(descriptions=candidate)

        async def _single(data_inst: dict[str, Any]) -> tuple[str, str, float]:
            result = await agent.run(data_inst["query"])
            predicted = result.output.strip().lower().strip("\"'")
            expected = data_inst["expected"]
            return predicted, expected, 1.0 if predicted == expected else 0.0

        async def _run_all() -> list[tuple[str, str, float]]:
            return list(await asyncio.gather(*[_single(d) for d in batch]))

        triplets = _run_async(_run_all())  # type: ignore[assignment]

        outputs = [t[0] for t in triplets]
        scores = [t[2] for t in triplets]
        trajectories = (
            [{"predicted": t[0], "expected": t[1], "query": b.get("query", "")} for t, b in zip(triplets, batch)]
            if capture_traces
            else None
        )

        return EvaluationBatch(
            outputs=outputs,
            scores=scores,
            trajectories=trajectories,
        )

    def make_reflective_dataset(
        self,
        candidate: dict[str, str],
        eval_batch: EvaluationBatch,
        components_to_update: list[str],
    ) -> Mapping[str, Sequence[Mapping[str, Any]]]:
        """Build failure analysis for the GEPA proposer."""
        failures = []
        trajectories = eval_batch.trajectories or []
        scores = eval_batch.scores

        for score, traj in zip(scores, trajectories):
            if score < 1.0 and traj:
                failures.append(
                    {
                        "query": traj.get("query", ""),
                        "predicted": traj.get("predicted", ""),
                        "expected": traj.get("expected", ""),
                    }
                )

        # Build per-component reflection data
        reflective_data: dict[str, list[dict[str, Any]]] = {}
        for skill in components_to_update:
            skill_failures = [f for f in failures if f["expected"] == skill or f["predicted"] == skill]
            reflective_data[skill] = [
                {
                    "current_description": candidate.get(skill, ""),
                    "failures": skill_failures,
                    "instruction": (
                        f"The skill '{skill}' is being mis-classified in {len(skill_failures)} cases. "
                        "Revise its description to be more distinctive and precise. "
                        "Output ONLY the revised description as a single line of plain text — "
                        "no bullet points, no headings, no newlines."
                    ),
                }
            ]

        return reflective_data


def build_seed_candidate() -> dict[str, str]:
    """Load the current skill descriptions as the seed candidate."""
    return load_skill_descriptions()


def build_trainset() -> list[dict[str, Any]]:
    """Build the GEPA training set from trigger cases."""
    dataset = build_trigger_dataset()
    return [
        {
            "query": case.inputs.query,
            "expected": case.expected_output,
            "category": case.metadata.category if case.metadata else "unknown",
        }
        for case in dataset.cases
    ]


def write_back_descriptions(optimized: dict[str, str]) -> None:
    """Write optimized descriptions back to SKILL.md frontmatter files."""
    for skill_name, new_desc in optimized.items():
        # YAML frontmatter requires single-line values; collapse any newlines from GEPA output
        new_desc = " ".join(new_desc.split())
        skill_md = SKILLS_ROOT / skill_name / "SKILL.md"
        if not skill_md.exists():
            print(f"  SKIP {skill_name}: SKILL.md not found")
            continue

        content = skill_md.read_text()
        # Replace description field in frontmatter (handles quoted and unquoted values).
        # Use a callable replacement — lambda bypasses re.sub's backslash interpretation,
        # so new_desc is used verbatim without any pre-escaping.
        new_content = re.sub(
            r'^(description:\s*)["\']?.*?["\']?\s*$',
            lambda m: f'{m.group(1)}"{new_desc}"',
            content,
            flags=re.MULTILINE,
        )
        if new_content != content:
            skill_md.write_text(new_content)
            print(f"  UPDATED {skill_name}")
        else:
            print(f"  UNCHANGED {skill_name}")
