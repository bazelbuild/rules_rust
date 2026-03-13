# Multiplex Sandbox Overhead Investigation Plan

## Goal

Determine which of these is true:

1. Stage-pool reuse is blocked mainly by Bazel worker process churn.
2. Reuse is structurally too rare even with fewer or longer-lived workers.
3. Bazel-side sandbox preparation is now a comparable or larger cost than `process_wrapper`
   staging.

## Phase 1: Worker-Lifetime Matrix

Run `//sdk/sdk_builder:sdk_builder_lib` first. It is cheaper than `//sdk` and already showed the
regression clearly.

Use the same sandboxed `worker-pipe` flags as the current benchmark, then sweep:

1. `--worker_max_instances=Rustc=1,2,4`
2. `--worker_max_multiplex_instances=Rustc=8,12,16`

That yields 9 configurations. Do 2 measured iterations each after a warm-up run.

Suggested command pattern:

```bash
bazel clean --expunge
bazel build //sdk/sdk_builder:sdk_builder_lib \
  --@rules_rust//rust/settings:pipelined_compilation=true \
  --@rules_rust//rust/settings:experimental_worker_pipelining=true \
  --experimental_worker_multiplex_sandboxing \
  --strategy=Rustc=worker,sandboxed \
  --strategy=RustcMetadata=worker,sandboxed \
  --worker_max_instances=Rustc=${MAX_INSTANCES} \
  --worker_max_multiplex_instances=Rustc=${MULTIPLEX} \
  --profile=/tmp/sdk_builder_${MAX_INSTANCES}_${MULTIPLEX}.json.gz \
  2>&1 | tee /tmp/sdk_builder_${MAX_INSTANCES}_${MULTIPLEX}.log
```

After each run, collect:

1. Wall time
2. Critical path
3. `worker_preparing`
4. `worker_working`
5. Count of distinct worker PIDs or worker workdirs
6. Slot `reuse_count` histogram from `_pw_state/pipeline/*/pipeline.log`

### Success Criteria

- If lower `worker_max_instances` causes `reuse_count > 1` and setup time drops materially, keep
  the current per-process reuse design and tune worker topology.
- If `reuse_count` stays at `1` across the matrix, per-process reuse is the wrong abstraction.

## Phase 2: Confirm on Full `//sdk`

Take the best 1-2 configurations from Phase 1 and rerun on `//sdk`:

```bash
bazel clean --expunge
bazel build //sdk \
  --@rules_rust//rust/settings:pipelined_compilation=true \
  --@rules_rust//rust/settings:experimental_worker_pipelining=true \
  --experimental_worker_multiplex_sandboxing \
  --strategy=Rustc=worker,sandboxed \
  --strategy=RustcMetadata=worker,sandboxed \
  --worker_max_instances=Rustc=${MAX_INSTANCES} \
  --worker_max_multiplex_instances=Rustc=${MULTIPLEX} \
  --profile=/tmp/sdk_${MAX_INSTANCES}_${MULTIPLEX}.json.gz \
  2>&1 | tee /tmp/sdk_${MAX_INSTANCES}_${MULTIPLEX}.log
```

This checks whether any improvement survives in the full mixed graph.

## Phase 3: Decide the Next Engineering Direction

If Phase 1 and Phase 2 still show `reuse_count=1`:

1. Prototype cross-process stage slots under a shared directory such as
   `_pw_state_shared/stage_pool`.
2. Use file locking per slot.
3. Keep the manifest conservative and invalidate on any ambiguity.

The more detailed design and measurement plan for that option now lives in
[`2026-03-11-cross-process-shared-stage-pool-plan.md`](/var/mnt/dev/rules_rust/thoughts/shared/plans/2026-03-11-cross-process-shared-stage-pool-plan.md).
The concrete next-context prototype plan now lives in
[`2026-03-12-shared-cross-process-stage-pool-prototype-plan.md`](/var/mnt/dev/rules_rust/thoughts/shared/plans/2026-03-12-shared-cross-process-stage-pool-prototype-plan.md).

If Phase 1 and Phase 2 show reuse but wall time barely changes:

1. Investigate Bazel-side sandbox preparation directly.
2. Compare `worker_preparing` against `process_wrapper` `diff_ms` and `total_setup_ms`.
3. If Bazel preparation dominates, worker-side staging is no longer the main bottleneck.

## Phase 4: Input-Set Narrowing

In parallel with the topology sweep, test whether metadata actions are overdeclaring inputs.

Important constraint from follow-up implementation work on 2026-03-11: a broad analysis-side
toolchain input reduction attempt regressed full `//sdk` correctness (`E0463` missing-crate
failures). Treat input-set narrowing as a trace-driven investigation only; do not land further
metadata input pruning without per-action access evidence and full-graph validation.

Pick 3-5 metadata actions from `sdk_builder_lib` and trace actual file opens:

```bash
strace -f -e trace=file -o /tmp/rustc_files.trace <single metadata rustc invocation>
```

Questions to answer:

1. Are most declared inputs ever opened?
2. Are whole trees being staged that metadata rustc never touches?
3. Are `_pipeline/*.rmeta` and extern inputs the only hot subset?

If the answer is yes, the next code change should be analysis-side input narrowing, because that
reduces both Bazel sandbox preparation and worker-side staging.

## Results Table

Use one row per run:

```text
| target | max_instances | multiplex | iter | wall_s | crit_s | worker_preparing_s | worker_working_s | distinct_workers | metadata_actions | avg_setup_ms | p90_setup_ms | avg_stage_ms | slot_reuse_gt1 | max_reuse_count | notes |
|--------|---------------|-----------|------|--------|--------|--------------------|------------------|------------------|------------------|--------------|--------------|--------------|----------------|-----------------|-------|
```

Add a short summary block per configuration:

```text
config: max_instances=X multiplex=Y
- mean wall_s:
- mean crit_s:
- mean worker_preparing_s:
- slot reuse summary:
- verdict:
```

## Decision Rule

- If reducing worker process count yields real slot reuse and at least about 10% setup reduction,
  keep iterating on the current design.
- If not, stop investing in per-process pools and move to either shared cross-process reuse or
  trace-driven input-set reduction.
- If Bazel `worker_preparing` remains much larger than `process_wrapper` staging, prioritize
  Bazel-side sandbox investigation before more worker code.
