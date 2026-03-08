"""Entry point for GEPA optimization: python -m runner.gepa"""

from __future__ import annotations

import argparse
import asyncio

from gepa import optimize
from gepa.utils.stop_condition import MaxCandidateProposalsStopper

from runner.gepa.adapter import (
    SkillDescriptionAdapter,
    _run_async,
    build_seed_candidate,
    build_trainset,
    write_back_descriptions,
)
from runner.trigger.task import build_dispatcher_agent


def _evaluate_candidate(candidate: dict[str, str]) -> float:
    """Evaluate a candidate against the trigger dataset, return accuracy."""
    from runner.trigger.dataset import build_trigger_dataset

    agent = build_dispatcher_agent(descriptions=candidate)
    dataset = build_trigger_dataset()

    async def _single(case: object) -> bool:
        result = await agent.run(case.inputs.query)  # type: ignore[union-attr]
        predicted = result.output.strip().lower().strip("\"'")
        return predicted == case.expected_output  # type: ignore[union-attr]

    async def _run() -> float:
        results = await asyncio.gather(*[_single(c) for c in dataset.cases])
        return sum(results) / len(results) if results else 0.0

    return _run_async(_run())  # type: ignore[return-value]


def main() -> None:
    parser = argparse.ArgumentParser(description="Run GEPA skill description optimization")
    parser.add_argument(
        "--iterations",
        type=int,
        default=10,
        help="Number of candidate proposals (optimization rollouts) to run",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print proposed changes without writing to SKILL.md",
    )
    parser.add_argument(
        "--write-back",
        action="store_true",
        help="Write optimized descriptions back to SKILL.md frontmatter",
    )
    parser.add_argument(
        "--reflection-lm",
        type=str,
        default="gemini/gemini-2.5-flash",
        help="litellm model string for reflection/proposal step (default: gemini/gemini-2.5-flash)",
    )
    args = parser.parse_args()

    seed = build_seed_candidate()
    trainset = build_trainset()

    print(f"Starting GEPA optimization over {len(trainset)} trigger cases")
    print(f"Rollouts: {args.iterations}")
    print(f"Seed descriptions: {list(seed.keys())}")

    # Evaluate seed candidate first
    print("\nEvaluating seed candidate...")
    seed_score = _evaluate_candidate(seed)
    print(f"Seed accuracy: {seed_score:.1%}")

    adapter = SkillDescriptionAdapter()

    print(f"Reflection LM: {args.reflection_lm}")

    result = optimize(
        seed_candidate=seed,
        trainset=trainset,
        adapter=adapter,
        reflection_lm=args.reflection_lm,
        stop_callbacks=[MaxCandidateProposalsStopper(max_proposals=args.iterations)],
        display_progress_bar=True,
    )

    best_candidate = result.best_candidate

    print("\n--- Optimized Descriptions ---")
    for skill, desc in best_candidate.items():
        original = seed.get(skill, "")
        changed = desc != original
        marker = "[CHANGED]" if changed else "  unchanged"
        print(f"\n{marker}: {skill}")
        if changed:
            print(f"  Before: {original}")
            print(f"  After:  {desc}")

    # Evaluate optimized candidate
    print("\nEvaluating optimized candidate...")
    final_score = _evaluate_candidate(best_candidate)
    print(f"Final accuracy: {final_score:.1%} (was {seed_score:.1%})")

    if args.write_back and not args.dry_run:
        print("\nWriting optimized descriptions back to SKILL.md files...")
        write_back_descriptions(best_candidate)
    elif args.dry_run:
        print("\n[DRY RUN] Not writing changes to SKILL.md")
    else:
        print("\nRun with --write-back to apply changes to SKILL.md")


if __name__ == "__main__":
    main()
