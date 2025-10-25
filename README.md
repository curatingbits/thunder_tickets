# ThunderTickets - NBA Season Ticket Tracker

A comprehensive web application for managing Oklahoma City Thunder season tickets, built with Ruby on Rails, Stimulus, SolidQueue, TailwindCSS, and SQLite.

## Features

### Core Functionality
- **Dashboard Analytics** - Real-time financial tracking with profit/loss calculations
- **Game Management** - Track all regular season and playoff games
- **Ticket Sales** - Record and manage individual ticket sales for each seat
- **Break-Even Analysis** - Know if you're on track to recover your season ticket investment
- **Financial Insights** - View revenue, costs, and profitability per game
- **Playoff Support** - Add playoff games as they're scheduled

### Authentication & Security
- **Invite-Only Access** - No public registration, admin-controlled user creation
- **Password Reset** - Secure password recovery via email (token printed to console)
- **Session Management** - Secure login/logout with encrypted passwords

### Design
- **Tokyo Night Theme** - Beautiful dark theme inspired by Tokyo Night color palette
- **Responsive Design** - Works seamlessly on desktop, tablet, and mobile
- **Real-time Updates** - Turbo-powered for instant updates without page reloads

## Tech Stack

- **Ruby on Rails 8.0.3**
- **SQLite3** - Lightweight database
- **TailwindCSS 4** - Modern utility-first CSS
- **Stimulus** - Modest JavaScript framework
- **SolidQueue** - Background job processing
- **Turbo** - SPA-like page acceleration

## Getting Started

### Prerequisites
- Ruby 3.4+ (using RVM)
- Rails 8.0+
- Node.js (for asset compilation)

### Installation

1. **Clone the repository** (if applicable)
   ```bash
   cd thunder_tickets
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup the database**
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   bin/rails db:seed
   ```

4. **Start the server**
   ```bash
   bin/dev
   ```

5. **Access the application**
   - Open your browser to `http://localhost:3000`
   - Default login credentials:
     - Email: `admin@thundertickets.com`
     - Password: `thunder2026`

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
3. Check the Rails console for the reset token URL
4. Visit the URL to set a new password

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
The current season is marked with `is_current: true` in the database. To start a new season:
1. Create a new Season record
2. Set `is_current: true`
3. Set the previous season's `is_current` to `false`
4. Import or create games for the new season

### Adding New Users
Since this is invite-only, create users via Rails console:
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
- Email notifications for password resets
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
