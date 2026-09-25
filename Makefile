.PHONY: help install-backend run-backend test-backend run-mobile

help:
	@echo "Comandos disponíveis:"
	@echo "  make install-backend   - Instala as dependências Python no backend"
	@echo "  make run-backend       - Inicia a API FastAPI na porta 8000"
	@echo "  make test-backend      - Executa os testes automatizados do backend"
	@echo "  make run-mobile        - Inicia o app Flutter em modo debug"

install-backend:
	cd backend && pip install -r requirements.txt

run-backend:
	cd backend && uvicorn app.main:app --reload --port 8000

test-backend:
	cd backend && pytest

run-mobile:
	cd mobile && flutter run
