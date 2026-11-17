# Tunable thresholds (pricing alerts, fee assumptions, verification age).
# Defaults live in code (AppSetting::DEFINITIONS); a row exists only once
# someone changes a value.
class CreateAppSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :app_settings do |t|
      t.string :key, null: false
      t.text :value
      t.references :updated_by, foreign_key: { to_table: :users }
      t.timestamps

      t.index :key, unique: true
    end
  end
end
