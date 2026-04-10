## Stripe Test Setup

Use Stripe test or sandbox keys in the root `.env` file:

```env
STRIPE_MODE=test
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

Do not commit real or test secrets to Git.

### Backend

Install Python packages:

```powershell
pip install -r requirements.txt
```

Start the rider backend so it serves `http://localhost:8003`.

### Webhook listener

From the repo root:

```powershell
.\stripe.exe listen --forward-to localhost:8003/api/stripe/webhook
```

Copy the printed `whsec_...` secret into `.env`, then restart the rider backend.

### Verify config

Check:

```text
GET /api/config/stripe
```

Expected response values:

- `configured: true`
- `mode: "test"`
- `test_mode_ready: true`

### Test payment flow

1. Start a ride and move it to `in_progress`.
2. In the rider app, tap `Complete ride & pay`.
3. Use the Stripe test card below.
4. Wait for webhook confirmation.
5. Refresh the rider dashboard and confirm the trip shows `Paid`.

### Test cards

Successful payment:

```text
4242 4242 4242 4242
```

Use any future expiry date, any CVC, and any ZIP/postal code.

Additional cards:

- Decline: `4000 0000 0000 0002`
- 3DS/auth flow: `4000 0025 0000 3155`

### Included app flow

- Rider sees fare estimate before matching.
- Driver can accept and start the ride.
- Rider completes the ride from the rider app.
- Rider pays immediately in Stripe Payment Sheet.
- Webhook updates payment status in the database.
