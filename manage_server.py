import os
import sys
import socket
import subprocess
import time
import urllib.request
import json

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.join(BASE_DIR, "backend")
PORT = 8000


def get_local_ip():
    """Detecta o IP local da máquina na rede Wi-Fi/Ethernet."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.5)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def get_python_exe():
    """Prioriza o Python do ambiente virtual (.venv) se existir."""
    venv_py = os.path.join(BACKEND_DIR, ".venv", "Scripts", "python.exe")
    if os.path.exists(venv_py):
        return venv_py
    root_venv = os.path.join(BASE_DIR, ".venv", "Scripts", "python.exe")
    if os.path.exists(root_venv):
        return root_venv
    return sys.executable



def get_process_using_port(port):
    """Encontra o PID do processo usando a porta no Windows."""
    try:
        cmd = f'netstat -ano | findstr ":{port} "'
        output = subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL)
        pids = set()
        for line in output.strip().splitlines():
            parts = line.split()
            if len(parts) >= 5 and "LISTENING" in parts:
                pids.add(parts[-1])
        return list(pids)
    except Exception:
        return []


def is_server_running():
    """Verifica se o servidor FastAPI responde na rota de health."""
    try:
        url = f"http://127.0.0.1:{PORT}/health"
        req = urllib.request.Request(url, headers={"User-Agent": "HealthCheck/1.0"})
        with urllib.request.urlopen(req, timeout=2) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                return True, data
    except Exception:
        pass
    return False, None


def start_server():
    print("\n--- INICIANDO SERVIDOR FASTAPI ---")
    running, data = is_server_running()
    if running:
        print(f"[!] O servidor JA ESTA RODANDO na porta {PORT}!")
        print(f"    Status: {data}")
        return

    local_ip = get_local_ip()
    print(f"[*] Ouvindo em: 0.0.0.0:{PORT}")
    print(f"[*] IP Local (para o Celular): http://{local_ip}:{PORT}/api/v1")
    print(f"[*] Pressione CTRL+C nesta janela para parar o servidor.\n")

    python_exe = get_python_exe()
    print(f"[*] Python executável: {python_exe}")

    cmd = [
        python_exe, "-m", "uvicorn",
        "app.main:app",
        "--host", "0.0.0.0",
        "--port", str(PORT),
        "--reload"
    ]
    try:
        subprocess.run(cmd, cwd=BACKEND_DIR)
    except KeyboardInterrupt:
        print("\n[OK] Servidor interrompido pelo usuário.")


def stop_server():
    print("\n--- DESLIGANDO SERVIDOR FASTAPI ---")
    pids = get_process_using_port(PORT)
    if not pids:
        print(f"[INFO] Nenhum processo escutando na porta {PORT}.")
        return

    for pid in pids:
        try:
            subprocess.run(f"taskkill /F /PID {pid}", shell=True, check=False)
            print(f"[OK] Processo {pid} finalizado.")
        except Exception as e:
            print(f"[ERRO] Falha ao finalizar PID {pid}: {e}")

    time.sleep(1)
    running, _ = is_server_running()
    if not running:
        print("[OK] Servidor desligado com sucesso.")
    else:
        print("[!] A porta ainda parece ativa. Tente novamente.")


def check_status():
    print("\n--- STATUS DO SISTEMA ---")
    local_ip = get_local_ip()
    running, health = is_server_running()

    print(f"[*] IP do Computador na Rede: {local_ip}")
    if running:
        print(f"[OK] Status da API: ONLINE")
        print(f"     URL Local:   http://localhost:{PORT}/docs")
        print(f"     URL Celular: http://{local_ip}:{PORT}/api/v1")
    else:
        print("[!] Status da API: OFFLINE (Servidor parado)")


def print_menu():
    local_ip = get_local_ip()
    running, _ = is_server_running()
    status_str = "ONLINE" if running else "OFFLINE"
    print("\n" + "=" * 55)
    print("      B2B PERSONAL IA - GERENCIADOR DE SERVIDORES")
    print("=" * 55)
    print(f" Status: [{status_str}] | IP: {local_ip}:{PORT}")
    print("-" * 55)
    print("  [1] Iniciar Servidor (FastAPI 0.0.0.0:8000)")
    print("  [2] Desligar / Parar Servidor")
    print("  [3] Verificar Status (/health)")
    print("  [4] Exibir IP para Conectar no Celular")
    print("  [0] Sair")
    print("=" * 55)


def main():
    while True:
        print_menu()
        choice = input("\nEscolha uma opcao [0-4]: ").strip()
        if choice == "1":
            start_server()
        elif choice == "2":
            stop_server()
        elif choice == "3":
            check_status()
        elif choice == "4":
            local_ip = get_local_ip()
            print(f"\n" + "-" * 50)
            print(f" IP PARA CONFIGURAR NO APLICATIVO MÓVEL:")
            print(f"   http://{local_ip}:{PORT}/api/v1")
            print(f"-" * 50)
        elif choice == "0":
            print("\nEncerrando gerenciador. Ate logo!")
            break
        else:
            print("\n[!] Opcao invalida.")


if __name__ == "__main__":
    main()

