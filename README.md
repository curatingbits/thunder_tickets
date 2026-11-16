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
bin/rails schedule:import YEAR=2026-27 TOTAL=20842.80 PARKING=8.70 SEATS=3 SECTION=101 PRESEASON=1 BILLED_GAMES=41
```
Add `DRY_RUN=1` to preview. The import makes that season current and is safe to
re-run. See `lib/tasks/schedule.rake` for the options.

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
