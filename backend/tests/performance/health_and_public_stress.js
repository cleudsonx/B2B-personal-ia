import http from 'k6/http';
import { check, sleep } from 'k6';

// Teste de Carga de Leitura: 100 usuários simultâneos consultando endpoints públicos
export const options = {
  stages: [
    { duration: '10s', target: 30 },  // Rampa de subida
    { duration: '30s', target: 100 }, // Pico de 100 VUs
    { duration: '10s', target: 0 },   // Resfriamento
  ],
  thresholds: {
    http_req_duration: ['p(95)<400'], // Leitura pública deve ser rápida (< 400ms)
    http_req_failed: ['rate<0.01'],   // Menos de 1% de falhas
  },
};

const BASE_URL = __ENV.TARGET_URL || 'http://localhost:8000';

export default function () {
  // 1. Healthcheck
  const resHealth = http.get(`${BASE_URL}/health`);
  check(resHealth, {
    'health responde 200': (r) => r.status === 200,
    'health body contém healthy': (r) => r.body && r.body.includes('healthy'),
  });

  // 2. Vitrine Pública de Treinadores
  const resPublic = http.get(`${BASE_URL}/api/v1/public/trainers`);
  check(resPublic, {
    'vitrine pública responde 200': (r) => r.status === 200,
    'tempo vitrine < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(0.3);
}

