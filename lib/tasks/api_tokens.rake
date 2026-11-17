namespace :api_tokens do
  desc "Create a token. Prints it once. Usage: rake api_tokens:create NAME=market-research SCOPES=market:write"
  task create: :environment do
    scopes = ENV.fetch("SCOPES").split(/[\s,]+/)
    token, raw = ApiToken.generate!(name: ENV.fetch("NAME"), scopes: scopes)
    puts "Created token ##{token.id} (#{token.name}, #{token.scope_list.join(' ')})."
    puts "This is the only time it's shown. Save this line in a chmod-600 header file:"
    puts
    puts "Authorization: Bearer #{raw}"
  end

  desc "List tokens (never shows the tokens themselves)"
  task list: :environment do
    ApiToken.order(:id).each do |t|
      state = if t.revoked_at then "revoked #{t.revoked_at.to_date}"
      elsif t.expires_at&.past? then "expired"
      else "active"
      end
      puts format("#%-3d %-20s %-12s %-30s last used %s  %s", t.id, t.name, "#{t.token_prefix}…",
                  t.scope_list.join(" "), t.last_used_at&.strftime("%F %R") || "never", state)
    end
  end

  desc "Revoke a token. Usage: rake api_tokens:revoke ID=3"
  task revoke: :environment do
    token = ApiToken.find(ENV.fetch("ID"))
    token.revoke!
    puts "Revoked ##{token.id} (#{token.name})."
  end
end
