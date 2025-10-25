# Ticketmaster API Analysis Report
Generated: October 25, 2025 at 11:43 AM UTC

---

## 1. Current API Configuration

**API Endpoint:** `https://app.ticketmaster.com/discovery/v2`
**API Type:** Discovery API v2 (Free Tier)
**API Key:** Configured ✓
**Rate Limits:** 5000 calls/day, 5 requests/second
**Season:** 2025-26
**Seat Section:** 115

## 2. Test Results for Upcoming Games

### Game 1: Sacramento Kings

- **Date:** October 28, 2025
- **Game Number:** 2
- **Days Until Game:** 3 days

**Events Found:** 5

- `Thunder vs. Kings - POST GAME` (2025-10-28) - ID: `Za5ju3rKuqZBGm3hMx2PkFam4cgl8dz30`
- `Thunder vs. Kings - PASS` (2025-10-28) - ID: `Za5ju3rKuqZDe33oAQEqP7K5GH3OekS0YZ`
- `Thunder vs. Sacramento Kings - SUITE` (2025-10-28) - ID: `Za5ju3rKuqZDeEaBRD-Ntkj5sBqihrlnFl`
- `Thunder vs. Kings - POST GAME` (2025-10-28) - ID: `Za5ju3rKuqZDeTbrlGJ8q1D1Lugk_Asv0k`
- `Oklahoma City Thunder vs. Sacramento Kings` (2025-10-28) - ID: `vvG1YZbYMJpSM3`

**Matched Event:** ✓ `Oklahoma City Thunder vs. Sacramento Kings`
**Event ID:** `vvG1YZbYMJpSM3`
**Event URL:** https://ticketmaster.evyy.net/c/dugganroberts/264167/4272?u=https%3A%2F%2Fwww.ticketmaster.com%2Foklahoma-city-thunder-vs-sacramento-kings-oklahoma-city-oklahoma-10-28-2025%2Fevent%2F0C00630DE65B3DD2&utm_medium=affiliate
**Has Price Ranges:** ✗ No

### Game 2: Washington Wizards

- **Date:** October 30, 2025
- **Game Number:** 3
- **Days Until Game:** 5 days

**Events Found:** 5

- `Thunder vs. Wizards - POST GAME` (2025-10-30) - ID: `Za5ju3rKuqZBC8HswfzqGPBLhAEpVr7Ph`
- `Thunder vs. Wizards - POST GAME` (2025-10-30) - ID: `Za5ju3rKuqZDeCo446QmtvwzjZ0rXQdAMi`
- `Thunder vs. Washington Wizards - SUITE` (2025-10-30) - ID: `Za5ju3rKuqZDeZP16we_A2VQiECl16zvG1`
- `Thunder vs. Wizards - PASS` (2025-10-30) - ID: `Za5ju3rKuqZDv0sPSv8d-GGD7ofo751nFt`
- `Oklahoma City Thunder vs. Washington Wizards` (2025-10-30) - ID: `vvG1YZbYMJ9SMx`

**Matched Event:** ✓ `Oklahoma City Thunder vs. Washington Wizards`
**Event ID:** `vvG1YZbYMJ9SMx`
**Event URL:** https://ticketmaster.evyy.net/c/dugganroberts/264167/4272?u=https%3A%2F%2Fwww.ticketmaster.com%2Foklahoma-city-thunder-vs-washington-wizards-oklahoma-city-oklahoma-10-30-2025%2Fevent%2F0C00630DE65F3DE2&utm_medium=affiliate
**Has Price Ranges:** ✗ No

### Game 3: New Orleans Pelicans

- **Date:** November 02, 2025
- **Game Number:** 4
- **Days Until Game:** 8 days

**Events Found:** 5

- `Thunder vs. New Orleans Pelicans - SUITE` (2025-11-02) - ID: `Za5ju3rKuqZDdqBc9f7t-vz1YiHhF-ZCCS`
- `Thunder vs. Pelicans - PASS` (2025-11-02) - ID: `Za5ju3rKuqZDdsm9KSlPAAeFEWddzwitsI`
- `Thunder vs. Pelicans - POST GAME` (2025-11-02) - ID: `Za5ju3rKuqZDeqcammUStAxy4vg8nG6eIo`
- `Thunder vs. Pelicans - POST GAME` (2025-11-02) - ID: `Za5ju3rKuqZDvdXZM4ZscGuBgFonGdzOev`
- `Oklahoma City Thunder vs. New Orleans Pelicans` (2025-11-02) - ID: `vvG1YZbYMJbSzk`

**Matched Event:** ✓ `Oklahoma City Thunder vs. New Orleans Pelicans`
**Event ID:** `vvG1YZbYMJbSzk`
**Event URL:** https://ticketmaster.evyy.net/c/dugganroberts/264167/4272?u=https%3A%2F%2Fwww.ticketmaster.com%2Foklahoma-city-thunder-vs-new-orleans-oklahoma-city-oklahoma-11-02-2025%2Fevent%2F0C00630DE6633E06&utm_medium=affiliate
**Has Price Ranges:** ✗ No

---

## 3. Complete Event Data Structure

Sample event: **Oklahoma City Thunder vs. Sacramento Kings** (October 28, 2025)

### Available Top-Level Fields

```
_embedded, _links, accessibility, ageRestrictions, classifications, dates, id, images, info, locale, name, pleaseNote, products, promoter, promoters, sales, seatmap, test, ticketLimit, ticketing, type, url
```

### Field-by-Field Analysis

#### Event Identification
- **id:** `vvG1YZbYMJpSM3`
- **name:** `Oklahoma City Thunder vs. Sacramento Kings`
- **type:** `event`
- **url:** https://ticketmaster.evyy.net/c/dugganroberts/264167/4272?u=https%3A%2F%2Fwww.ticketmaster.com%2Foklahoma-city-thunder-vs-sacramento-kings-oklahoma-city-oklahoma-10-28-2025%2Fevent%2F0C00630DE65B3DD2&utm_medium=affiliate

#### Dates & Times
```json
{
  "start": {
    "localDate": "2025-10-28",
    "localTime": "19:00:00",
    "dateTime": "2025-10-29T00:00:00Z",
    "dateTBD": false,
    "dateTBA": false,
    "timeTBA": false,
    "noSpecificTime": false
  },
  "timezone": "America/Chicago",
  "status": {
    "code": "onsale"
  },
  "spanMultipleDays": false
}
```

#### Sales Information
```json
{
  "public": {
    "startDateTime": "2025-09-18T15:00:00Z",
    "startTBD": false,
    "startTBA": false,
    "endDateTime": "2025-10-29T01:00:00Z"
  },
  "presales": [
    {
      "startDateTime": "2025-09-18T14:00:00Z",
      "endDateTime": "2025-09-18T14:59:00Z",
      "name": "MidFirst Bank Cardholder Presale",
      "description": "Exclusive MidFirst Bank Cardholder Presale! Your password must be entered exactly as it was provided to be accepted. First come, first served. Quantities are limited."
    }
  ]
}
```

#### Ticketing
```json
{
  "safeTix": {
    "enabled": true
  },
  "allInclusivePricing": {
    "enabled": true
  }
}
```

#### Products (Upsells)
```json
[
  {
    "name": "Thunder Parking",
    "id": "vvG1YZbsG1JVUv",
    "url": "https://www.ticketmaster.com/thunder-parking-oklahoma-city-oklahoma-10-28-2025/event/0C0063130A9B4D81",
    "type": "Upsell",
    "classifications": [
      {
        "primary": true,
        "segment": {
          "id": "KZFzniwnSyZfZ7v7n1",
          "name": "Miscellaneous"
        },
        "genre": {
          "id": "KnvZfZ7v7ll",
          "name": "Undefined"
        },
        "subGenre": {
          "id": "KZazBEonSMnZfZ7vAv1",
          "name": "Undefined"
        },
        "type": {
          "id": "KZAyXgnZfZ7vAva",
          "name": "Parking"
        },
        "subType": {
          "id": "KZFzBErXgnZfZ7vAFe",
          "name": "Regular"
        },
        "family": false
      }
    ]
  }
]
```

#### Seat Map
- **Static URL:** `https://mapsapi.tmol.io/maps/geometry/3/event/0C00630DE65B3DD2/staticImage?type=png&systemId=HOST`

#### Price Ranges
```json
null (NOT AVAILABLE)
```

---

## 4. Data Availability Analysis

### ✅ What We ARE Getting

1. **Event Matching**: Successfully matching Thunder games to Ticketmaster events
2. **Event Details**: Complete event metadata (name, date, venue, URL)
3. **Sales Information**: Public sale dates, presale details
4. **Ticketing Info**: SafeTix enabled, all-inclusive pricing status
5. **Seat Map**: Static image URLs for venue layout
6. **Products**: Related upsells (parking, suites, etc.)
7. **Event Classification**: Sport/genre/type taxonomy
8. **Images**: Multiple aspect ratios for event display

### ❌ What We're NOT Getting

1. **Price Ranges**: The `priceRanges` field is **null** for all tested events
2. **Section-Specific Pricing**: No way to get Section 115 specific prices
3. **Resale Marketplace Prices**: No distinction between primary and resale
4. **Current Inventory**: No real-time availability counts
5. **Fee Information**: No fee breakdowns

### 🔍 Root Cause

The **Ticketmaster Discovery API v2** (free tier) does **not reliably provide pricing data** in the `priceRanges` field. According to Ticketmaster's documentation:

- The `priceRanges` field is **optional** in event responses
- Pricing data availability varies by event and market
- No guarantee that pricing will be included

---

## 5. Why This Matters for Your Use Case

### Your Requirements
- Track **resale marketplace prices** for Section 115
- Compare market prices to your cost per ticket ($XXX)
- Make informed selling decisions
- Daily automated price updates

### Current Limitation
The Discovery API cannot fulfill these requirements because:
1. No pricing data is returned (even for games 3 days away)
2. No section-specific pricing capability
3. Event-level data only (not seat-level)

---

## 6. Alternative Solutions

### Option 1: Ticketmaster Inventory Status API ⭐ RECOMMENDED
- **Pros**: 
  - Official Ticketmaster API
  - Provides min/max pricing
  - Includes resale inventory
  - Hourly updates
- **Cons**:
  - Requires authorization (email devportalinquiry@ticketmaster.com)
  - May not be approved for personal use
  - Event-level pricing only (not section-specific)
  - Pricing excludes fees

### Option 2: SeatGeek Platform API
- **Pros**:
  - Section-specific pricing available
  - Comprehensive resale marketplace data
  - Well-documented API
- **Cons**:
  - Requires separate account/API key
  - Pay-per-use pricing model
  - Learning new API

### Option 3: Manual Price Tracking
- **Pros**:
  - Complete control
  - Most accurate for your specific seats
  - No API limitations
- **Cons**:
  - Requires manual effort
  - Not automated
  - Time-consuming

### Option 4: Web Scraping
- **Pros**:
  - Can get exact section pricing
  - Free
- **Cons**:
  - May violate Terms of Service
  - Fragile (breaks when site changes)
  - Legal/ethical concerns

---

## 7. Recommended Next Steps

### Short Term
1. **Contact Ticketmaster** about Inventory Status API access
   - Email: devportalinquiry@ticketmaster.com
   - Explain your use case (personal season ticket tracking)
   - Request access to Inventory Status API

2. **Manual Tracking** in the meantime
   - Add a manual price entry field to game records
   - Check Ticketmaster weekly for Section 115 prices
   - Build historical price database

### Long Term
1. **Evaluate SeatGeek API** as primary solution
   - Sign up for API access
   - Test their section-specific pricing
   - Compare pricing models

2. **Build Hybrid System**
   - Use Ticketmaster for event discovery/matching
   - Use SeatGeek (or alternative) for pricing
   - Best of both worlds

---

## 8. Sample API Calls (For Reference)

### Find Events
```bash
curl "https://app.ticketmaster.com/discovery/v2/events.json?apikey=YOUR_KEY&keyword=Oklahoma%20City%20Thunder&city=Oklahoma%20City&stateCode=OK&startDateTime=2025-10-27T00:00:00Z&endDateTime=2025-10-29T23:59:59Z"
```

### Get Event Details
```bash
curl "https://app.ticketmaster.com/discovery/v2/events/vvG1YZbYMJpSM3.json?apikey=YOUR_KEY"
```

---

## 9. Conclusion

**Current Status**: The Ticketmaster Discovery API integration is **technically working** but **cannot provide the pricing data** needed for your use case.

**Reality Check**: Even games happening in 3 days (October 28, 2025) return **null** for `priceRanges`.

**Recommendation**: Pursue **Ticketmaster Inventory Status API** access while implementing **manual price tracking** as a temporary solution.

---

**Report Generated**: October 25, 2025
**Thunder Tickets App**: Season 2025-26
