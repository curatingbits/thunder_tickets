# Pricing thresholds on the Settings page. Blank means "use the default".
class AppSettingsController < ApplicationController
  def update
    values = params.fetch(:settings, {}).permit(*AppSetting::DEFINITIONS.keys).to_h
    AppSetting.transaction { values.each { |key, value| AppSetting.set(key, value, user: current_user) } }
    redirect_to settings_path, notice: "Pricing settings saved."
  rescue ArgumentError, TypeError
    redirect_to settings_path, alert: "Those settings need numbers."
  end
end
