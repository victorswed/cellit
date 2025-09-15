# DevHub

A simple developer portal: submit a mocked dev environment order and store it in MongoDB. No authentication.

- frontend: Static HTML/CSS/JS form
- backend: FastAPI API
- db: Docs and helpers for MongoDB

## Canary Deployment

Both frontend and backend support canary deployments using ArgoRollouts and Istio traffic routing.

### How it works

1. **Frontend Canary**: ArgoRollouts manages frontend traffic splitting via Istio VirtualService
2. **Backend Canary**: When frontend detects it's running in canary mode, it adds `x-canary-version: canary` header to API calls
3. **Coordinated Routing**: Istio routes backend traffic based on the header, ensuring canary frontend → canary backend

### Testing Canary

To test canary functionality:

1. Enable canary mode by visiting: `http://devhub.dev.localhost?canary=true`
2. Set persistent canary: `localStorage.setItem('canary', 'true')`
3. Or set cookie: `document.cookie = 'canary=true'`

When in canary mode, you'll see:
- Orange "CANARY" indicator in top-right corner
- Orange border at top of page
- All API calls will include `x-canary-version` header

### Deployment Process

1. Update image tags in `values.yaml`
2. ArgoCD syncs and starts rollout
3. Traffic gradually shifts: 0% → 20% → 50% → 100%
4. Frontend and backend canary versions are coordinated via headers
