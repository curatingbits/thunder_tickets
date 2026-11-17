# MADR TICKETS - NBA Season Ticket Tracker

A comprehensive web application for managing Oklahoma City Thunder season tickets, built with Ruby on Rails, Stimulus, SolidQueue, TailwindCSS, and SQLite.

## Features

### Core Functionality
- **Dashboard Analytics** - Real-time financial tracking with profit/loss calculations
- **Game Management** - Track all regular season and playoff games
- **Ticket Sales** - Record, edit, and remove individual ticket sales for each seat
- **Break-Even Analysis** - Know if you're on track to recover your season ticket investment
- **Financial Insights** - View revenue, costs, and profitability per game
- **Playoff Support** - Add playoff games as they're scheduled

### Authentication & Security
- **Invite-Only Access** - No public registration, admin-controlled user creation
- **Password Reset** - Emailed reset link (via Resend), valid for 2 hours and single-use
- **Session Management** - Secure login/logout with encrypted passwords

### Design
- **Tokyo Night Theme** - Beautiful dark theme inspired by Tokyo Night color palette
- **Fully Mobile-Responsive** - Optimized for phones, tablets, and desktops
  - Hamburger menu navigation for mobile devices
  - Touch-friendly buttons (44px minimum tap targets)
  - Responsive typography that scales appropriately
  - Stacked layouts on mobile, multi-column on larger screens
  - Optimized card grids for all screen sizes
- **Real-time Updates** - Turbo-powered for instant updates without page reloads

## Tech Stack

- **Ruby 4.0** and **Rails 8.1**
- **SQLite3** - Lightweight database
- **TailwindCSS 4** - Modern utility-first CSS
- **Stimulus** - Modest JavaScript framework
- **SolidQueue** - Background job processing
- **Turbo** - SPA-like page acceleration

## Getting Started

### Prerequisites
- Ruby 4.0.9 (the version in `.ruby-version`; `mise install` picks it up)
- SQLite 3
- No Node.js: JavaScript ships through importmap and Tailwind uses its
  standalone binary

### Installation

1. **Set up and start the app**
   ```bash
   bin/setup
   ```
   This installs gems, creates the database, loads the seeds, and starts the
   server at `http://localhost:3000`. Later, start it with `bin/dev`.

2. **Sign in** with the sample account: `admin@example.com` / `password`.

The seeds give a fresh database the 29 opposing teams, the real 2026-27 home
schedule from `db/schedules`, and some made-up sales and buyers. They only
fill an empty database: re-running them never changes or deletes anything, and
in production they add the teams only. To start over with sample data, run
`bin/setup --reset`.

## Usage

### On your phone
MADR Tickets installs like an app. On iPhone, open madrtickets.com in Safari,
tap Share, then **Add to Home Screen**. On Android, use Chrome's **Install app**.
Phones get a bottom tab bar (Home, Games, Buyers, More); desktop gets a sidebar.
Pick a Dark, Light or System theme under More (or at the bottom of the sidebar).

### Home
Home leads with what needs doing: games in the next 7 days that still have seats
to sell, most urgent first, with the price each seat needs to break even. Then
the next three games, then the season's profit, charts and recent sales.

### Dashboard
The main dashboard displays:
- Total season cost vs. revenue
- Current profit/loss
- Tickets sold percentage
- Break-even tracking indicator
- Upcoming games
- Recent sales
- Game status summary

### Managing Games
- View all games with filtering options (upcoming, past, sold, unsold)
- Click any game to view details and manage ticket sales
- Add playoff games as they're scheduled

### Pricing
The **Pricing** tab answers what our unsold seats are worth, what to list them
at, and whether our current asking prices are too high or low. Each upcoming
game shows the market value on Ticketmaster (the all-in price buyers see), a
recommended list price with its strategy (competitive / market / premium) and
the reasons, how our confirmed listing compares, a confidence score, and how
old the data is. Each game's page has the full breakdown, including every
listing read and why any were set aside.

Market data comes from the weekly Ticketmaster research (sections 101, 102 and
120, priced for pairs). When that can't run, paste a game's listings on its page
(**Add market data by hand**). Every scan is kept, so prices can be compared
over time. Recommendations are advisory: nothing here changes a Ticketmaster
listing. Thresholds and fee assumptions live in Settings; the seller fee is left
unknown until it's set there or measured from sales linked to listings.

Each game's market card charts its **price history** once it has two scans:
market value, the competitive-to-premium range, and our price when we had one
listed, with the numbers in a table underneath.

### Insights
**Insights** (from Pricing, or More) shows what moves the market near our seats:
- how value changes with days to the game;
- weekends against weeknights;
- each opponent against the typical game;
- how many listings each scan saw;
- what we listed sold seats at against the market at the time.

Each comparison is against the typical game in the same scan, and says how many
games and scans it rests on. These are asking prices, not sales. A listing that
disappears may have sold, been taken down or been repriced, so fewer listings
doesn't mean more sales.

### Weekly report
**Weekly report** (from Home, or More) rebuilds any week from stored history:
- the research that ran;
- games whose market moved 10% or more;
- sales;
- listing decisions;
- Venmo payments, with today's balance.

The current week also lists what needs attention and the games in the next two
weeks with seats to sell. Past weeks come out the same every time, because
scans, listing events, sales and payments aren't rewritten. The daily digest
email now opens with the top five attention items.

### Money
The **Money** tab answers which sold games have been paid out and what's still
owed. Mark pays Duggan half of each sale's payout over Venmo. Each sold game in a
tracked season (2026-27 on) shows what's owed, what's been paid, and its status:
Paid, Partly paid, Unpaid or Needs review.

Payments come in read-only from the finance app (the weekly Venmo sync) or by
hand (**Add a payment**). A payment settles automatically only when its note and
amount clearly fit (for example "Thunder vs Twolves 11/25" for exactly half of
that game's payout). Payments covering two games and part-payments that say so
are fine. Anything uncertain lands in **Needs review** with a suggestion you can
apply, change or ignore. Season-invoice installments ("26/27") and personal
payments are set aside. Every change is kept: undoing an allocation needs a
reason, and nothing is ever deleted. If a sale's payout went to Duggan's account
instead, set **Payout went to** on the sale; then Duggan owes Mark half.

The **Season tickets** card tracks the other direction: Duggan's half of the
season invoice, which he pays Mark in installments. An installment counts toward
the season its note names ("26/27", "2026/2027"), or else the season whose spring
it falls in. The sync reads back to March 1 for these. Older game payments
belong to seasons that aren't tracked, so they're skipped.

### Listings
Record what you've listed on each game's page (**List seats**), or hold seats
you're keeping. Each game shows a listing status: Listed, Partially sold, Not
listed, Reserved, Sold, Transferred, or **Needs verification**. A listing nobody
has confirmed in 7 days needs verification. **Review listings** (on Games, or
from Home) is the checklist: check Ticketmaster, then tap "Still listed",
"Change price" or "Not listed". Every change is kept in the game's listing
history. Nothing here changes anything on Ticketmaster.

The Ticketmaster research (Mondays and Wednesdays) keeps this up to date on its
own, from what buyers can see:
- **A listing in our row (Section 101, Row DD):** our open seats are recorded as
  listed at that price (all-in), or the price change is recorded.
- **Nothing in our row after a complete read:** the seats are recorded as not
  listed, and any Ticketmaster listing the app had ends.
- **Two different prices in our row:** the app doesn't guess which is ours.

These changes appear in the listing history as made by the research.

The research reads listings for a pair, so a listing that only sells all three
seats together won't show. Another Row DD seat holder's listing would also look
like ours.

Sales through Ticketmaster count as delivered when they sell; mark private
sales **delivered** once the buyer has the tickets. Home flags undelivered
tickets in the last three days before a game.

### Recording Ticket Sales
1. Navigate to a specific game
2. Scroll to "Manage Tickets" section
3. Select the seat number
4. Enter the sale price
5. Optionally add buyer information and notes
6. Click "Record Sale"

To fix a sale later, click **Edit** next to it on the game page to change the
seat, price, sale date, buyer, or notes.

### Adding Playoff Games
1. Click "Add Playoff Game" from dashboard or games list
2. Select opponent
3. Choose game date
4. Select playoff round
5. Enter ticket cost and parking cost
6. Submit to add the game

### Password Recovery
1. Click "Forgot your password?" on login page
2. Enter your email address
3. Open the reset link in the email (in development, letter_opener opens it in
   your browser)
4. Set a new password. The link expires after 2 hours and works once.

Only active accounts can reset. Pending invitees should use their invitation
link, which an admin can resend from the Users page.

## Database Schema

### Models
- **User** - Authentication and user management
- **Season** - Season information (2025-26, etc.)
- **Team** - NBA teams
- **Game** - Individual games (regular season and playoffs)
- **Ticket** - Individual ticket sales

### Key Relationships
- A Season has many Games
- A Game belongs to a Season and an Opponent (Team)
- A Game has many Tickets
- A Ticket belongs to a Game

## Configuration

### Season Setup
Load a season's home games from the cached ESPN schedule in `db/schedules`:
```bash
bin/rails schedule:import YEAR=2026-27 TOTAL=20842.80 PARKING=8.70 SEATS=3 SECTION=101 PRESEASON=1
```
Add `DRY_RUN=1` to preview. The import makes that season current and is safe to
re-run. See `lib/tasks/schedule.rake` for the options.

The import also records each game's tipoff time. For a season imported before
tipoffs were stored, fill them in without touching anything else:
```bash
bin/rails schedule:backfill_tipoffs YEAR=2026-27 PRESEASON=1
```

### Adding New Users
Invite people from the Users page. A brand-new production database has no
accounts, so create the first one from a console (`bin/kamal console`):
```ruby
User.create!(
  email: "user@example.com",
  password: "secure_password",
  password_confirmation: "secure_password",
  name: "User Name",
  invited_by: "Admin"
)
```

## Customization

### Theme Colors
Edit `app/assets/tailwind/application.css` to customize the Tokyo Night color palette:
```css
--color-tokyo-bg: #1a1b26;
--color-tokyo-blue: #7aa2f7;
--color-tokyo-green: #9ece6a;
/* etc. */
```

### Team Support
While built for Thunder fans, you can adapt this for any NBA team by:
1. Changing branding in views
2. Updating team names in seed file
3. Customizing color scheme

## Production Deployment

### Using Kamal (included)
The app includes Kamal deployment configuration:
```bash
kamal setup
kamal deploy
```

### Environment Variables
Set these in your production environment:
- `RAILS_MASTER_KEY` - For encrypted credentials
- `DATABASE_URL` - If using PostgreSQL in production

## Future Enhancements

Potential features to add:
- Export financial reports to CSV/PDF
- Charts and visualizations with Chartkick
- Mobile app notifications
- Integration with ticketing platforms
- Automated price recommendations
- Multi-season comparison reports

## License

This project is available for personal use.

## Support

For issues or questions:
1. Check the Rails logs in `log/development.log`
2. Review error messages in the browser console
3. Ensure all migrations have run: `bin/rails db:migrate:status`

## Credits

Built with:
- Ruby on Rails framework
- TailwindCSS for styling
- Tokyo Night color scheme inspiration
- Heroicons for UI icons

---

**Thunder Up!** ⚡
