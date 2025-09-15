# DevHub Canary Call Flow

This document shows how the infrastructure handles requests from two clients:
- **Client A**: Regular user (gets stable version)
- **Client B**: Canary user (gets canary version via `?canary=true`)

## Infrastructure Components

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Istio Gateway │    │ Istio VirtualSvc │    │  ArgoRollouts   │
│  (ingress-gw)   │◄──►│   (devhub-vs)    │◄──►│   Controller    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌──────────────────┐
│ Frontend Pods   │    │  Backend Pods    │
│ ┌─────────────┐ │    │ ┌──────────────┐ │
│ │   Stable    │ │    │ │    Stable    │ │
│ │ (Weight 80%)│ │    │ │ (Weight 80%) │ │
│ └─────────────┘ │    │ └──────────────┘ │
│ ┌─────────────┐ │    │ ┌──────────────┐ │
│ │   Canary    │ │    │ │    Canary    │ │
│ │ (Weight 20%)│ │    │ │ (Weight 20%) │ │
│ └─────────────┘ │    │ └──────────────┘ │
└─────────────────┘    └──────────────────┘
```

## Scenario: Two Concurrent Users

### Client A (Regular User)
**Request**: `GET http://devhub.dev.localhost/`

### Client B (Canary User)
**Request**: `GET http://devhub.dev.localhost/?canary=true`

---

## Call Flow Breakdown

### 1. Initial Frontend Requests

#### Client A Flow (Regular):
```
Client A → Istio Gateway → VirtualService → Frontend Route
         ↓
    Weight-based routing (80% stable, 20% canary)
         ↓
    Gets: Frontend Stable Pod
```

#### Client B Flow (Canary):
```
Client B → Istio Gateway → VirtualService → Frontend Route
         ↓
    Weight-based routing (80% stable, 20% canary)
         ↓
    Gets: Frontend Canary Pod (or Stable - depends on traffic %)
```

### 2. Frontend Processing

#### Client A (Stable Frontend):
```javascript
// In stable frontend pod
window.CANARY_ENABLED = true; // Set via config
isCanaryDeployment() → false  // No ?canary=true param
// No canary headers added to API calls
```

#### Client B (Canary or Stable with canary param):
```javascript
// In frontend pod (canary or stable)
window.CANARY_ENABLED = true; // Set via config
isCanaryDeployment() → true   // ?canary=true param detected
// Adds x-canary-version: canary to all API calls
// Shows visual canary indicators
```

### 3. Backend API Requests

When users submit orders via the form:

#### Client A Backend Flow:
```
Browser → POST http://devhub.dev.localhost/api/orders
Headers: { "Content-Type": "application/json" }
         ↓
Istio Gateway → VirtualService devhub-vs
         ↓
Istio VirtualService Processing:
1. Check backend-api-canary route: NO x-canary-version header → SKIP
2. Check backend-api route: Match /api prefix → ROUTE
         ↓
Weight-based routing: 80% stable, 20% canary
         ↓
Result: Backend Stable Pod (most likely)
```

#### Client B Backend Flow:
```
Browser → POST http://devhub.dev.localhost/api/orders
Headers: {
  "Content-Type": "application/json",
  "x-canary-version": "canary"  ← Added by frontend JavaScript
}
         ↓
Istio Gateway → VirtualService devhub-vs
         ↓
Istio VirtualService Processing:
1. Check backend-api-canary route: HAS x-canary-version: canary → MATCH!
         ↓
Direct routing: 100% to backend-canary service
         ↓
Result: Backend Canary Pod (guaranteed)
```

---

## Complete Request Flows

### Client A (Regular User) - Order Submission

```
1. GET http://devhub.dev.localhost/
   └─► Istio Gateway
       └─► VirtualService devhub-vs
           └─► frontend-route (weight: 80% stable, 20% canary)
               └─► Frontend Stable Pod
                   └─► Serves index.html with CANARY_ENABLED=true
                       └─► isCanaryDeployment() = false

2. POST http://devhub.dev.localhost/api/orders
   Headers: { "Content-Type": "application/json" }
   └─► Istio Gateway
       └─► VirtualService devhub-vs
           ├─► backend-api-canary: NO x-canary-version header → SKIP
           └─► backend-api: Match /api → Route with weights
               └─► 80% chance: Backend Stable Pod
               └─► 20% chance: Backend Canary Pod

3. GET http://devhub.dev.localhost/api/orders
   Headers: { }
   └─► Same backend routing as step 2
```

### Client B (Canary User) - Order Submission

```
1. GET http://devhub.dev.localhost/?canary=true
   └─► Istio Gateway
       └─► VirtualService devhub-vs
           └─► frontend-route (weight: 80% stable, 20% canary)
               └─► Frontend Pod (could be stable or canary)
                   └─► Serves index.html with CANARY_ENABLED=true
                       └─► isCanaryDeployment() = true (detects ?canary=true)
                           └─► Shows orange canary indicators

2. POST http://devhub.dev.localhost/api/orders
   Headers: {
     "Content-Type": "application/json",
     "x-canary-version": "canary"
   }
   └─► Istio Gateway
       └─► VirtualService devhub-vs
           └─► backend-api-canary: HAS x-canary-version: canary → MATCH!
               └─► 100%: Backend Canary Pod (guaranteed)

3. GET http://devhub.dev.localhost/api/orders
   Headers: { "x-canary-version": "canary" }
   └─► Same as step 2 → Backend Canary Pod (guaranteed)
```

---

## Key Infrastructure Behaviors

### Network Flow Reality
**IMPORTANT**: All frontend-to-backend API calls go through the external Istio Gateway/VirtualService, NOT internal service mesh routing. This is because:
- Frontend JavaScript runs in the browser
- Browser makes HTTP calls to `http://devhub.dev.localhost/api/*`
- These calls go through the same Istio ingress path as initial page loads

### ArgoRollouts Traffic Management
- **Frontend**: Manages weights between stable/canary services for browser → frontend routing
- **Backend**: Manages weights between stable/canary services for browser → backend API routing
- **Progressive**: Weights change automatically: 0% → 20% → 50% → 100%

### Istio Routing Logic
1. **Single Entry Point**: All traffic (frontend pages + API calls) goes through external VirtualService
2. **Priority Order**: More specific routes (with headers) matched first
3. **Header Override**: `x-canary-version: canary` bypasses weight-based routing for API calls
4. **Fallback**: Requests without canary header use ArgoRollouts weights

### Client Behavior Coordination
- **Canary Users**: Frontend detects canary mode → adds headers → backend routes to canary (consistent experience)
- **Regular Users**: Subject to ArgoRollouts traffic percentages for both frontend and backend
- **Visual Feedback**: Canary users see clear indicators

### Traffic Distribution Example

During a 20% canary rollout:

**Frontend Traffic**:
- 80% → Stable Frontend Pods
- 20% → Canary Frontend Pods

**Backend Traffic**:
- **From Regular Users**: 80% → Stable Backend, 20% → Canary Backend
- **From Canary Users**: 100% → Canary Backend (header override)

This ensures canary users get a consistent full-stack canary experience while regular users gradually get exposed to the canary version.