import pandas as pd

# 1. Load the CSV file
df = pd.read_csv("orders_sample.csv")

# 2. Remove exact duplicate rows (e.g. order 1007 is repeated twice, identically)
df = df.drop_duplicates()

# 3. Remove rows where quantity or unit_price is missing (can't compute revenue without them)
df = df.dropna(subset=["quantity", "unit_price"])

# 4. Create line_revenue = quantity * unit_price
df["line_revenue"] = df["quantity"] * df["unit_price"]

# 5a. Total revenue by day
revenue_by_day = df.groupby("order_date")["line_revenue"].sum().round(2)

# 5b. Total number of orders per customer
# (an order can have multiple product rows, so count distinct order_id, not rows)
orders_per_customer = df.groupby("customer_id")["order_id"].nunique()

# 5c. Payment success rate (paid orders / total orders)
# payment_status is an order-level attribute, so dedupe to one row per order first
orders = df.drop_duplicates(subset="order_id")
payment_success_rate = (orders["payment_status"] == "paid").mean()

# 6. Print the final results
print("=== Total revenue by day ===")
print(revenue_by_day.to_string())

print("\n=== Total orders per customer ===")
print(orders_per_customer.to_string())

print(f"\n=== Payment success rate ===")
print(f"{payment_success_rate:.1%} ({(orders['payment_status'] == 'paid').sum()} of {len(orders)} orders paid)")
