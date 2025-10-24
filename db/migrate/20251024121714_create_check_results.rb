class CreateCheckResults < ActiveRecord::Migration[8.1]
  def change
    create_table :check_results do |t|
      t.references :check_session, null: false, foreign_key: true
      t.integer :section_number
      t.string :check_number
      t.text :description
      t.string :status
      t.text :note

      t.timestamps
    end
  end
end
