import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 20 },
    { duration: '60s', target: 50 },
    { duration: '30s', target: 0 },
  ],
  thresholds: { http_req_failed: ['rate<0.01'], http_req_duration: ['p(95)<500'] },
};

export default function () {
  const base = __ENV.BASE_URL || 'http://localhost:3000';
  const res = http.get(`${base}/api/v1/health`);
  check(res, { 'health is 200': (r) => r.status === 200 });
  sleep(1);
}
