#!/usr/bin/env python3
"""
Smoke Test Automatizado Pós-Deploy - Mr. Coach (B2B Personal IA)

Executa verificações de 'fumaça' não-destrutivas (read-only e probes de segurança)
para validar se o serviço foi implantado e está saudável em staging ou produção.

Uso:
    python backend/scripts/smoke_test.py --url https://sua-api.onrender.com
    # ou localmente:
    python backend/scripts/smoke_test.py
"""

import sys
import os
import argparse
import time

try:
    import httpx
except ImportError:
    import requests as httpx  # fallback caso httpx não esteja instalado


def run_smoke_tests(base_url: str) -> bool:
    print("=" * 65)
    print(f"  MR. COACH - SMOKE TEST PÓS-DEPLOY")
    print(f"  Target: {base_url}")
    print(f"  Data: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 65)

    tests_passed = 0
    tests_failed = 0

    client = httpx.Client(timeout=15.0)

    # 1. Healthcheck Geral
    try:
        res = client.get(f"{base_url}/health")
        if res.status_code == 200 and "healthy" in res.text.lower():
            print("  [PASS] 1. Healthcheck /health: HTTP 200 (healthy)")
            tests_passed += 1
        else:
            print(f"  [FAIL] 1. Healthcheck /health: HTTP {res.status_code} - Body: {res.text[:100]}")
            tests_failed += 1
    except Exception as e:
        print(f"  [FAIL] 1. Healthcheck /health: Exceção de conexão: {e}")
        tests_failed += 1

    # 2. Documentação Swagger / OpenAPI
    try:
        res = client.get(f"{base_url}/docs")
        if res.status_code == 200:
            print("  [PASS] 2. Documentação Swagger /docs: HTTP 200 (Acessível)")
            tests_passed += 1
        else:
            print(f"  [FAIL] 2. Documentação Swagger /docs: HTTP {res.status_code}")
            tests_failed += 1
    except Exception as e:
        print(f"  [FAIL] 2. Documentação Swagger /docs: Exceção: {e}")
        tests_failed += 1

    # 3. Contrato OpenAPI JSON
    try:
        res = client.get(f"{base_url}/openapi.json")
        if res.status_code == 200 and "paths" in res.json():
            print("  [PASS] 3. Schema OpenAPI /openapi.json: HTTP 200 (JSON Válido)")
            tests_passed += 1
        else:
            print(f"  [FAIL] 3. Schema OpenAPI /openapi.json: HTTP {res.status_code}")
            tests_failed += 1
    except Exception as e:
        print(f"  [FAIL] 3. Schema OpenAPI /openapi.json: Exceção: {e}")
        tests_failed += 1

    # 4. Vitrine Pública de Treinadores
    try:
        res = client.get(f"{base_url}/api/v1/public/trainers")
        if res.status_code == 200 and isinstance(res.json(), list):
            print("  [PASS] 4. Vitrine Pública /api/v1/public/trainers: HTTP 200 (Lista OK)")
            tests_passed += 1
        else:
            print(f"  [FAIL] 4. Vitrine Pública /api/v1/public/trainers: HTTP {res.status_code}")
            tests_failed += 1
    except Exception as e:
        print(f"  [FAIL] 4. Vitrine Pública /api/v1/public/trainers: Exceção: {e}")
        tests_failed += 1

    # 5. Probe de Segurança: Rota protegida sem token deve barrar (401/403)
    try:
        res = client.get(f"{base_url}/api/v1/workouts/students")
        if res.status_code in (401, 403):
            print(f"  [PASS] 5. Proteção Auth /api/v1/workouts/students: HTTP {res.status_code} (Barrado corretamente)")
            tests_passed += 1
        else:
            print(f"  [FAIL] 5. Proteção Auth /api/v1/workouts/students: HTTP {res.status_code} (Esperado 401/403)")
            tests_failed += 1
    except Exception as e:
        print(f"  [FAIL] 5. Proteção Auth /api/v1/workouts/students: Exceção: {e}")
        tests_failed += 1

    # 6. Probe de Segurança: Webhook sem assinatura deve ser rejeitado (401/422)
    try:
        res = client.post(f"{base_url}/api/v1/subscriptions/webhook", json={"event": "TEST"})
        if res.status_code in (401, 403, 422):
            print(f"  [PASS] 6. Proteção Webhook /api/v1/subscriptions/webhook: HTTP {res.status_code} (Barrado)")
            tests_passed += 1
        else:
            print(f"  [FAIL] 6. Proteção Webhook: HTTP {res.status_code} (Esperado 401/403/422)")
            tests_failed += 1
    except Exception as e:
        print(f"  [FAIL] 6. Proteção Webhook: Exceção: {e}")
        tests_failed += 1

    print("=" * 65)
    print(f"  RESUMO: {tests_passed} Aprovados | {tests_failed} Falhas")
    print("=" * 65)

    if tests_failed == 0:
        print("  >>> SMOKE TEST APROVADO COM SUCESSO! DEPLOY ÍNTEGRO. <<<")
        return True
    else:
        print("  >>> SMOKE TEST REPROVADO! VERIFIQUE OS LOGS DO SERVIÇO. <<<")
        return False


def main():
    parser = argparse.ArgumentParser(description="Executa smoke test pós-deploy na API Mr. Coach")
    parser.add_argument(
        "--url",
        default=os.getenv("TARGET_URL", "http://localhost:8000"),
        help="URL base do backend (ex: http://localhost:8000 ou https://sua-api.onrender.com)"
    )
    args = parser.parse_args()

    clean_url = args.url.rstrip("/")
    success = run_smoke_tests(clean_url)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
