# Dual Customer Types Rollout

1. Deploy app + admin updates.
2. Open **Maintenance** in admin and run **Users** backfill to set existing customers to `customerAccountType: cod`.
3. Open **Rate Settings** and confirm COD/contract default rates, then save.
4. Convert warehouse accounts in **Customers > detail > Account Type**.
5. Set per-customer contract fixed rates for warehouse accounts.
6. Use **Finance > Contract Billing** to mark 30-day invoice periods.

## Runtime fallback

Users without `customerAccountType` are treated as COD in the customer app.
