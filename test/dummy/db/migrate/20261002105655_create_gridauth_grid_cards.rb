class CreateGridauthGridCards < ActiveRecord::Migration[8.1]
  def change
    create_table :gridauth_grid_cards do |t|
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.string :serial, null: false
      t.string :status, null: false, default: "pending"
      t.integer :row_count, null: false
      t.integer :column_count, null: false
      t.integer :cell_length, null: false
      t.string :salt, null: false
      t.text :cell_digests, null: false
      t.string :challenge_cells
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :locked_until
      t.integer :use_count, null: false, default: 0
      t.datetime :last_used_at
      t.datetime :activated_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :gridauth_grid_cards, :serial, unique: true
    add_index :gridauth_grid_cards, [ :user_id, :status ]
  end
end
