# BullWave Capital — Django Backend

REST API for the **BullWave Invest** Flutter app. Uses **PostgreSQL** for persistence and **real external APIs** for market data, news, payments, and SMS.

## Real API integrations

| Feature | Provider | Env keys | Status |
|---------|----------|----------|--------|
| Stock quotes, charts, screener | **Kotak Neo Trade API** | `KOTAK_NEO_ACCESS_TOKEN` | Primary (real-time) |
| Quote fallback | **Finnhub / Yahoo Finance** | `FINNHUB_API_KEY` (optional) | Auto fallback |
| Market news | **RSS** (ET, Moneycontrol, BS) | none | Always on |
| Dividends | **Finnhub** `/stock/dividend2` | `FINNHUB_API_KEY` | Live sync |
| Bank IFSC validation | **Razorpay IFSC API** | none (free) | Always on |
| Wallet deposits | **Razorpay** | `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` | Production |
| SMS OTP | **MSG91 / Twilio** | `SMS_PROVIDER`, keys below | Production |
| AI assistant | **Ollama / Groq / Gemini / OpenAI** | `AI_PROVIDER`, provider keys | Ollama default |
| F&O option chain | Live spot + synthetic premiums | `ALPHA_VANTAGE_API_KEY` | Spot is real; premiums derived |
| Broker trading | Paper trading | — | Use Kite/Dhan keys when ready |

Check what's configured: `GET /health/`

## Setup
### 1. PostgreSQL

Create the database:

```sql
CREATE DATABASE bullwave_db;
CREATE USER postgres WITH PASSWORD 'postgres';
GRANT ALL PRIVILEGES ON DATABASE bullwave_db TO postgres;
```

### 2. Environment

```bash
copy .env.example .env
```

Edit `.env` (in the project root) with your PostgreSQL credentials and API keys.

### AI assistant — Ollama (default, local & free)

The app uses **Ollama** locally — no API key, no quota.

**Why was it slow?** The full `llama3.2` model (2 GB) runs on your CPU. The first message also loads the model into RAM (30–60 s).

**Speed fix (already configured):** use the smaller **`llama3.2:1b`** model (~1.3 GB, 3–5× faster):

```powershell
ollama pull llama3.2:1b
```

```env
AI_PROVIDER=ollama
OLLAMA_MODEL=llama3.2:1b
OLLAMA_KEEP_ALIVE=30m
AI_MAX_TOKENS=350
```

Django **pre-loads the model on startup** so the first app message is faster. Keep Ollama running in the background.

| Model | Speed | Quality |
|-------|-------|---------|
| `llama3.2:1b` | Fast (recommended) | Good for Q&A |
| `llama3.2` | Slow on CPU | Better answers |
| Groq cloud | Fastest (~1 s) | Free tier, needs API key |

**Need instant replies?** Switch to Groq (free, cloud, very fast):

```env
AI_PROVIDER=groq
GROQ_API_KEY=your-key-from-console.groq.com/keys
GROQ_MODEL=llama-3.1-8b-instant
```

Restart Django after any `.env` change.

### Real-time market data (Kotak Neo — recommended)

Live NSE/BSE prices use the **Kotak Neo Trade API v2** (same feed as the Kotak Neo trading app):

1. Open **Kotak Neo** app → **More** → **TradeAPI** → **API Dashboard**
2. Create an application (if needed) and copy your **Access Token**
3. Add to `backend/.env`:

```env
KOTAK_NEO_ACCESS_TOKEN=your-access-token-here
MARKET_DATA_PROVIDER=kotak_neo
KOTAK_NEO_BASE_URL=https://mis.kotaksecurities.com
```

4. Load Kotak instrument tokens (one-time, cached 24h):

```powershell
..\venv\Scripts\python.exe manage.py warm_kotak_scrip
```

5. Test live quotes:

```powershell
..\venv\Scripts\python.exe manage.py refresh_market
```

**Live endpoints:**
- `GET /api/v1/market/live/` — Nifty 50 + indices (refreshes every 15–20s in app)
- `GET /api/v1/stocks/{symbol}/quote/` — real-time quote
- `GET /api/v1/stocks/{symbol}/candles/` — OHLCV charts (Yahoo/Finnhub fallback)

Without `KOTAK_NEO_ACCESS_TOKEN`, the app falls back to Finnhub or Yahoo Finance.

### SMS OTP (production)

```env
SMS_PROVIDER=msg91
MSG91_AUTH_KEY=your-key
MSG91_TEMPLATE_ID=your-template-id
```

Or Twilio Messages: `SMS_PROVIDER=twilio` + `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM_NUMBER`.

Or Twilio Verify (recommended when you have a Verify Service): `SMS_PROVIDER=twilio` + `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_SERVICE_SID` (no from-number needed).

Dev default: `SMS_PROVIDER=console` prints OTP to terminal.

### Razorpay deposits (production)

```env
RAZORPAY_KEY_ID=rzp_test_...
RAZORPAY_KEY_SECRET=...
RAZORPAY_WEBHOOK_SECRET=...
```

| Step | Endpoint |
|------|----------|
| Create order | `POST /wallet/deposit/create-order/` `{ "amount": 1000 }` |
| After payment | `POST /wallet/deposit/verify/` `{ orderId, paymentId, signature }` |
| Webhook | `POST /wallet/webhook/razorpay/` |

When Razorpay is **not** configured, `POST /wallet/deposit/` works in DEBUG only (instant credit for testing).

### Scheduled jobs (cron)

```powershell
..\venv\Scripts\python.exe manage.py run_finance_jobs --all
```

Runs SIP installments, price alert checks, and monthly investment profit credits.

### 3. Install & migrate
```bash
# From project root
.\venv\Scripts\pip.exe install -r requirements.txt
cd backend
..\venv\Scripts\python.exe manage.py migrate
..\venv\Scripts\python.exe manage.py seed_data
..\venv\Scripts\python.exe manage.py createsuperuser
```

### 4. Run server

```bash
..\venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

- API base: `http://127.0.0.1:8000/api/v1/`           
- Admin: `http://127.0.0.1:8000/admin/`
- In DEBUG mode, OTP codes print to the terminal console.

### Flutter connection

Use `http://10.0.2.2:8000/api/v1/` on Android emulator, or your machine IP for a physical device.

---

## API map (aligned with Flutter screens)

### Authentication flow
| Screen | Method | Endpoint |
|--------|--------|----------|
| Login | POST | `/auth/send-otp/` |
| OTP | POST | `/auth/verify-otp/` → returns JWT + user |
| Token refresh | POST | `/auth/token/refresh/` `{ "refresh": "..." }` |
| Profile | GET/PATCH | `/users/me/` |
| Health / integrations | GET | `/health/` |

### Home & investments
| Screen | Method | Endpoint |
|--------|--------|----------|
| Home | GET | `/home/` |
| Investment details | GET | `/investment/plans/`, `/investment/plans/{id}/` |
| Invest action | POST | `/investment/subscribe/` |
| Portfolio tab | GET | `/portfolio/`, `/portfolio/overview/`, `/portfolio/holdings/`, `/portfolio/analytics/` |

### Wallet
| Screen | Method | Endpoint |
|--------|--------|----------|
| Wallet | GET | `/wallet/` |
| Deposit (dev) | POST | `/wallet/deposit/` |
| Deposit (Razorpay) | POST | `/wallet/deposit/create-order/`, `/wallet/deposit/verify/` |
| Withdraw | POST | `/wallet/withdraw/` |
| Wallet history | GET | `/wallet/transactions/` |

### KYC & bank
| Screen | Method | Endpoint |
|--------|--------|----------|
| KYC upload | GET/POST | `/kyc/documents/` |
| KYC submit | POST | `/kyc/submit/` |
| Bank verification | GET/POST | `/bank/`, `/bank/verify/` |

### Stocks (Markets tab)
| Screen | Method | Endpoint |
|--------|--------|----------|
| Stock search | GET | `/stocks/search?q=` |
| Stock detail | GET | `/stocks/{symbol}/quote/`, `/candles/` |
| Watchlist | GET/POST/DELETE | `/watchlist/` |
| News | GET | `/news/` (live RSS from ET, Moneycontrol, Business Standard) |
| Screener | GET | `/screener/` (live Nifty 50 via Finnhub) |
| Option chain | GET | `/options/{symbol}/chain/?expiry=` (live spot via Finnhub) |
| Price alerts | GET/POST | `/alerts/` |
| Alert toggle/delete | PATCH/DELETE | `/alerts/{id}/` |
| SIP tracker | GET/POST | `/sip/` |
| Cancel SIP | DELETE | `/sip/{id}/` |
| Paper trading | GET/POST | `/paper-trading/orders/` |
| Portfolio analytics | GET | `/portfolio/analytics/`, `/portfolio/holdings/` |
| Dividends | GET | `/dividends/?sync=true` (Finnhub sync) |
| AI assistant | POST | `/ai/stock-assistant/` |
| AI chat history | GET/DELETE | `/ai/history/` |
| AI suggestions | GET | `/ai/suggestions/` |

### Other
| Screen | Method | Endpoint |
|--------|--------|----------|
| Transactions | GET | `/transactions/` |
| Notifications | GET | `/notifications/` |
| Support | GET/POST | `/support/faqs/`, `/support/tickets/` |
| Referrals | GET/POST | `/referrals/`, `/referrals/apply/` |

---

## Auth header

```
Authorization: Bearer <access_token>
```

Refresh tokens: `POST /auth/token/refresh/` with `{ "refresh": "<token>" }`.
