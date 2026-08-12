# syntax=docker/dockerfile:1.7
#
# Stage Definitions:
#   base      : Pre-built lind-wasm-dev toolchain
#   source    : Copies build context and records revision metadata
#   test      : Runs `make test` and parses results
#   dev       : Interactive debugging environment for reproducing failures (pushed to Docker Hub / Not yet)
#   artifacts : Minimal stage for extracting test outputs via `--output type=local`
#
# Usage Examples:
#   docker buildx build --target artifacts --output type=local,dest=./out .
#   docker buildx build --target dev -t <repo>:<tag> --push .
ARG BRANCH_NAME=main
ARG COMMIT_SHA=
# Digest of the lind-wasm-dev base image, resolved by the caller. The :latest
# tag moves, so recording the digest is what makes a run reproducible later.
ARG BASE_DIGEST=
ARG HOME_DIR=/home/lind

# ── base ────────────────────────────────────────────────────────────────────
FROM securesystemslab/lind-wasm-dev:latest AS base
ARG HOME_DIR
ENV HOME_DIR=${HOME_DIR}
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ── source ──────────────────────────────────────────────────────────────────
FROM base AS source
ARG BRANCH_NAME
ARG COMMIT_SHA
ARG BASE_DIGEST

COPY --chown=lind:lind . ${HOME_DIR}/lind-wasm-example-grates
WORKDIR ${HOME_DIR}/lind-wasm-example-grates

RUN mkdir -p ${HOME_DIR}/e2e-artifacts && \
    printf 'branch=%s\ncommit=%s\nbase_digest=%s\nbuilt_at=%s\n' \
        "${BRANCH_NAME}" "${COMMIT_SHA:-<none>}" "${BASE_DIGEST:-<none>}" \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        > ${HOME_DIR}/e2e-artifacts/revision.txt

# ── test ────────────────────────────────────────────────────────────────────
FROM source AS test
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV LIND_WASM_ROOT=${HOME_DIR}/lind-wasm
WORKDIR ${HOME_DIR}/lind-wasm-example-grates

RUN if make test 2>&1 | tee ${HOME_DIR}/e2e-artifacts/make-test.log; then \
        echo "E2E_STATUS=pass" > ${HOME_DIR}/e2e_status; \
    else \
        status=$?; \
        echo "E2E_STATUS=fail" > ${HOME_DIR}/e2e_status; \
        printf '\nmake test exited with status %s\n' "${status}" \
            >> ${HOME_DIR}/e2e-artifacts/make-test.log; \
    fi; \
    sed -r 's/\x1b\[[0-9;]*m//g' ${HOME_DIR}/e2e-artifacts/make-test.log \
        > ${HOME_DIR}/e2e-artifacts/make-test.plain.log; \
    { \
        grep -E '^[[:space:]]+(Total|Passed|Failed|Skipped):' \
            ${HOME_DIR}/e2e-artifacts/make-test.plain.log || true; \
        echo; \
        grep -oE '(FAIL|SKIP): [A-Za-z0-9_.-]+ / [A-Za-z0-9_.-]+ \([^)]*\)' \
            ${HOME_DIR}/e2e-artifacts/make-test.plain.log || true; \
        grep -oE 'SKIP: [A-Za-z0-9_.-]+ \(configured[^)]*\)' \
            ${HOME_DIR}/e2e-artifacts/make-test.plain.log || true; \
    } > ${HOME_DIR}/e2e-artifacts/test-summary.txt; \
    echo "=== test summary ==="; \
    cat ${HOME_DIR}/e2e-artifacts/test-summary.txt

# ── dev ─────────────────────────────────────────────────────────────────────
FROM test AS dev
ENV LIND_WASM_ROOT=${HOME_DIR}/lind-wasm
WORKDIR ${HOME_DIR}/lind-wasm-example-grates

# ── artifacts ───────────────────────────────────────────────────────────────
FROM scratch AS artifacts
ARG HOME_DIR
COPY --from=test ${HOME_DIR}/e2e_status /e2e_status
COPY --from=test ${HOME_DIR}/e2e-artifacts /test-artifacts
