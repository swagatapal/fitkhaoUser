# Subscription API — Full Flow

Base URL: `https://<host>/api`  
Auth header (সব protected route-এ): `Authorization: Bearer <token>`

---

## Flow Overview

```
1. Plan দেখো          →  GET  /adm/subscription-plan
2a. Wallet দিয়ে কেনো  →  POST /subscription/create
2b. Razorpay দিয়ে কেনো
     ├─ Order তৈরি    →  POST /razorpay/create-order          (purpose: subscription)
     ├─ Frontend Checkout  (Razorpay SDK)
     └─ Verify + Activate → POST /razorpay/verify-payment     (purpose: subscription)
3. Subscription চেক   →  GET  /user/profile  |  GET /wallet/balance
4. Upgrade preview    →  GET  /subscription/upgrade/preview?newPlanCode=XXX
5. Upgrade করো        →  POST /subscription/upgrade
6. Cancel preview     →  GET  /subscriptions/:id/cancel-preview
7. Cancel করো         →  POST /subscriptions/:id/cancel
8. Invoice            →  GET  /subscriptions/:id/invoice
9. Event history      →  GET  /subscriptions/:id/history
```

---

## Pricing Formula

| Field              | Formula                                                              |
|--------------------|----------------------------------------------------------------------|
| `cancelAnytimeFee` | `cancelAnytimeSelected ? 21 : 0`                                     |
| `subtotal`         | `planAmount + cancelAnytimeFee`                                      |
| `gstAmount`        | `subtotal × 0.10`                                                    |
| `totalAmount`      | `subtotal + gstAmount`                                               |
| `pricePerMeal`     | `(planAmount - consultationFee) / (durationInDays × mealsPerDay)`   |

**Refund formula (cancellation):**
```
refund = max(0, planAmount - consultationFee - pricePerMeal × mealsConsumed)
```

---

## 1. Get Subscription Plans

```
GET /api/adm/subscription-plan
Auth: না লাগে
Query: ?isActive=true   (optional)
```

**Response `200`:**
```json
{
  "success": true,
  "message": "Subscription plans retrieved successfully",
  "data": {
    "plans": [
      {
        "_id": "664abc123...",
        "planCode": "WEEKLY",
        "name": "Weekly Plan",
        "price": 499,
        "durationInDays": 7,
        "consultationFee": 50,
        "isActive": true,
        "features": {
          "mealCountPerDay": 2,
          "walletEnabled": true,
          "outletFoodDiscount": true,
          "outletFoodDiscountPercent": 10,
          "cancelCoupon": true,
          "cancelCouponAmount": 30
        },
        "rules": {
          "walletEnabled": true,
          "canUpgrade": true
        }
      }
    ],
    "count": 1
  }
}
```

---

## 2a. Create Subscription — Wallet Payment

```
POST /api/subscription/create
Auth: Required
```

**Request Body:**
```json
{
  "planCode": "WEEKLY",
  "paymentMethod": "wallet",
  "cancelAnytimeSelected": true
}
```

| Field                   | Type      | Required | Notes                            |
|-------------------------|-----------|----------|----------------------------------|
| `planCode`              | `string`  | ✅       | Active plan-এর code              |
| `paymentMethod`         | `string`  | ✅       | `"wallet"` (online হলে Razorpay) |
| `cancelAnytimeSelected` | `boolean` | ❌       | default `false`, fee ₹21 extra   |

**Response `201`:**
```json
{
  "success": true,
  "message": "Subscription created successfully",
  "data": {
    "subscription": {
      "id": "664sub...",
      "planCode": "WEEKLY",
      "planName": "Weekly Plan",
      "planAmount": 499,
      "cancelAnytimeSelected": true,
      "cancelAnytimeFee": 21,
      "subtotal": 520,
      "gstRate": 0.10,
      "gstAmount": 52,
      "totalAmount": 572,
      "mealsPerDay": 2,
      "consultationFee": 50,
      "pricePerMeal": 32.07,
      "outletFoodDiscountPercent": 10,
      "paymentMethod": "wallet",
      "paymentStatus": "paid",
      "status": "active",
      "startDate": "2026-06-17T10:30:00.000Z",
      "endDate": "2026-06-24T10:30:00.000Z",
      "remainingDays": 7,
      "features": { "mealCountPerDay": 2, "walletEnabled": true, "..." : "..." }
    },
    "wallet": {
      "couponBalance": 428,
      "previousBalance": 1000,
      "addedAmount": 499,
      "deductedAmount": 572
    }
  }
}
```

**Error — Insufficient balance `400`:**
```json
{
  "success": false,
  "message": "Insufficient wallet balance",
  "data": {
    "requiredAmount": 572,
    "availableBalance": 300
  }
}
```

**Error — Already active subscription `422`:**
```json
{
  "success": false,
  "message": "You already have an active subscription. Please wait for it to expire or cancel it first.",
  "data": {
    "existingSubscription": {
      "id": "...",
      "planCode": "WEEKLY",
      "planName": "Weekly Plan",
      "endDate": "2026-06-24T10:30:00.000Z"
    }
  }
}
```

---

## 2b. Create Subscription — Razorpay Payment (2 steps)

### Step 1 — Order তৈরি

```
POST /api/razorpay/create-order
Auth: Required
```

**Request Body:**
```json
{
  "purpose": "subscription",
  "planCode": "WEEKLY",
  "cancelAnytimeSelected": true,
  "amount": 0
}
```

> `amount` এখানে ignore হয়। Server-side pricing calculate হয়।

**Response `200`:**
```json
{
  "success": true,
  "message": "Razorpay order created",
  "data": {
    "razorpayOrderId": "order_XXXXXXXXXX",
    "amount": 572,
    "amountInPaise": 57200,
    "currency": "INR",
    "keyId": "rzp_live_XXXXXXX",
    "purpose": "subscription",
    "planCode": "WEEKLY",
    "pricing": {
      "planAmount": 499,
      "cancelAnytimeSelected": true,
      "cancelAnytimeFee": 21,
      "subtotal": 520,
      "gstRate": 0.10,
      "gstAmount": 52,
      "totalAmount": 572
    }
  }
}
```

### Step 2 — Frontend Checkout (Razorpay SDK)

```javascript
const options = {
  key: data.keyId,
  amount: data.amountInPaise,
  currency: data.currency,
  order_id: data.razorpayOrderId,
  handler: function (response) {
    // Step 3-এ call করো
    verifyPayment(response);
  }
};
new Razorpay(options).open();
```

### Step 3 — Verify & Activate

```
POST /api/razorpay/verify-payment
Auth: Required
```

**Request Body:**
```json
{
  "purpose": "subscription",
  "planCode": "WEEKLY",
  "razorpayOrderId": "order_XXXXXXXXXX",
  "razorpayPaymentId": "pay_YYYYYYYYYY",
  "razorpaySignature": "hmac_signature_here"
}
```

**Response `201`:**
```json
{
  "success": true,
  "message": "Subscription activated successfully",
  "data": {
    "subscription": {
      "id": "664sub...",
      "planCode": "WEEKLY",
      "planName": "Weekly Plan",
      "planAmount": 499,
      "cancelAnytimeSelected": true,
      "cancelAnytimeFee": 21,
      "subtotal": 520,
      "gstRate": 0.10,
      "gstAmount": 52,
      "totalAmount": 572,
      "mealsPerDay": 2,
      "consultationFee": 50,
      "pricePerMeal": 32.07,
      "outletFoodDiscountPercent": 10,
      "paymentMethod": "online",
      "paymentStatus": "paid",
      "status": "active",
      "startDate": "2026-06-17T10:30:00.000Z",
      "endDate": "2026-06-24T10:30:00.000Z",
      "remainingDays": 7
    },
    "wallet": {
      "couponBalance": 499
    },
    "payment": {
      "razorpayOrderId": "order_XXXXXXXXXX",
      "razorpayPaymentId": "pay_YYYYYYYYYY"
    }
  }
}
```

---

## 3. Active Subscription দেখো

### Profile এ

```
GET /api/user/profile
Auth: Required
```

Response-এর `data.user.activeSubscription` এ subscription payload আসে (same structure as above, `features` ছাড়া)।

### Wallet Balance এ

```
GET /api/wallet/balance
Auth: Required
```

**Response `200`:**
```json
{
  "success": true,
  "message": "Wallet balance retrieved successfully",
  "data": {
    "wallet": {
      "couponBalance": 427,
      "frozenBalance": 0,
      "availableBalance": 427,
      "canUseBalance": true,
      "totalEarned": 499,
      "totalSpent": 72,
      "lastTransactionAt": "2026-06-17T10:30:00.000Z"
    },
    "subscription": {
      "id": "664sub...",
      "planCode": "WEEKLY",
      "planName": "Weekly Plan",
      "planAmount": 499,
      "cancelAnytimeSelected": true,
      "cancelAnytimeFee": 21,
      "subtotal": 520,
      "gstRate": 0.10,
      "gstAmount": 52,
      "totalAmount": 572,
      "mealsPerDay": 2,
      "consultationFee": 50,
      "pricePerMeal": 32.07,
      "outletFoodDiscountPercent": 10,
      "paymentMethod": "wallet",
      "paymentStatus": "paid",
      "status": "active",
      "startDate": "2026-06-17T10:30:00.000Z",
      "endDate": "2026-06-24T10:30:00.000Z",
      "remainingDays": 7
    },
    "message": "Your balance is available for use"
  }
}
```

---

## 4. Upgrade Preview

```
GET /api/subscription/upgrade/preview?newPlanCode=MONTHLY
Auth: Required
```

**Response `200`:**
```json
{
  "success": true,
  "message": "Upgrade preview calculated",
  "data": {
    "currentPlan": {
      "planCode": "WEEKLY",
      "name": "Weekly Plan",
      "amount": 499,
      "endDate": "2026-06-24T10:30:00.000Z",
      "remainingDays": 7
    },
    "newPlan": {
      "planCode": "MONTHLY",
      "name": "Monthly Plan",
      "price": 1499,
      "durationInDays": 30,
      "consultationFee": 100,
      "mealsPerDay": 2,
      "outletFoodDiscountPercent": 15,
      "features": { "..." : "..." }
    },
    "breakdown": {
      "priceDiff": 1000,
      "ordersConsumed": 145.50,
      "orderCount": 5,
      "amountDue": 854.50,
      "walletAvailable": 427,
      "amountToPayWithoutWallet": 854.50,
      "amountToPayWithWallet": 427.50,
      "walletDeductionIfUsed": 427
    },
    "newSubscriptionDuration": {
      "startDate": "2026-06-17T11:00:00.000Z",
      "endDate": "2026-07-17T11:00:00.000Z",
      "durationInDays": 30
    }
  }
}
```

---

## 5. Upgrade Subscription

```
POST /api/subscription/upgrade
Auth: Required
```

**Request Body:**
```json
{
  "newPlanCode": "MONTHLY",
  "useWallet": true,
  "paymentId": "pay_YYYYYYYYYY"
}
```

| Field        | Type      | Required | Notes                                           |
|--------------|-----------|----------|-------------------------------------------------|
| `newPlanCode`| `string`  | ✅       | নতুন plan-এর code (price > current plan price)  |
| `useWallet`  | `boolean` | ❌       | `true` হলে wallet থেকে partial pay              |
| `paymentId`  | `string`  | ❌       | Razorpay pay_xxx (online part থাকলে)             |

**Response `200`:**
```json
{
  "success": true,
  "message": "Subscription upgraded successfully",
  "data": {
    "upgrade": {
      "fromPlan": { "planCode": "WEEKLY", "name": "Weekly Plan" },
      "toPlan":   { "planCode": "MONTHLY", "name": "Monthly Plan" },
      "ordersConsumed": 145.50,
      "priceDiff": 1000,
      "amountDue": 854.50,
      "walletUsed": 427,
      "amountPaidOnline": 427.50,
      "paymentId": "pay_YYYYYYYYYY"
    },
    "subscription": {
      "id": "664newsub...",
      "planCode": "MONTHLY",
      "planName": "Monthly Plan",
      "planAmount": 1499,
      "cancelAnytimeSelected": false,
      "cancelAnytimeFee": 0,
      "subtotal": 1499,
      "gstRate": 0.10,
      "gstAmount": 149.90,
      "totalAmount": 1648.90,
      "mealsPerDay": 2,
      "consultationFee": 100,
      "pricePerMeal": 22.42,
      "outletFoodDiscountPercent": 15,
      "paymentMethod": "online",
      "paymentStatus": "paid",
      "status": "active",
      "startDate": "2026-06-17T11:00:00.000Z",
      "endDate": "2026-07-17T11:00:00.000Z",
      "remainingDays": 30,
      "features": { "..." : "..." }
    },
    "wallet": {
      "couponBalance": 2072.50,
      "walletCredited": 1000,
      "walletDebited": 427
    }
  }
}
```

---

## 6. Cancel Preview

> `cancelAnytimeSelected: true` না থাকলে cancel করা যাবে না।

```
GET /api/subscriptions/:subscriptionId/cancel-preview
Auth: Required
```

**Response `200`:**
```json
{
  "success": true,
  "message": "Subscription cancellation preview",
  "data": {
    "planAmount": 499,
    "consultationFee": 50,
    "mealsPerDay": 2,
    "totalMeals": 14,
    "mealsConsumed": 4,
    "pricePerMeal": 32.07,
    "refundAmount": 320.72,
    "availableRefundMethods": ["wallet", "razorpay"],
    "subscription": {
      "id": "664sub...",
      "planCode": "WEEKLY",
      "planName": "Weekly Plan",
      "status": "active",
      "startDate": "2026-06-17T10:30:00.000Z",
      "endDate": "2026-06-24T10:30:00.000Z"
    }
  }
}
```

> `availableRefundMethods`: wallet সবসময় থাকে। Razorpay শুধু থাকে যদি plan টি online payment-এ কেনা হয়।

---

## 7. Cancel Subscription

```
POST /api/subscriptions/:subscriptionId/cancel
Auth: Required
```

**Request Body:**
```json
{
  "refundMethod": "wallet",
  "reason": "No longer needed"
}
```

| Field          | Type     | Required | Notes                         |
|----------------|----------|----------|-------------------------------|
| `refundMethod` | `string` | ✅       | `"wallet"` বা `"razorpay"`    |
| `reason`       | `string` | ❌       | cancellation reason           |

**Response `200`:**
```json
{
  "success": true,
  "message": "Subscription cancelled successfully",
  "data": {
    "refundAmount": 320.72,
    "refundMethod": "wallet",
    "refundStatus": "processed",
    "subscription": {
      "id": "664sub...",
      "planCode": "WEEKLY",
      "planName": "Weekly Plan",
      "status": "cancelled",
      "cancelledAt": "2026-06-20T08:00:00.000Z"
    }
  }
}
```

> `refundStatus`: `"processed"` | `"failed"` | `"pending"`  
> Razorpay refund fail করলেও cancellation committed থাকে, `refundStatus: "failed"` হয়।

**Meal Order Cancel হলে Auto-Coupon:**  
যদি plan-এ `cancelCoupon: true` এবং `cancelCouponAmount > 0` থাকে, তাহলে subscription meal cancel করলে user-specific flat discount coupon auto-generate হয় (30 দিনের validity, ঐ user-এর জন্য only)।

---

## 8. Subscription Invoice

```
GET /api/subscriptions/:subscriptionId/invoice
Auth: Required
```

**Response `200`:**
```json
{
  "success": true,
  "message": "Invoice generated successfully",
  "data": {
    "invoiceUrl": "https://<storage>.blob.core.windows.net/invoices/sub-664abc-1718600000000.pdf",
    "planCode": "WEEKLY",
    "cached": false
  }
}
```

> PDF-টি Azure Blob Storage-এ cache হয়। পরেরবার same URL return করে (cache: true)।  
> Invoice-এ থাকে: plan details, dates, payment info, pricing breakdown (plan amount + cancel anytime fee + GST = total).

---

## 9. Subscription Event History

```
GET /api/subscriptions/:subscriptionId/history
Auth: Required
```

**Response `200`:**
```json
{
  "success": true,
  "message": "Subscription history retrieved",
  "data": {
    "logs": [
      {
        "_id": "664log...",
        "userId": "664user...",
        "subscriptionId": "664sub...",
        "event": "refund_processed",
        "details": { "refundAmount": 320.72, "method": "wallet" },
        "createdAt": "2026-06-20T08:01:00.000Z"
      },
      {
        "_id": "664log2...",
        "event": "subscription_cancelled",
        "details": { "reason": "No longer needed", "mealsConsumed": 4, "refundAmount": 320.72, "refundMethod": "wallet" },
        "createdAt": "2026-06-20T08:00:00.000Z"
      },
      {
        "_id": "664log3...",
        "event": "subscription_created",
        "details": { "planCode": "WEEKLY", "planAmount": 499, "totalAmount": 572, "paymentMethod": "wallet", "mealsPerDay": 2, "pricePerMeal": 32.07 },
        "createdAt": "2026-06-17T10:30:00.000Z"
      }
    ]
  }
}
```

**Possible `event` values:**

| Event                    | কখন হয়                                              |
|--------------------------|------------------------------------------------------|
| `subscription_created`   | নতুন subscription activate                           |
| `subscription_cancelled` | user cancel করলে                                     |
| `subscription_expired`   | timer job expire করলে                               |
| `subscription_upgraded`  | plan upgrade হলে *(future)*                          |
| `refund_initiated`       | refund process শুরু হলে                              |
| `refund_processed`       | refund সফল                                           |
| `refund_failed`          | Razorpay refund fail করলে                            |

---

## Subscription Object — Full Structure

সব response-এ subscription এই common structure follow করে (`buildSubscriptionPayload`):

```json
{
  "id": "664sub...",
  "planCode": "WEEKLY",
  "planName": "Weekly Plan",
  "planAmount": 499,
  "cancelAnytimeSelected": true,
  "cancelAnytimeFee": 21,
  "subtotal": 520,
  "gstRate": 0.10,
  "gstAmount": 52,
  "totalAmount": 572,
  "mealsPerDay": 2,
  "consultationFee": 50,
  "pricePerMeal": 32.07,
  "outletFoodDiscountPercent": 10,
  "paymentMethod": "wallet | online",
  "paymentStatus": "paid",
  "status": "active | cancelled | expired",
  "startDate": "2026-06-17T10:30:00.000Z",
  "endDate": "2026-06-24T10:30:00.000Z",
  "remainingDays": 7,
  "features": { "..." }
}
```

> `features` শুধু create/upgrade response-এ আসে। Profile/wallet balance-এ আসে না।

---

## Error Codes

| HTTP | Message                                              | কারণ                                     |
|------|------------------------------------------------------|------------------------------------------|
| 400  | Insufficient wallet balance                          | Wallet-এ টাকা কম                        |
| 400  | Cancel anytime was not selected                      | Plan কেনার সময় cancel anytime নেওয়া হয়নি |
| 400  | Razorpay refund not available for wallet payments    | Wallet-এ কিনলে Razorpay refund নেই      |
| 403  | Payment verification failed: invalid signature       | Razorpay HMAC mismatch                   |
| 404  | Subscription plan not found or inactive              | ভুল planCode বা plan inactive            |
| 409  | Subscription already cancelled or not found          | Race condition — already cancelled       |
| 422  | You already have an active subscription              | একটাই active থাকতে পারবে               |
