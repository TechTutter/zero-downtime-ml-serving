// Constant arrival rate against /predict, used during canary rollouts.
// MAX_ERROR_RATE=0 means a single failed request fails the run.
import http from 'k6/http';
import { check } from 'k6';

const maxErrorRate = Number(__ENV.MAX_ERROR_RATE || 0);

export const options = {
  scenarios: {
    steady: {
      executor: 'constant-arrival-rate',
      rate: Number(__ENV.RATE || 20),
      timeUnit: '1s',
      duration: __ENV.DURATION || '1m',
      preAllocatedVUs: 20,
      maxVUs: 200,
    },
  },
  thresholds: {
    http_req_failed: [maxErrorRate === 0 ? 'rate==0' : `rate<${maxErrorRate}`],
    http_req_duration: ['p(99)<1000'],
  },
};

const body = JSON.stringify({ instances: [[5.1, 3.5, 1.4, 0.2]] });
const params = { headers: { 'Content-Type': 'application/json' }, tags: { name: 'predict' } };

export default function () {
  const res = http.post(`${__ENV.BASE_URL}/predict`, body, params);
  check(res, { 'status 200': (r) => r.status === 200 });
}
