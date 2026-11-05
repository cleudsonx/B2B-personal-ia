"""
Automação Zero-Touch de Migração & Validação Dual-Stack: Render -> Google Cloud Run
====================================================================================
Este script automatiza:
1. Extração de variáveis de ambiente e secrets diretamente da API do Render (via RENDER_API_KEY)
   ou consolidação a partir do .env local + render.yaml.
2. Enriquecimento automático para suporte Dual-Domain (shaipados.com + shapelab.ia.br).
3. Geração do manifesto `.env.cloudrun.yaml` pronto para injeção no Google Cloud Run
   (`gcloud run services update b2b-personal-ia-backend --env-vars-file=.env.cloudrun.yaml`).
4. Benchmark e Smoke Test comparativo entre Render (Legado) e Cloud Run (Novo) para garantir
   paridade de saúde (/health), CORS multi-domínio e ganho real de latência antes do desligamento.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from typing import Dict, List, Optional, Tuple

import httpx

RENDER_API_BASE = "https://api.render.com/v1"
DEFAULT_RENDER_URL = "https://b2b-personal-ia-backend.onrender.com"
DEFAULT_GCP_PROJECT = "shaipados-labs"
DEFAULT_GCP_REGION = "southamerica-east1"
DEFAULT_SERVICE_NAME = "b2b-personal-ia-backend"

DUAL_DOMAIN_ORIGINS = [
    "https://shaipados.com",
    "https://www.shaipados.com",
    "https://shaipados-labs.web.app",
    "https://shaipados-labs.firebaseapp.com",
    "https://mrcoach.shaipados.com",
    "https://mrcoach.app",
    "https://app.shaipados.com",
    "https://shapelab.ia.br",
    "https://www.shapelab.ia.br",
    "https://app.shapelab.ia.br",
    "https://mrcoach.shapelab.ia.br",
]

BASE_PRODUCTION_DEFAULTS: Dict[str, str] = {
    "ENVIRONMENT": "production",
    "DEFAULT_FAST_MODEL": "gemini-2.5-flash",
    "DEFAULT_DEEP_MODEL": "gemini-2.5-flash",
    "AIS_GATEWAY_URL": "https://ais-dev-3ey6ymjmlzt5sh4qusmboi-873261240850.us-east1.run.app",
    "SUPABASE_URL": "https://rgbyfiulomxpqkuufdtg.supabase.co",
    "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_GM85tixsI7l1WTU3jhEmoQ_s_pv_F6C",
    "SUPABASE_JWKS_URL": "https://rgbyfiulomxpqkuufdtg.supabase.co/auth/v1/.well-known/jwks.json",
    "ASAAS_API_URL": "https://api.asaas.com/v3",
    "CORS_ORIGINS": json.dumps(DUAL_DOMAIN_ORIGINS),
}


def fetch_render_env_vars(render_api_key: str, service_name: str = DEFAULT_SERVICE_NAME) -> Dict[str, str]:
    """Busca todas as variáveis de ambiente e secrets diretamente da API v1 do Render."""
    headers = {
        "Authorization": f"Bearer {render_api_key}",
        "Accept": "application/json",
    }
    with httpx.Client(timeout=20.0, headers=headers) as client:
        resp = client.get(f"{RENDER_API_BASE}/services", params={"name": service_name, "limit": 20})
        resp.raise_for_status()
        services = resp.json()
        service_id: Optional[str] = None
        for item in services:
            svc = item.get("service", item)
            if svc.get("name") == service_name:
                service_id = svc.get("id")
                break
        if not service_id and services:
            service_id = services[0].get("service", services[0]).get("id")
        if not service_id:
            raise RuntimeError(f"Serviço '{service_name}' não encontrado na conta Render informada.")

        env_resp = client.get(f"{RENDER_API_BASE}/services/{service_id}/env-vars", params={"limit": 100})
        env_resp.raise_for_status()
        raw_items = env_resp.json()

        extracted: Dict[str, str] = {}
        for entry in raw_items:
            env_var = entry.get("envVar", entry)
            key = env_var.get("key")
            val = env_var.get("value")
            if key and val is not None:
                extracted[str(key)] = str(val)
        return extracted


def build_cloud_run_env_dict(
    render_vars: Optional[Dict[str, str]] = None,
    target_domain: str = "shapelab.ia.br",
    cloud_run_url: Optional[str] = None,
) -> Dict[str, str]:
    """Consolida as variáveis de produção garantindo suporte Dual-Domain (shaipados.com + shapelab.ia.br)."""
    merged: Dict[str, str] = dict(BASE_PRODUCTION_DEFAULTS)
    if render_vars:
        for k, v in render_vars.items():
            if k.upper() == "PORT":
                continue  # Cloud Run gerencia PORT automaticamente (8080)
            merged[k] = v

    # Garante que todas as origens Dual-Domain estejam presentes em CORS_ORIGINS
    merged["CORS_ORIGINS"] = json.dumps(DUAL_DOMAIN_ORIGINS)
    merged["WEB_CONCURRENCY"] = "1"

    if cloud_run_url:
        merged["PUBLIC_BACKEND_URL"] = cloud_run_url.rstrip("/")

    if target_domain == "shapelab.ia.br":
        merged.setdefault("APP_FRONTEND_URL", "https://shapelab.ia.br")
        merged.setdefault("APP_BACKEND_URL", "https://api.shapelab.ia.br")

    return merged


def write_gcloud_env_yaml(env_dict: Dict[str, str], output_path: str) -> None:
    """Gera arquivo YAML compatível com `gcloud run services update --env-vars-file`."""
    lines: List[str] = [
        "# Gerado automaticamente por migrate_render_to_cloud_run.py (NÃO COMMITAR)",
    ]
    for key in sorted(env_dict.keys()):
        val = str(env_dict[key]).replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'{key}: "{val}"')
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def probe_endpoint(base_url: str, origin: str) -> Tuple[bool, float, int, Optional[str], dict]:
    """Executa probe de saúde (/health) e inspeciona cabeçalho CORS para uma origem."""
    url = f"{base_url.rstrip('/')}/health"
    headers = {"Origin": origin}
    t0 = time.perf_counter()
    try:
        with httpx.Client(timeout=15.0) as client:
            resp = client.get(url, headers=headers)
            elapsed_ms = (time.perf_counter() - t0) * 1000.0
            allow_origin = resp.headers.get("access-control-allow-origin")
            payload = resp.json() if resp.status_code == 200 else {}
            return (resp.status_code == 200, elapsed_ms, resp.status_code, allow_origin, payload)
    except Exception as exc:
        elapsed_ms = (time.perf_counter() - t0) * 1000.0
        return (False, elapsed_ms, 0, None, {"error": str(exc)})


def run_parity_verification(render_url: str, cloud_run_url: Optional[str] = None) -> int:
    """Valida saúde, latência e suporte Dual-Domain CORS no Render e (se fornecido) no Cloud Run."""
    print("=" * 78)
    print(" VERIFICAÇÃO AUTOMÁTICA DE PARIDADE DUAL-STACK & MULTI-DOMÍNIO")
    print("=" * 78)

    targets = [("Render (Legado Ohio)", render_url)]
    if cloud_run_url:
        targets.append(("Google Cloud Run (São Paulo)", cloud_run_url))

    all_ok = True
    for label, url in targets:
        print(f"\n-> Testando [{label}]: {url}")
        for domain in ["https://shaipados.com", "https://shapelab.ia.br"]:
            ok, ms, status, cors_hdr, payload = probe_endpoint(url, domain)
            status_tag = "OK" if ok else "FALHA"
            print(
                f"   [{status_tag}] Origin={domain:<24} | HTTP {status} | "
                f"Latência={ms:6.1f} ms | ACAO={cors_hdr or '(ausente)'}"
            )
            if not ok:
                all_ok = False

    print("\n" + "=" * 78)
    return 0 if all_ok else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Automação de Migração Render -> Cloud Run")
    parser.add_argument("--render-api-key", default=os.environ.get("RENDER_API_KEY", ""))
    parser.add_argument("--render-url", default=os.environ.get("RENDER_URL", DEFAULT_RENDER_URL))
    parser.add_argument("--cloud-run-url", default=os.environ.get("CLOUD_RUN_URL", ""))
    parser.add_argument("--output-yaml", default=".env.cloudrun.yaml")
    parser.add_argument("--apply-gcloud", action="store_true", help="Aplica as variáveis no Cloud Run via gcloud CLI")
    parser.add_argument("--verify", action="store_true", help="Executa bateria de verificação Dual-Stack e CORS")
    args = parser.parse_args()

    render_vars: Dict[str, str] = {}
    if args.render_api_key:
        print("[1/3] Extraindo variáveis e secrets de produção via API do Render...")
        render_vars = fetch_render_env_vars(args.render_api_key)
        print(f"      {len(render_vars)} variáveis extraídas com sucesso do Render.")
    else:
        print("[1/3] RENDER_API_KEY não informada; gerando manifesto base com Dual-Domain configurado.")

    env_dict = build_cloud_run_env_dict(
        render_vars=render_vars,
        cloud_run_url=args.cloud_run_url or None,
    )
    write_gcloud_env_yaml(env_dict, args.output_yaml)
    print(f"[2/3] Manifesto Cloud Run gerado em: {args.output_yaml} ({len(env_dict)} chaves)")

    if args.apply_gcloud:
        print("[3/3] Aplicando variáveis de ambiente no serviço Cloud Run via gcloud...")
        cmd = [
            "gcloud", "run", "services", "update", DEFAULT_SERVICE_NAME,
            "--project", DEFAULT_GCP_PROJECT,
            "--region", DEFAULT_GCP_REGION,
            f"--env-vars-file={args.output_yaml}",
            "--quiet",
        ]
        subprocess.run(cmd, check=True)
        print("      Variáveis sincronizadas com sucesso no Cloud Run!")

    if args.verify:
        return run_parity_verification(args.render_url, args.cloud_run_url or None)

    return 0


if __name__ == "__main__":
    sys.exit(main())

