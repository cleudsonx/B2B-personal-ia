#!/usr/bin/env python3
"""
Forca a exclusao de artefatos antigos do GitHub Actions via REST API direta.

Por que este script existe:
Quando o armazenamento de artefatos do GitHub Actions estoura a cota (500 MB),
o proprio GitHub bloqueia a inicializacao de novos runners (inclusive workflows
de limpeza!). A unica forma de destravar e deletar os artefatos diretamente via
GitHub REST API fora dos runners do Actions.

Uso:
  python scripts/purge_github_artifacts.py --list
  python scripts/purge_github_artifacts.py --before-date 2026-11-06
  python scripts/purge_github_artifacts.py --keep-latest 1
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
BRT_TZ = dt.timezone(dt.timedelta(hours=-3))


def get_github_token() -> str:
    """Obtem token do ambiente ou do Git Credential Manager local (sem jamais imprimi-lo)."""
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

    raise RuntimeError(
        "Nenhum token GitHub encontrado em GITHUB_TOKEN/GH_TOKEN ou no Git Credential Manager."
    )


def gh_request(method: str, url: str, token: str) -> tuple[int, Any]:
    req = urllib.request.Request(
        url,
        method=method,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "b2b-personal-ia-artifact-cleaner",
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


def list_all_artifacts(token: str) -> list[dict[str, Any]]:
    artifacts: list[dict[str, Any]] = []
    page = 1
    while True:
        url = f"{API_BASE}/actions/artifacts?per_page=100&page={page}"
        status, data = gh_request("GET", url, token)
        if status != 200:
            raise RuntimeError(f"Erro HTTP {status} ao listar artefatos: {data}")
        batch = data.get("artifacts", [])
        if not batch:
            break
        artifacts.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    return artifacts


def parse_gh_timestamp(ts: str) -> dt.datetime:
    return dt.datetime.fromisoformat(ts.replace("Z", "+00:00"))


def delete_single_artifact(art: dict[str, Any], token: str) -> tuple[bool, int, str]:
    art_id = art["id"]
    size_bytes = int(art.get("size_in_bytes", 0))
    created_brt = parse_gh_timestamp(art["created_at"]).astimezone(BRT_TZ)
    for attempt in range(3):
        status, resp = gh_request("DELETE", f"{API_BASE}/actions/artifacts/{art_id}", token)
        if status in (204, 404):
            return (
                True,
                size_bytes,
                f"ID={art_id} | {art['name']} | {size_bytes / (1024 * 1024):.2f} MB | {created_brt.strftime('%d/%m/%Y %H:%M')}",
            )
        if status in (403, 429, 500, 502, 503, 504) and attempt < 2:
            time.sleep(1.5 * (attempt + 1))
            continue
        return (False, 0, f"ID={art_id} HTTP {status}: {resp}")
    return (False, 0, f"ID={art_id} excedeu tentativas")


def main() -> int:
    parser = argparse.ArgumentParser(description="Limpeza forcada de artefatos do GitHub Actions")
    parser.add_argument(
        "--list",
        action="store_true",
        help="Apenas lista todos os artefatos ativos e o espaco ocupado",
    )
    parser.add_argument(
        "--before-date",
        type=str,
        default=None,
        help="Exclui todos os artefatos criados antes desta data em BRT (YYYY-MM-DD). Ex: 2026-11-06 exclui 05/11 para tras.",
    )
    parser.add_argument(
        "--keep-latest",
        type=int,
        default=None,
        help="Mantem apenas os N artefatos mais recentes (nao expirados) e exclui todos os demais.",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=8,
        help="Numero de requisicoes paralelas de exclusao (padrao: 8)",
    )
    args = parser.parse_args()

    token = get_github_token()
    all_artifacts = list_all_artifacts(token)

    active = [a for a in all_artifacts if not a.get("expired", False)]
    active.sort(key=lambda a: a.get("created_at", ""), reverse=True)

    total_bytes = sum(int(a.get("size_in_bytes", 0)) for a in active)
    print(f"Repositorio: {OWNER}/{REPO}")
    print(f"Artefatos totais listados: {len(all_artifacts)} | Ativos (ocupando cota): {len(active)}")
    print(f"Armazenamento ativo estimado: {total_bytes / (1024 * 1024):.2f} MB\n")

    if args.list or (args.before_date is None and args.keep_latest is None):
        for idx, art in enumerate(active[:25], start=1):
            created_brt = parse_gh_timestamp(art["created_at"]).astimezone(BRT_TZ)
            size_mb = int(art.get("size_in_bytes", 0)) / (1024 * 1024)
            print(
                f"  [{idx:03d}] ID={art['id']} | {art['name']} | "
                f"{size_mb:6.2f} MB | BRT={created_brt.strftime('%Y-%m-%d %H:%M:%S')}"
            )
        if len(active) > 25:
            print(f"  ... e mais {len(active) - 25} artefato(s).")
        return 0

    to_delete: list[dict[str, Any]] = []

    if args.before_date:
        year, month, day = (int(p) for p in args.before_date.split("-"))
        cutoff_brt = dt.datetime(year, month, day, 0, 0, 0, tzinfo=BRT_TZ)
        print(f"Filtro de corte (BRT): anteriores a {cutoff_brt.strftime('%Y-%m-%d %H:%M:%S %z')}")
        for art in active:
            created_brt = parse_gh_timestamp(art["created_at"]).astimezone(BRT_TZ)
            if created_brt < cutoff_brt:
                to_delete.append(art)

    if args.keep_latest is not None:
        keep_n = max(0, args.keep_latest)
        extra = active[keep_n:]
        existing_ids = {a["id"] for a in to_delete}
        for art in extra:
            if art["id"] not in existing_ids:
                to_delete.append(art)

    if not to_delete:
        print("Nenhum artefato ativo corresponde ao criterio de exclusao.")
        return 0

    print(f"Iniciando exclusao forcada paralela de {len(to_delete)} artefato(s) (workers={args.workers})...")
    deleted_count = 0
    freed_bytes = 0
    failed_count = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(delete_single_artifact, art, token) for art in to_delete]
        for idx, fut in enumerate(concurrent.futures.as_completed(futures), start=1):
            ok, sz, msg = fut.result()
            if ok:
                deleted_count += 1
                freed_bytes += sz
                if deleted_count <= 10 or deleted_count % 50 == 0 or deleted_count == len(to_delete):
                    print(f"  [{deleted_count:03d}/{len(to_delete):03d}] EXCLUIDO -> {msg}")
            else:
                failed_count += 1
                print(f"  [FALHA] {msg}", file=sys.stderr)

    print(
        f"\nConcluido: {deleted_count} artefato(s) excluido(s), {failed_count} falha(s), "
        f"{freed_bytes / (1024 * 1024):.2f} MB ({freed_bytes / (1024 * 1024 * 1024):.2f} GB) liberados!"
    )
    return 0 if failed_count == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
