module NavigationHelper
  NavItem = Data.define(:key, :label, :path, :icon, :active)

  # Main destinations: the phone tab bar and the top of the desktop sidebar.
  # Later features (Pricing, Money) join here as they ship, so a tab never
  # leads to an empty page.
  def primary_nav_items
    [
      nav_item(:home, "Home", root_path, :home, controllers: %w[dashboard]),
      nav_item(:games, "Games", games_path, :ticket, controllers: %w[games tickets listings listing_reviews manual_scans]),
      nav_item(:pricing, "Pricing", pricing_path, :chart, controllers: %w[pricing import_runs]),
      nav_item(:money, "Money", money_path, :cash, controllers: %w[settlements partner_payments settlement_allocations])
    ]
  end

  # Everything else: the sidebar's second group on desktop, the More page on
  # phones.
  def secondary_nav_items
    [
      nav_item(:buyers, "Buyers", buyers_path, :user_group, controllers: %w[buyers]),
      nav_item(:seasons, "Seasons", seasons_path, :calendar, controllers: %w[seasons], actions: %w[index]),
      nav_item(:users, "Users", users_path, :users, controllers: %w[users]),
      nav_item(:settings, "Settings", settings_path, :cog, controllers: %w[seasons], actions: %w[edit update])
    ]
  end

  # The phone tab bar's last tab. It counts as current on any secondary page,
  # since those are reached through it.
  def more_nav_item
    NavItem.new(key: :more, label: "More", path: more_path, icon: :menu,
                active: controller_name == "more" || secondary_nav_items.any?(&:active))
  end

  def nav_item(key, label, path, icon, controllers:, actions: nil)
    active = controllers.include?(controller_name) && (actions.nil? || actions.include?(action_name))
    NavItem.new(key: key, label: label, path: path, icon: icon, active: active)
  end
end
