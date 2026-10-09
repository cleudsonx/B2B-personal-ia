# Suíte de Testes de Carga e Performance (k6) - Mr. Coach

Esta suíte avalia a resiliência do backend sob concorrência e estresse real utilizando o [k6](https://k6.io).

## 1. Instalação do k6

- **Windows (winget ou choco):**
  ```powershell
  winget install k6 --source winget
  # ou via chocolatey:
  choco install k6
  ```
- **macOS:**
  ```bash
  brew install k6
  ```
- **Linux:**
  ```bash
  sudo gpg -k
  sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
  echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
  sudo apt-get update && sudo apt-get install k6
  ```

## 2. Como Executar

### 2.1 Teste de Stress nos Webhooks (Idempotência e Locks Concorrentes)
```powershell
k6 run tests/performance/webhook_stress.js -e TARGET_URL="http://localhost:8000"
```

### 2.2 Teste de Leitura e Healthcheck (100 Usuários Virtuais)
```powershell
k6 run tests/performance/health_and_public_stress.js -e TARGET_URL="http://localhost:8000"
```

### 2.3 Execução Automatizada no Windows
Execute o script em lote:
```powershell
.\tests\performance\run_stress_tests.bat
```
