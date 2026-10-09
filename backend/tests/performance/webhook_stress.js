import http from 'k6/http';
import { check, sleep } from 'k6';

// Configuração de Carga: Rampa de subida, sustentação sob pico e resfriamento
export const options = {
  stages: [
    { duration: '10s', target: 20 },  // Aquecimento: 20 usuários simultâneos
    { duration: '30s', target: 50 },  // Carga máxima: 50 requisições simultâneas
    { duration: '10s', target: 0 },   // Desaceleração
  ],
  thresholds: {
    http_req_duration: ['p(95)<800'], // 95% das requisições devem responder em menos de 800ms
    http_req_failed: ['rate<0.01'],   // Taxa de erro menor que 1%
  },
};

const BASE_URL = __ENV.TARGET_URL || 'http://localhost:8000';

export default function () {
  // Simula um payload de webhook do Asaas (evento de pagamento recebido)
  const eventId = `k6-stress-evt-${__VU}-${__ITER}`;
  const payload = JSON.stringify({
    event: 'PAYMENT_RECEIVED',
    payment: {
      id: `pay_${eventId}`,
      customer: 'cus_k6_stress_test',
      value: 99.90,
      netValue: 97.90,
      billingType: 'PIX',
      status: 'RECEIVED',
      confirmedDate: new Date().toISOString(),
    },
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'asaas-access-token': __ENV.ASAAS_WEBHOOK_SECRET || 'test_webhook_secret_k6',
      'X-Idempotency-Key': eventId,
    },
  };

  const res = http.post(`${BASE_URL}/api/v1/subscriptions/webhook`, payload, params);

  check(res, {
    'status é 200, 401 ou 422 (sem 500)': (r) => r.status === 200 || r.status === 401 || r.status === 422,
    'tempo de resposta aceitável (<1000ms)': (r) => r.timings.duration < 1000,
  });

  sleep(0.5);
}

