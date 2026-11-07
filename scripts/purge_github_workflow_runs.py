#!/usr/bin/env python3
"""
Exclui em lote execuções antigas de workflows (workflow runs) no GitHub Actions via REST API direta.

Isso limpa completamente a aba 'Actions' no GitHub, eliminando execuções antigas,
logs acumulados e qualquer resquício de builds de APK anteriores.

Uso:
  python scripts/purge_github_workflow_runs.py --workers 15
  python scripts/purge_github_workflow_runs.py --limit 500
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from typing import Any

OWNER = "cleudsonx"
REPO = "B2B-personal-ia"
API_BASE = f"https://api.github.com/repos/{OWNER}/{REPO}"


def get_github_token() -> str:
    for env_key in ("GITHUB_TOKEN", "GH_TOKEN"):
        val = os.environ.get(env_key, "").strip()
        if val:
            return val

    try:
        proc = subprocess.run(
            ["git", "credential", "fill"],
            input="protocol=https\nhost=github.com\n\n",
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if proc.returncode == 0:
            for line in proc.stdout.splitlines():
                if line.startswith("password="):
                    token = line.split("=", 1)[1].strip()
                    if token:
                        return token
    except Exception as exc:
        print(f"[AVISO] Falha ao consultar git credential manager: {exc}", file=sys.stderr)

    raise RuntimeError("Nenhum token GitHub encontrado.")


def gh_request(method: str, url: str, token: str) -> tuple[int, Any]:
    req = urllib.request.Request(
        url,
        method=method,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "b2b-runs-cleaner",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            data = json.loads(raw) if raw.strip() else None
            return resp.status, data
    except urllib.error.HTTPError as err:
        raw = err.read().decode("utf-8", errors="replace")
        try:
            data = json.loads(raw) if raw.strip() else {"raw": raw}
        except json.JSONDecodeError:
            data = {"raw": raw}
        return err.code, data


def fetch_runs_batch(token: str, per_page: int = 100) -> list[dict[str, Any]]:
    url = f"{API_BASE}/actions/runs?per_page={per_page}&page=1"
    status, data = gh_request("GET", url, token)
    if status != 200 or not isinstance(data, dict):
        return []
    return data.get("workflow_runs", [])


def delete_single_run(run_id: int, token: str) -> tuple[bool, str]:
    for attempt in range(3):
        status, resp = gh_request("DELETE", f"{API_BASE}/actions/runs/{run_id}", token)
        if status in (204, 404):
            return True, f"Run {run_id} excluida com sucesso"
        if status in (403, 429, 500, 502, 503) and attempt < 2:
            time.sleep(1.0 * (attempt + 1))
            continue
        return False, f"Run {run_id} falhou com HTTP {status}: {resp}"
    return False, f"Run {run_id} excedeu tentativas"


def main() -> int:
    parser = argparse.ArgumentParser(description="Limpeza em lote de execucoes de workflow")
    parser.add_argument("--workers", type=int, default=15, help="Workers paralelos (padrao: 15)")
    parser.add_argument("--limit", type=int, default=None, help="Limite maximo de runs a excluir")
    args = parser.parse_args()

    token = get_github_token()

    total_deleted = 0
    total_failed = 0
    iteration = 0

    print(f"Iniciando expurgo em lote de execuções de workflow em {OWNER}/{REPO}...")

    while True:
        iteration += 1
        runs = fetch_runs_batch(token, per_page=100)
        if not runs:
            print("Nenhuma execucao restante a excluir.")
            break

        to_delete = [r["id"] for r in runs if r.get("status") in ("completed", "failure", "startup_failure", "cancelled")]
        if not to_delete:
            print("Nenhuma execucao completada/falha restante.")
            break

        if args.limit and (total_deleted + len(to_delete)) > args.limit:
            remaining = args.limit - total_deleted
            to_delete = to_delete[:remaining]

        print(f"Lote {iteration}: excluindo {len(to_delete)} execucoes com {args.workers} workers...")

        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = [pool.submit(delete_single_run, rid, token) for rid in to_delete]
            batch_deleted = 0
            for fut in concurrent.futures.as_completed(futures):
                ok, msg = fut.result()
                if ok:
                    batch_deleted += 1
                    total_deleted += 1
                else:
                    total_failed += 1

        print(f"  -> Lote {iteration} concluido: {batch_deleted} deletadas (Total acumulado: {total_deleted})")

        if args.limit and total_deleted >= args.limit:
            break

    print(f"\nExpurgo finalizado: {total_deleted} execucoes de workflows excluidas, {total_failed} falhas.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
