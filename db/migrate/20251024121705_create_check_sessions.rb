class CreateCheckSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :check_sessions do |t|
      t.string :target_url
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
